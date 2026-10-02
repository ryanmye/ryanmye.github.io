# frozen_string_literal: true

# Image handling shared by scripts/local_editor_server.rb (uploads, variants)
# and scripts/generate_thumbnails.rb (backfill). Not loaded by Jekyll.
#
# What each format gets (ImagePipeline.store, on upload):
#   .jpg .jpeg .png .webp  stored in the same format with the orientation baked
#                          in and EXIF/XMP/IPTC/comments removed (the ICC color
#                          profile is kept); -thumb.jpg (600w) and -med.jpg
#                          (1600w) JPEG variants + an image_meta.yml entry
#   .gif                   a still GIF is treated like the above; an animated
#                          GIF keeps every frame (metadata stripped only) and
#                          gets only a -thumb.jpg of its first frame and
#                          `animated: true` (no med, so the site shows the GIF
#                          itself). Animated WebP is handled the same way.
#   .svg                   sanitized (SvgSanitizer below), never rasterized,
#                          no variants; the manifest entry holds only its size
#   .heic .heif .avif      decoded with macOS `sips` (ImageMagick here has no
#                          HEIC/AVIF coder), then stored as a stripped JPEG;
#                          the HEIC itself is not kept
#   .tif .tiff .bmp        stored as a stripped JPEG (ImageMagick)
#
# ImageMagick safety: the file type is always sniffed from its bytes and the
# coder is forced ("jpeg:/path[0]"), so a file can never pick its own decoder
# (MSL, MVG, SVG, TEXT...). scripts/magick-policy/policy.xml (loaded through
# MAGICK_CONFIGURE_PATH, set below before any ImageMagick call) also denies
# those coders, all delegates and "@file" paths, and caps size, memory and
# time.
#
# Variants need the mini_magick gem and an ImageMagick binary on PATH; SVG
# handling needs neither (REXML only).

require 'open3'
require 'tmpdir'
require 'fileutils'
require 'rexml/document'

module ImagePipeline
  POLICY_DIR = File.expand_path('magick-policy', __dir__)
  # Every ImageMagick process this Ruby process starts inherits this.
  ENV['MAGICK_CONFIGURE_PATH'] = POLICY_DIR

  THUMB_W = 600
  MED_W = 1600
  THUMB_Q = 78
  MED_Q = 82
  # Quality of a stored original that had to be re-encoded (metadata
  # stripping, HEIC/TIFF/BMP conversion).
  STORE_Q = 92

  # Sources that get -thumb.jpg (and, unless animated, -med.jpg) variants.
  RASTER_EXTS = %w[.jpg .jpeg .png .gif .webp].freeze
  SVG_EXT = '.svg'
  # Every extension that can sit in assets/images/{posts,drafts,albums}/ as a
  # source image (after upload conversion).
  SOURCE_EXTS = (RASTER_EXTS + [SVG_EXT]).freeze

  # Sniffed kind -> stored extension. :heif, :tiff and :bmp become JPEG.
  KIND_EXT = { jpeg: '.jpg', png: '.png', gif: '.gif', webp: '.webp', svg: '.svg',
               heif: '.jpg', tiff: '.jpg', bmp: '.jpg' }.freeze
  # Sniffed kind -> the ImageMagick coder forced on every read and write.
  CODER = { jpeg: 'jpeg', png: 'png', gif: 'gif', webp: 'webp', tiff: 'tiff', bmp: 'bmp' }.freeze
  ANIMATABLE = %i[gif webp].freeze

  SUPPORTED_TEXT = 'JPEG, PNG, GIF, WebP, SVG, HEIC, AVIF, TIFF or BMP'

  # Content types for serving (Rack's table has no .webp), so the API can
  # send nosniff without a browser refusing a file it labeled wrongly.
  MIME = { '.jpg' => 'image/jpeg', '.jpeg' => 'image/jpeg', '.png' => 'image/png', '.gif' => 'image/gif',
           '.webp' => 'image/webp', '.svg' => 'image/svg+xml' }.freeze

  class ConvertError < StandardError; end

  # A refused upload: `status` is the HTTP status (415 unusable type or
  # failed conversion, 422 an SVG that cannot be sanitized).
  class UploadError < StandardError
    attr_reader :status

    def initialize(status, message)
      @status = status
      super(message)
    end
  end

  module_function

  def tool_on_path(bin)
    ENV['PATH'].to_s.split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, bin)) }
  end

  SIPS = tool_on_path('sips') ? 'sips' : nil
  WEBPMUX = tool_on_path('webpmux') ? 'webpmux' : nil
  # The ImageMagick binary found on PATH (nil without one).
  IMAGE_TOOL = %w[magick convert].find { |bin| tool_on_path(bin) }
  # Variants need the mini_magick gem AND an ImageMagick binary.
  MAGICK_AVAILABLE =
    begin
      require 'mini_magick'
      !IMAGE_TOOL.nil?
    rescue LoadError
      false
    end

  # ---------- sniffing ----------

  # What a file really is, from its first bytes (the extension can lie: some
  # exports name HEIC files .jpg, and a "PNG" can be an SVG or an MSL
  # script). nil for anything this site cannot use.
  def sniff(path)
    head = File.binread(path, 65_536) || ''.b
    return :jpeg if head.start_with?("\xFF\xD8\xFF".b)
    return :png if head.start_with?("\x89PNG\r\n\x1A\n".b)
    return :gif if head.start_with?('GIF87a'.b, 'GIF89a'.b)
    return :webp if head[0, 4] == 'RIFF'.b && head[8, 4] == 'WEBP'.b
    return :tiff if head.start_with?("II*\x00".b, "MM\x00*".b)
    return :bmp if head.start_with?('BM'.b) && head.bytesize > 26
    # ISO base media: HEIC/HEIF (iPhone photos) and AVIF share the container;
    # sips reads both. Video brands (mp4, qt) are not images.
    return :heif if head[4, 4] == 'ftyp'.b && (ftyp_brands(head) & %w[heic heix hevc hevx heim heis mif1 msf1 avif avis]).any?
    return :svg if svg_head?(head)
    nil
  end

  # True when the text starts (after an optional BOM, XML declaration,
  # comments, processing instructions and a DOCTYPE) with an <svg> element.
  # A plain left-to-right scan, no backtracking regex.
  def svg_head?(head)
    return false if head.include?("\x00".b)
    s = head.dup.force_encoding('UTF-8').scrub
    s = s.delete_prefix("﻿")
    i = 0
    loop do
      i += 1 while i < s.length && s[i] =~ /\s/
      return false unless s[i] == '<'
      if s[i, 4] == '<!--'
        j = s.index('-->', i + 4) or return false
        i = j + 3
      elsif s[i, 2] == '<?'
        j = s.index('?>', i + 2) or return false
        i = j + 2
      elsif s[i, 9].casecmp?('<!DOCTYPE')
        lt = s.index('>', i) or return false
        br = s.index('[', i)
        if br && br < lt
          j = s.index(']', br) or return false
          lt = s.index('>', j) or return false
        end
        i = lt + 1
      else
        return s[i + 1..] =~ /\A(?:[A-Za-z_][\w.-]*:)?svg[\s>\/]/ ? true : false
      end
    end
  end

  # Major + compatible brands of an ISO base media file (from its ftyp box).
  def ftyp_brands(head)
    size = head[0, 4].unpack1('N').to_i.clamp(16, 64)
    head[8, size - 8].to_s.scan(/.{4}/m).map { |b| b.force_encoding('ASCII-8BIT') }
  end

  # "AVIF" or "HEIC", for messages.
  def heif_label(path)
    (ftyp_brands(File.binread(path, 64).to_s) & %w[avif avis]).any? ? 'AVIF' : 'HEIC'
  end

  # ---------- ImageMagick ----------

  # "jpeg:/path[0]": the coder comes from the sniffed bytes, never from the
  # file. Raises ConvertError for anything ImageMagick must not read.
  def coded(path, kind = sniff(path), frame: '[0]')
    coder = CODER[kind] or raise ConvertError, "#{File.basename(path)} is not a raster image this site handles"
    "#{coder}:#{path}#{frame}"
  end

  # ImageMagick through mini_magick (`magick` on IM7, `convert` on IM6), with
  # an argument array (never a shell string).
  def magick(*args)
    raise ConvertError, 'ImageMagick is not available (brew install imagemagick)' unless MAGICK_AVAILABLE
    tool = MiniMagick.imagemagick7? ? MiniMagick::Tool::Magick.new : MiniMagick::Tool::Convert.new
    args.each { |a| tool << a }
    tool.call
  rescue MiniMagick::Error => e
    raise ConvertError, "ImageMagick could not read it (#{magick_reason(e)})"
  end

  # The ImageMagick complaint without file paths, for messages.
  def magick_reason(error)
    line = error.message.lines.grep(/(magick|convert|identify):/).last.to_s
    line.sub(/\A\s*\S+:\s*/, '').sub(/\s*[`'"].*\z/m, '').sub(/\s*@ .*\z/m, '').strip[0, 120]
  end

  def identify(*args)
    raise ConvertError, 'ImageMagick is not available (brew install imagemagick)' unless MAGICK_AVAILABLE
    tool = MiniMagick::Tool::Identify.new
    args.each { |a| tool << a }
    tool.call
  rescue MiniMagick::Error => e
    raise ConvertError, "ImageMagick could not read it (#{magick_reason(e)})"
  end

  # ---------- storing an upload ----------

  # Turn an uploaded file into what is stored: writes dest_base + extension
  # (dest_base has none) and returns [path, info]; info has 'converted_from'
  # and/or 'svg_removed'. ext_hint keeps a ".jpeg" spelling. Raises
  # UploadError.
  def store(src, dest_base, ext_hint: nil)
    kind = sniff(src)
    raise UploadError.new(415, "is not an image type the site can use. Use #{SUPPORTED_TEXT}") unless kind
    dest = dest_base + KIND_EXT[kind]
    dest = dest_base + '.jpeg' if kind == :jpeg && ext_hint.to_s.downcase == '.jpeg'
    info = {}
    case kind
    when :svg
      clean, removed = SvgSanitizer.sanitize(File.binread(src))
      File.write(dest, clean)
      info['svg_removed'] = removed
    when :heif
      heif_to_jpeg(src, dest)
      info['converted_from'] = heif_label(src)
    when :tiff, :bmp
      reencode(src, kind, dest, :jpeg)
      info['converted_from'] = kind.to_s.upcase
    else
      clean_raster(src, kind, dest)
    end
    File.chmod(0o644, dest)
    [dest, info]
  rescue SvgSanitizer::Error => e
    FileUtils.rm_f(dest) if dest
    raise UploadError.new(422, "was not uploaded: #{e.message}. Export it again as a plain SVG")
  rescue ConvertError => e
    FileUtils.rm_f(dest) if dest
    raise UploadError.new(415, "could not be stored: #{e.message}")
  end

  # JPEG/PNG/GIF/WebP: orientation baked in, metadata removed, same format.
  # Animated GIF/WebP keep every frame and are only stripped.
  def clean_raster(src, kind, dest)
    if ANIMATABLE.include?(kind) && frame_count(src, kind) > 1
      if kind == :webp && WEBPMUX
        # Lossless: drop the EXIF and XMP chunks, keep the frames as they are.
        # webpmux fails with WEBP_MUX_NOT_FOUND when a chunk is absent.
        Dir.mktmpdir('webp') do |dir|
          current = src
          %w[exif xmp].each_with_index do |chunk, i|
            out = File.join(dir, "step#{i}.webp")
            _o, err, st = Open3.capture3(WEBPMUX, '-strip', chunk, current, '-o', out)
            if st.success? then current = out
            elsif !err.include?('NOT_FOUND') then raise ConvertError, "webpmux failed (#{err.strip.lines.last&.strip})"
            end
          end
          FileUtils.cp(current, dest)
        end
      else
        magick(coded(src, kind, frame: ''), '-strip', "#{CODER[kind]}:#{dest}")
      end
    else
      reencode(src, kind, dest, kind)
    end
  end

  # One frame, auto-oriented, every profile but ICC removed (EXIF, XMP, IPTC,
  # 8BIM), no comment or PNG text chunks, written as out_kind.
  def reencode(src, in_kind, dest, out_kind)
    args = [coded(src, in_kind), '-auto-orient', '+profile', '!icc,*', '+set', 'comment']
    case out_kind
    when :jpeg then args += ['-background', 'white', '-alpha', 'remove', '-alpha', 'off', '-quality', STORE_Q.to_s]
    when :png then args += ['-define', 'png:exclude-chunks=tEXt,zTXt,iTXt,eXIf,date,time']
    when :webp then args += webp_lossless?(src) ? ['-define', 'webp:lossless=true'] : ['-quality', STORE_Q.to_s]
    end
    magick(*args, "#{CODER.fetch(out_kind)}:#{dest}")
    raise ConvertError, 'ImageMagick wrote nothing' unless File.size?(dest)
  end

  def webp_lossless?(path)
    head = File.binread(path, 4096).to_s
    head.include?('VP8L'.b) && !head.include?('VP8 '.b)
  end

  # HEIC/HEIF/AVIF: sips decodes to a lossless TIFF (EXIF orientation and the
  # ICC profile carried over), then one JPEG encode bakes the orientation in
  # and drops the metadata (GPS, camera, capture time).
  def heif_to_jpeg(src, dest)
    raise ConvertError, 'converting HEIC/AVIF needs macOS (sips)' unless SIPS
    Dir.mktmpdir('heif') do |dir|
      input = File.join(dir, 'in.heic') # sips picks its decoder by extension
      tiff = File.join(dir, 'out.tiff')
      FileUtils.cp(src, input)
      _o, err, st = Open3.capture3(SIPS, '-s', 'format', 'tiff', input, '--out', tiff)
      unless st.success? && File.size?(tiff) && sniff(tiff) == :tiff
        raise ConvertError, "sips could not read it (#{err.strip.lines.last&.strip || 'no output'})"
      end
      reencode(tiff, :tiff, dest, :jpeg)
    end
  end

  # True when a stored raster still carries metadata or a non-default
  # orientation (used by `generate_thumbnails.rb --strip-metadata`).
  def metadata?(path, kind = sniff(path))
    return false unless CODER[kind]
    verbose = identify('-verbose', coded(path, kind))
    return true if verbose =~ /^\s*Profile-(exif|xmp|iptc|8bim|app1)\b/i || verbose =~ /^\s*comment:/i
    return true if verbose =~ /^\s*(exif|xmp|iptc|tiff):(gps|make|model|datetime)/i
    orient = verbose[/^\s*Orientation:\s*(\S+)/, 1]
    !orient.nil? && !%w[TopLeft Undefined].include?(orient)
  end

  # Strip an existing original in place (same rules as an upload). Returns
  # true when the file was rewritten.
  def strip_in_place!(path)
    kind = sniff(path)
    return false unless CODER[kind] && metadata?(path, kind)
    tmp = "#{path}.strip-tmp"
    clean_raster(path, kind, tmp)
    File.chmod(File.stat(path).mode & 0o777, tmp)
    File.rename(tmp, path)
    true
  ensure
    FileUtils.rm_f(tmp) if tmp && File.exist?(tmp)
  end

  # ---------- variants ----------

  def svg?(path)
    File.extname(path.to_s).downcase == SVG_EXT
  end

  def raster?(path)
    RASTER_EXTS.include?(File.extname(path.to_s).downcase)
  end

  def variant_path(source_abs, variant)
    dir = File.dirname(source_abs)
    base = File.basename(source_abs, File.extname(source_abs))
    File.join(dir, "#{base}-#{variant}.jpg")
  end

  def variant_file?(path)
    File.basename(path.to_s) =~ /-(thumb|med)\.jpg\z/i ? true : false
  end

  # Frame count (1 for anything that cannot animate).
  def frame_count(path, kind = sniff(path))
    return 1 unless ANIMATABLE.include?(kind)
    identify('-format', '%n\n', coded(path, kind, frame: '')).lines.first.to_i.clamp(1, 1_000_000)
  rescue ConvertError
    1
  end

  # The variants a source should have: %w[thumb med], %w[thumb] (animated),
  # or [] (SVG, or a format without variants).
  def expected_variants(source_abs)
    return [] unless raster?(source_abs)
    frame_count(source_abs) > 1 ? %w[thumb] : %w[thumb med]
  end

  # Writes a JPEG variant from the first frame of source_abs, oriented,
  # flattened on white, stripped, at most max_w wide. Returns [w, h].
  def write_variant(source_abs, out_abs, max_w, quality)
    magick(coded(source_abs), '-auto-orient', '-background', 'white', '-alpha', 'remove', '-alpha', 'off',
           '-strip', '-resize', "#{max_w}x>", '-interlace', 'Plane', '-quality', quality.to_s, "jpeg:#{out_abs}")
    dimensions(out_abs)
  end

  # [w, h] as displayed (EXIF orientation 5-8 swaps them), first frame only.
  def dimensions(path)
    w, h, orient = identify('-format', '%w %h %[orientation]\n', coded(path)).lines.first.to_s.split
    w = w.to_i
    h = h.to_i
    %w[LeftTop RightTop RightBottom LeftBottom].include?(orient) ? [h, w] : [w, h]
  end

  # Writes the variants for one source and returns its manifest fields
  # ({'w','h','thumb','med'?,'animated'?}), or nil when there is nothing to
  # record (an SVG without a usable size). `key_for` maps an absolute path to
  # its manifest key. Raster sources need ImageMagick.
  def build_entry(source_abs, key_for)
    if svg?(source_abs)
      size = SvgSanitizer.size(File.binread(source_abs))
      return size && { 'w' => size[0], 'h' => size[1] }
    end
    return nil unless raster?(source_abs)
    wanted = expected_variants(source_abs)
    orig_w, orig_h = dimensions(source_abs)
    entry = { 'w' => orig_w, 'h' => orig_h }
    { 'thumb' => [THUMB_W, THUMB_Q], 'med' => [MED_W, MED_Q] }.each do |v, (max_w, q)|
      out = variant_path(source_abs, v)
      if wanted.include?(v)
        w, h = write_variant(source_abs, out, max_w, q)
        entry[v] = { 'src' => key_for.call(out), 'w' => w, 'h' => h }
      elsif File.exist?(out)
        File.delete(out) # e.g. a med left from before the file was animated
      end
    end
    entry['animated'] = true if wanted == %w[thumb]
    entry
  end

  # True when every variant the source needs exists and is newer than it.
  # Runs on every save, so it only looks at files (no ImageMagick): a GIF/WebP
  # with a fresh thumb and no med is an animated one that is done.
  def variants_fresh?(source_abs)
    return true unless raster?(source_abs)
    fresh = lambda do |v|
      out = variant_path(source_abs, v)
      File.exist?(out) && File.mtime(out) >= File.mtime(source_abs)
    end
    return false unless fresh.call('thumb')
    med = variant_path(source_abs, 'med')
    fresh.call('med') || (%w[.gif .webp].include?(File.extname(source_abs).downcase) && !File.exist?(med))
  end
end

# SVG sanitizer. Cheap checks first (size, UTF-8, element count, nesting
# depth), then REXML parses (pure Ruby; it never fetches external entities or
# DTDs and caps internal entity expansion) and a new document is written
# holding only what is safe:
#   - only elements in the SVG namespace (an SVG without xmlns is treated as
#     SVG); everything else, with its children, is dropped (Inkscape/RDF
#     metadata included)
#   - never <script>, <foreignObject>, <iframe>, <object>, <embed>,
#     <handler>, <listener>, nor an <animate>/<set>/... that targets an href
#     or an on* attribute
#   - no on* attributes; href / xlink:href only when it is a local "#id" or a
#     data:image/(png|jpeg|gif|webp) URL; xml:space and xml:lang kept,
#     xml:base dropped; no attributes in other namespaces
#   - CSS is not rewritten: a declaration (in <style> or style="") or an
#     attribute value with a backslash, @import, image-set( or a url(...)
#     other than url(#id) is removed whole
#   - no DOCTYPE/ENTITY declarations (internal entities are expanded into the
#     text, external ones are never read), processing instructions
#     (xml-stylesheet) or comments
# Raises SvgSanitizer::Error for anything it will not take.
module SvgSanitizer
  SVG_NS = 'http://www.w3.org/2000/svg'
  XLINK_NS = 'http://www.w3.org/1999/xlink'
  XML_NS = 'http://www.w3.org/XML/1998/namespace'
  MAX_BYTES = 5 * 1024 * 1024
  MAX_OUTPUT = 10 * 1024 * 1024
  MAX_TAGS = 50_000
  MAX_DEPTH = 256
  # The pre-parse depth scan is approximate (a ">" inside an attribute value
  # can fool it), so it gets slack; the tree walk enforces MAX_DEPTH exactly.
  PRESCAN_DEPTH = 512
  MAX_REMOVED_LISTED = 50
  DROP_ELEMENTS = %w[script foreignobject iframe object embed handler listener].freeze
  ANIMATION_ELEMENTS = %w[set animate animatetransform animatemotion animatecolor].freeze
  SAFE_DATA_URL = %r{\Adata:image/(png|jpeg|jpg|gif|webp)[;,]}i
  SAFE_CSS_URL = /url\(\s*(["']?)\s*#[^)"'\s\\]*\s*\1\s*\)/i
  CSS_COMMENT = %r{/\*[^*]*\*+(?:[^/*][^*]*\*+)*/}

  class Error < StandardError; end

  module_function

  # Returns [clean_svg_string, removed], where removed lists what was taken
  # out (deduplicated with counts, at most MAX_REMOVED_LISTED lines).
  def sanitize(xml)
    root = parse(xml)
    removed = Hash.new(0)
    ns = namespaces_of(root, {})
    body = +''
    begin
      write_element(root, body, removed, ns, ns[root.prefix.to_s].to_s.empty?, 1)
    rescue Error
      raise
    rescue StandardError, SystemStackError => e # REXML expands entities lazily; its limits raise here
      raise Error, "it could not be read (#{e.message.lines.first.to_s.strip[0, 120]})"
    end
    list = removed.map { |what, n| n > 1 ? "#{what} (x#{n})" : what }.first(MAX_REMOVED_LISTED)
    ["<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n#{body}\n", list]
  end

  # Display size [w, h] (integers) from width/height (px or absolute units)
  # and/or viewBox. nil when it cannot be known (e.g. width="100%" and no
  # viewBox), or when the file is not a usable SVG.
  def size(xml)
    root = parse(xml)
    w = length(root.attributes['width'])
    h = length(root.attributes['height'])
    vb = view_box(root.attributes['viewBox'])
    unless w && h
      if vb && w then h = w * vb[1] / vb[0]
      elsif vb && h then w = h * vb[0] / vb[1]
      elsif vb then w, h = vb
      end
    end
    return nil unless w && h && w.positive? && h.positive?
    [w.round.clamp(1, 100_000), h.round.clamp(1, 100_000)]
  rescue StandardError
    nil
  end

  # Cheap checks, then REXML. Any failure is an Error.
  def parse(xml)
    xml = xml.to_s.dup.force_encoding('UTF-8')
    raise Error, 'it is larger than 5 MB' if xml.bytesize > MAX_BYTES
    raise Error, 'it is not UTF-8 text' unless xml.valid_encoding?
    xml = xml.delete_prefix("﻿")
    raise Error, 'the file is empty' if xml.strip.empty?
    raise Error, "it has more than #{MAX_TAGS} elements" if xml.count('<') > MAX_TAGS
    raise Error, "it is nested more than #{MAX_DEPTH} levels deep" if prescan_depth(xml) > PRESCAN_DEPTH
    begin
      doc = REXML::Document.new(xml)
    rescue REXML::ParseException => e
      raise Error, "it is not well-formed XML (#{e.message.lines.first.to_s.strip[0, 120]})"
    rescue StandardError, SystemStackError => e # entity expansion limits, encoding errors and the like
      raise Error, "it could not be parsed (#{e.message.lines.first.to_s.strip[0, 120]})"
    end
    root = doc.root
    unless root && root.name == 'svg' && [SVG_NS, ''].include?(namespaces_of(root, {})[root.prefix.to_s].to_s)
      raise Error, 'its root element is not <svg>'
    end
    root
  end

  # Maximum element nesting, counted from the tags alone (linear).
  def prescan_depth(xml)
    depth = max = 0
    xml.scan(%r{<([/!?]?)[^<>]*?(/?)>}) do |kind, self_close|
      next unless kind.empty? || kind == '/'
      if kind == '/'
        depth -= 1
      elsif self_close.empty?
        depth += 1
        max = depth if depth > max
      end
    end
    max
  end

  # The prefix -> namespace map in scope for `el`, given its parent's.
  def namespaces_of(el, inherited)
    decls = {}
    el.attributes.each_attribute do |a|
      if a.prefix == 'xmlns' then decls[a.name] = a.value
      elsif a.prefix.to_s.empty? && a.name == 'xmlns' then decls[''] = a.value
      end
    end
    decls.empty? ? inherited : inherited.merge(decls)
  end

  def length(value)
    m = value.to_s.strip.match(/\A([0-9]*\.?[0-9]+(?:e[+-]?\d+)?)\s*(px|pt|pc|in|cm|mm)?\z/i)
    return nil unless m
    m[1].to_f * { nil => 1, 'px' => 1, 'pt' => 4.0 / 3, 'pc' => 16, 'in' => 96, 'cm' => 96 / 2.54, 'mm' => 96 / 25.4 }[m[2]&.downcase]
  end

  def view_box(value)
    nums = value.to_s.strip.split(/[\s,]+/).map { |n| Float(n, exception: false) }
    return nil unless nums.length == 4 && nums.all? && nums[2].positive? && nums[3].positive?
    [nums[2], nums[3]]
  end

  def safe_ref?(value)
    v = value.to_s.gsub(/[\s\u0000-\u001F]/, '')
    v.start_with?('#') || v.match?(SAFE_DATA_URL)
  end

  # True for CSS (or an attribute value) this sanitizer will not keep.
  def unsafe_css?(text)
    return true if text.include?('\\')
    text.gsub(SAFE_CSS_URL, '').match?(/@import|image-set\(|url\(/i)
  end

  # Removes whole declarations (and @import rules) that are unsafe_css?;
  # everything else is kept byte for byte.
  def clean_css(css, removed)
    css.gsub(CSS_COMMENT, '').split(/([{};])/).map do |piece|
      next piece if piece.match?(/\A[{};]\z/) || !unsafe_css?(piece)
      removed['CSS with an outside url(), @import, image-set() or a backslash'] += 1
      ''
    end.join
  end

  def esc_attr(s)
    s.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;').gsub('"', '&quot;')
     .gsub("\n", '&#10;').gsub("\r", '&#13;').gsub("\t", '&#9;')
  end

  def esc_text(s)
    s.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;')
  end

  def label(el)
    el.prefix.to_s.empty? ? el.name : "#{el.prefix}:#{el.name}"
  end

  def check_output!(out)
    raise Error, 'the cleaned file would be larger than 10 MB' if out.bytesize > MAX_OUTPUT
  end

  # The attributes to write for `el`, as [qname, value] pairs. `ns` is the
  # namespace map in scope for it.
  def safe_attributes(el, ns, removed, root:)
    attrs = []
    el.attributes.each_attribute do |a|
      prefix = a.prefix.to_s
      local = a.name.to_s
      next if prefix == 'xmlns' || (prefix.empty? && local == 'xmlns')
      qname =
        if prefix.empty? then local
        elsif prefix == 'xml' then %w[space lang].include?(local) ? "xml:#{local}" : nil
        elsif ns[prefix] == XLINK_NS then "xlink:#{local}"
        end
      unless qname
        removed["#{prefix}:#{local} attribute"] += 1 unless %w[inkscape sodipodi].include?(prefix)
        next
      end
      value = a.value.to_s
      if local.downcase.start_with?('on')
        removed["#{qname} handler"] += 1
      elsif local.downcase == 'href' && !safe_ref?(value)
        removed["#{qname}=\"#{value[0, 60]}\""] += 1
      elsif local == 'style'
        attrs << [qname, clean_css(value, removed)]
      elsif unsafe_css?(value)
        removed["#{qname} with an outside url() or a backslash"] += 1
      else
        attrs << [qname, value]
      end
    end
    if root
      attrs.unshift(['xmlns:xlink', XLINK_NS]).unshift(['xmlns', SVG_NS])
      names = attrs.map(&:first)
      # Give an SVG that only has a viewBox an intrinsic size, so <img> and
      # the manifest know its aspect ratio.
      vb = view_box(el.attributes['viewBox'])
      if vb && !names.include?('width') && !names.include?('height')
        attrs << ['width', fmt_num(vb[0])]
        attrs << ['height', fmt_num(vb[1])]
      end
    end
    attrs
  end

  def write_element(el, out, removed, ns, no_ns, depth)
    raise Error, "it is nested more than #{MAX_DEPTH} levels deep" if depth > MAX_DEPTH
    element_ns = ns[el.prefix.to_s].to_s
    unless element_ns == SVG_NS || (no_ns && element_ns.empty?)
      removed["<#{label(el)}> (not SVG)"] += 1
      return
    end
    name = el.name.to_s
    lname = name.downcase
    if DROP_ELEMENTS.include?(lname)
      removed["<#{name}>"] += 1
      return
    end
    if ANIMATION_ELEMENTS.include?(lname)
      target = el.attributes['attributeName'].to_s.split(':').last.to_s.strip.downcase
      if target == 'href' || target.start_with?('on')
        removed["<#{name} attributeName=\"#{target}\">"] += 1
        return
      end
    end

    out << "<#{name}"
    safe_attributes(el, ns, removed, root: depth == 1).each { |k, v| out << " #{k}=\"#{esc_attr(v)}\"" }
    check_output!(out)
    children = el.children
    if children.empty?
      out << '/>'
      return
    end
    out << '>'
    children.each do |c|
      case c
      when REXML::Element
        write_element(c, out, removed, namespaces_of(c, ns), no_ns, depth + 1)
      when REXML::Text # includes CDATA
        text = c.value.to_s
        text = clean_css(text, removed) if lname == 'style'
        out << esc_text(text)
        check_output!(out)
      when REXML::Instruction
        removed["<?#{c.target}?>"] += 1
      end
      # Comments are dropped silently.
    end
    out << "</#{name}>"
  end

  def fmt_num(n)
    n == n.round ? n.round.to_s : n.round(3).to_s
  end
end

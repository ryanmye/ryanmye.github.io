#!/usr/bin/env ruby
# Local-only API behind the /editor/ studio (posts, drafts, albums, git publish).
# Easiest: bin/dev (starts this and Jekyll). By hand, from the repo root:
#   ruby -rbundler/setup scripts/local_editor_server.rb
# (`bundle exec ruby` breaks when the repo path contains a space.)
# STUDIO_SITE_PORT (default 4000) is the Jekyll port allowed to call this API;
# STUDIO_API_PORT (default 4001) is the port this listens on.

require 'sinatra'
require 'json'
require 'fileutils'
require 'time'
require 'yaml'
require 'base64'
require 'open3'
require 'digest'

# Thumbnails need the mini_magick gem AND an ImageMagick binary on PATH.
IMAGE_TOOL = %w[magick convert].find do |bin|
  ENV['PATH'].to_s.split(File::PATH_SEPARATOR).any? { |dir| File.executable?(File.join(dir, bin)) }
end
begin
  require 'mini_magick'
  MINI_MAGICK_AVAILABLE = !IMAGE_TOOL.nil?
rescue LoadError
  MINI_MAGICK_AVAILABLE = false
end
warn 'Thumbnails disabled: install ImageMagick (brew install imagemagick).' unless MINI_MAGICK_AVAILABLE

SITE_PORT = Integer(ENV['STUDIO_SITE_PORT'] || 4000)
API_PORT = Integer(ENV['STUDIO_API_PORT'] || 4001)

set :bind, '127.0.0.1'
set :port, API_PORT

ROOT = File.expand_path('..', __dir__)
POSTS_DIR = File.join(ROOT, '_posts')
DRAFTS_DIR = File.join(ROOT, '_drafts')
IMAGES_DIR = File.join(ROOT, 'assets', 'images', 'posts')
DRAFT_IMAGES_DIR = File.join(ROOT, 'assets', 'images', 'drafts')
ALBUM_IMAGES_DIR = File.join(ROOT, 'assets', 'images', 'albums')
ALBUMS_DIR = File.join(ROOT, '_albums')
TEMP_IMAGES_DIR = File.join(ROOT, '_editor_tmp')
IMAGE_META_PATH = File.join(ROOT, '_data', 'image_meta.yml')
# Roots that request-supplied paths are confined to (see confined_path).
IMAGES_ROOT = File.expand_path(File.join(ROOT, 'assets', 'images'))
TEMP_ROOT = File.expand_path(TEMP_IMAGES_DIR)
# The only image folders the editor may delete from (never headshots etc.).
CONTENT_IMAGE_ROOTS = [IMAGES_DIR, DRAFT_IMAGES_DIR, ALBUM_IMAGES_DIR].map { |d| File.expand_path(d) }.freeze

# Browser origins allowed to call this API (the Jekyll dev server only), and
# Host headers this API answers to (blocks DNS rebinding).
ALLOWED_ORIGINS = ["http://127.0.0.1:#{SITE_PORT}", "http://localhost:#{SITE_PORT}"].freeze
ALLOWED_HOSTS = ["127.0.0.1:#{API_PORT}", "localhost:#{API_PORT}"].freeze

# Repo paths that count as "content" for the git publish flow. /git/status only
# reports these and /git/publish only ever stages and commits these.
GIT_CONTENT_PATHS = %w[_posts/ _drafts/ _albums/ assets/images/posts/ assets/images/albums/ _data/image_meta.yml].freeze
ACTIONS_URL = 'https://github.com/ryanmye/ryanmye.github.io/actions'
# Abort a stalled fetch/push instead of hanging the request forever.
GIT_ENV = { 'GIT_TERMINAL_PROMPT' => '0', 'GIT_HTTP_LOW_SPEED_LIMIT' => '1000', 'GIT_HTTP_LOW_SPEED_TIME' => '20' }.freeze

# Front matter keys the editor edits. Everything else in an existing file
# (layout, published, ...) is carried over untouched on save.
# One-line text fields the public site reads: `excerpt` (blog index), and
# `album_title` / `album_caption` (the gallery card). An empty value removes
# the key; a request that leaves one out keeps what the file has.
POST_TEXT_KEYS = %w[excerpt album_title album_caption].freeze
ALBUM_TEXT_KEYS = %w[album_caption].freeze
POST_KEYS = (%w[layout title date tags description images draft] + POST_TEXT_KEYS).freeze
ALBUM_KEYS = (%w[layout title date description images draft published] + ALBUM_TEXT_KEYS).freeze

THUMB_W = 600
MED_W = 1600
THUMB_Q = 78
MED_Q = 82
VARIANT_EXTS = %w[.png .jpg .jpeg].freeze
STALE_UPLOAD_SECONDS = 24 * 3600

[POSTS_DIR, DRAFTS_DIR, IMAGES_DIR, DRAFT_IMAGES_DIR, ALBUM_IMAGES_DIR, ALBUMS_DIR].each { |d| FileUtils.mkdir_p(d) }
%w[posts drafts albums].each { |d| FileUtils.mkdir_p(File.join(TEMP_IMAGES_DIR, d)) }

class FrontMatterError < StandardError; end
class BadDateError < StandardError; end

# WEBrick serves requests on threads. Every write route runs under this lock,
# so a version check and the write that follows (and every read-modify-write
# of _data/image_meta.yml) happen as one step.
WRITE_LOCK = Mutex.new

helpers do
  def json(body, status = 200)
    content_type :json
    halt status, JSON.generate(body)
  end

  def json_error(status, message, extra = {})
    json({ 'error' => message }.merge(extra), status)
  end

  # Serialize a write route; a bad form date anywhere inside becomes a 422.
  def locked
    WRITE_LOCK.synchronize { yield }
  rescue BadDateError => e
    json_error(422, e.message, 'code' => 'bad_date')
  end

  def allowed_origin?(origin)
    ALLOWED_ORIGINS.include?(origin.to_s)
  end

  def allowed_host?(host)
    ALLOWED_HOSTS.include?(host.to_s.downcase)
  end

  # Expand `path` and return it only if it lies strictly inside one of `roots`
  # (absolute, already-expanded directories). Returns nil otherwise, so `../`
  # tricks in request data can never reach files outside the image folders.
  def confined_path(path, *roots)
    abs = File.expand_path(path.to_s)
    roots.any? { |root| abs.start_with?(root.chomp('/') + '/') } ? abs : nil
  end

  # Absolute path for a site-relative image src like "/assets/images/posts/x.png",
  # or nil unless it is inside assets/images/{posts,drafts,albums}/.
  def image_src_path(src)
    confined_path(File.join(ROOT, src.to_s.sub(%r{\A/+}, '')), *CONTENT_IMAGE_ROOTS)
  end

  # Parse a JSON request body. Rejects anything not sent as application/json
  # (blocks form/text-plain cross-site requests that skip CORS preflight).
  def json_body
    unless request.content_type.to_s.downcase.start_with?('application/json')
      halt 415, 'Content-Type must be application/json'
    end
    data = JSON.parse(request.body.read)
    halt 400, 'JSON object expected' unless data.is_a?(Hash)
    data
  rescue JSON::ParserError
    halt 400, 'invalid JSON'
  end

  def sanitize_slug(slug)
    slug.to_s.strip.downcase.gsub(/[^a-z0-9]+/, '-').gsub(/^-+|-+$/, '')
  end

  def post_files
    Dir[File.join(POSTS_DIR, '*.md')].sort
  end

  def draft_files
    Dir[File.join(DRAFTS_DIR, '*.md')].sort
  end

  def all_post_files
    post_files + draft_files
  end

  def album_files
    Dir[File.join(ALBUMS_DIR, '*.md')].sort
  end

  def slug_from_path(path)
    return nil unless path
    if File.dirname(path) == DRAFTS_DIR
      File.basename(path, '.md')
    else
      File.basename(path, '.md').split('-', 4)[3] || File.basename(path, '.md')
    end
  end

  # Content hash sent to the client with every item and checked on write, so a
  # stale tab cannot silently overwrite a file that changed on disk.
  def file_version(path)
    Digest::SHA1.hexdigest(File.binread(path))[0, 16]
  end

  # [front matter hash, body]. Raises FrontMatterError when the file has no
  # front matter block or it does not parse: saving over a file we could not
  # read would wipe its title and tags.
  def read_front_matter(path)
    content = File.read(path)
    raise FrontMatterError, "#{rel_path(path)} has no front matter block" unless content =~ /\A---\s*\n(.*?)\n---\s*\n?(.*)\z/m
    front_matter = $1
    body = $2
    parsed =
      begin
        YAML.safe_load(front_matter, permitted_classes: [Date, Time], aliases: true)
      rescue StandardError => e
        raise FrontMatterError, "Front matter in #{rel_path(path)} does not parse: #{e.message}"
      end
    parsed = {} if parsed.nil?
    raise FrontMatterError, "Front matter in #{rel_path(path)} is not a key/value map" unless parsed.is_a?(Hash)
    [parsed, body]
  end

  # read_front_matter for routes: answers 422 with the parser message.
  def front_matter!(path)
    read_front_matter(path)
  rescue FrontMatterError => e
    json_error(422, e.message, 'code' => 'front_matter')
  end

  def date_string(date_val)
    date = date_val.respond_to?(:iso8601) ? date_val.iso8601 : date_val.to_s.strip
    date.empty? ? nil : date
  end

  def parse_image_list(images_val)
    return [] unless images_val.is_a?(Array)
    images_val.select { |i| i.is_a?(Hash) && i['src'].to_s.strip != '' }.map do |i|
      { 'src' => i['src'].to_s.strip, 'caption' => i['caption'].to_s.strip }
    end
  end

  def parse_images_from_data(data)
    parse_image_list(Array(data['images']))
  end

  # A one-line front matter value: whitespace runs (newlines included) become
  # one space, so the field stays a single YAML line.
  def one_line(val)
    val.to_s.gsub(/\s+/, ' ').strip
  end

  # The one-line text fields (POST_TEXT_KEYS / ALBUM_TEXT_KEYS) for a write:
  # the request's value when it sent the key, else the file's.
  def text_fields(keys, data, existing_data)
    keys.to_h { |k| [k, one_line(data.key?(k) ? data[k] : existing_data[k])] }
  end

  # `key: "value"` lines for the non-empty fields, in `keys` order.
  def text_fields_to_frontmatter(keys, fields)
    keys.reject { |k| fields[k].to_s.empty? }.map { |k| "#{k}: #{yaml_quote(fields[k])}\n" }.join
  end

  def truthy?(val)
    val == true || val.to_s.strip.downcase == 'true'
  end

  def rel_path(abs)
    abs.to_s.sub(ROOT + '/', '')
  end

  # URL Jekyll serves a post at (permalink /blog/:year/:month/:day/:title/).
  # A draft without a date is dated by its mtime (that is what Jekyll does).
  def post_url(path, date, slug)
    time = date ? ((Time.parse(date) rescue nil)&.localtime) : nil
    "/blog/#{(time || File.mtime(path)).strftime('%Y/%m/%d')}/#{slug}/"
  end

  def parse_post(path)
    data, body = read_front_matter(path)
    slug = slug_from_path(path)
    title = data['title'].to_s.strip
    title = slug.to_s.gsub(/[-_]+/, ' ').split.map(&:capitalize).join(' ') if title.empty?
    tags_val = data['tags']
    tags =
      case tags_val
      when Array then tags_val.map { |t| t.to_s.strip }.reject(&:empty?)
      when NilClass then []
      else tags_val.to_s.gsub(/[\[\]]/, '').split(',').map(&:strip).reject(&:empty?)
      end
    date = date_string(data['date'])
    {
      'title' => title,
      'date' => date,
      'tags' => tags,
      'description' => data['description'].to_s.strip,
      **POST_TEXT_KEYS.to_h { |k| [k, one_line(data[k])] },
      'kind' => (File.dirname(path) == DRAFTS_DIR ? 'draft' : 'post'),
      'slug' => slug,
      'images' => parse_image_list(data['images']),
      'path' => rel_path(path),
      'url' => post_url(path, date, slug),
      'version' => file_version(path),
      'body' => body
    }
  end

  # An album is a draft if it says `draft: true` or `published: false`.
  def parse_album(path)
    data, = read_front_matter(path)
    slug = File.basename(path, '.md')
    title = data['title'].to_s.strip
    {
      'title' => title.empty? ? slug : title,
      'date' => date_string(data['date']),
      'description' => data['description'].to_s.strip,
      **ALBUM_TEXT_KEYS.to_h { |k| [k, one_line(data[k])] },
      'draft' => truthy?(data['draft']) || data['published'] == false,
      'kind' => 'album',
      'slug' => slug,
      'images' => parse_image_list(data['images']),
      'path' => rel_path(path),
      'url' => "/albums/#{slug}/",
      'version' => file_version(path)
    }
  end

  # Sidebar row: no body, no image list. A file whose front matter does not
  # parse still gets a row (with `error`) so it can be found and fixed.
  # `mtime` lets the studio open the most recently edited item on load.
  def summary(path, kind)
    item = kind == 'album' ? parse_album(path) : parse_post(path)
    item.reject { |k, _| %w[body images].include?(k) }.merge('image_count' => item['images'].length, 'mtime' => File.mtime(path).to_i)
  rescue FrontMatterError => e
    slug = kind == 'album' ? File.basename(path, '.md') : slug_from_path(path)
    { 'title' => slug, 'slug' => slug, 'kind' => kind == 'album' ? 'album' : (File.dirname(path) == DRAFTS_DIR ? 'draft' : 'post'),
      'path' => rel_path(path), 'image_count' => 0, 'error' => e.message }
  end

  # Find a post file by kind + slug. Matches the slug exactly, so "blog-post"
  # never resolves to "first-real-blog-post".
  def find_post_path(kind, slug)
    if kind == 'draft'
      path = File.join(DRAFTS_DIR, "#{slug}.md")
      File.exist?(path) ? path : nil
    else
      post_files.find { |p| slug_from_path(p) == slug }
    end
  end

  # A string as a YAML double-quoted scalar. JSON strings are valid YAML, and
  # this escapes backslashes and control characters that a bare gsub misses.
  def yaml_quote(str)
    JSON.generate(str.to_s)
  end

  # Tags stay bare in `tags: [a, b]` (the existing style) unless they contain
  # characters that would break a YAML flow sequence.
  def tag_scalar(tag)
    tag =~ /[,\[\]{}:#"]|\A[\s\-?!&*|>%@`']|\s\z/ ? yaml_quote(tag) : tag
  end

  # Parse a date from the form ("2026-04-26T13:25", local wall time). If it
  # shows the same wall-clock minute as the existing front matter date, keep
  # the existing string, so re-saving never churns seconds or a UTC offset
  # written in another DST period.
  def resolve_date(date_str, existing = nil)
    date_str = date_str.to_s.strip
    if existing && !date_str.empty?
      old = existing.to_s.strip
      wall = old.length == 10 ? "#{old}T00:00" : old[0, 16].tr(' ', 'T')
      return [(Time.parse(old) rescue Time.now), old] if wall == date_str[0, 16]
    end
    time = parse_form_date(date_str)
    [time, time.iso8601]
  end

  # A date from the form, or now when empty. Anything that is not a real
  # YYYY-MM-DD[THH:MM[:SS]] date raises BadDateError (422) instead of being
  # written to the file.
  def parse_form_date(date_str)
    return Time.now if date_str.to_s.strip.empty?
    unless date_str =~ /\A\d{4}-\d{2}-\d{2}([T ]\d{2}:\d{2}(:\d{2})?)?\z/
      raise BadDateError, "\"#{date_str}\" is not a date (use YYYY-MM-DDTHH:MM)."
    end
    time = Time.parse(date_str)
    raise BadDateError, "\"#{date_str}\" is not a real date." unless time.strftime('%Y-%m-%d') == date_str[0, 10]
    time
  rescue ArgumentError
    raise BadDateError, "\"#{date_str}\" is not a real date."
  end

  # YAML for front matter keys the editor does not manage (carried over as-is).
  def extra_front_matter(data, managed)
    extras = (data || {}).reject { |k, _| managed.include?(k.to_s) }
    return '' if extras.empty?
    extras.to_yaml(line_width: -1).sub(/\A---\s*\n/, '')
  end

  def images_to_frontmatter(images)
    return '' if images.empty?
    fm = +"images:\n"
    images.each do |img|
      fm << "  - src: #{yaml_quote(img['src'])}\n"
      fm << "    caption: #{yaml_quote(img['caption'])}\n" unless img['caption'].to_s.empty?
    end
    fm
  end

  def post_front_matter(layout:, title:, date:, tags:, description:, images:, text: {}, extra: '')
    fm = +"---\n"
    fm << "layout: #{layout}\n"
    fm << "title: #{yaml_quote(title)}\n"
    fm << "date: #{date}\n" if date
    fm << "tags: [#{tags.map { |t| tag_scalar(t) }.join(', ')}]\n" unless tags.empty?
    fm << "description: #{yaml_quote(description)}\n" unless description.to_s.strip.empty?
    fm << text_fields_to_frontmatter(POST_TEXT_KEYS, text)
    fm << extra
    fm << images_to_frontmatter(images)
    fm << "---\n\n"
    fm
  end

  # Jekyll ignores `draft:` on collections, so a draft album also gets
  # `published: false` (otherwise its page builds and lands in the sitemap).
  def album_to_file(album, layout: 'album', extra: '')
    fm = +"---\nlayout: #{layout}\n"
    fm << "title: #{yaml_quote(album['title'])}\n"
    fm << "date: #{album['date']}\n" if album['date']
    fm << "description: #{yaml_quote(album['description'])}\n" unless album['description'].to_s.empty?
    fm << text_fields_to_frontmatter(ALBUM_TEXT_KEYS, album)
    fm << "draft: true\npublished: false\n" if album['draft']
    fm << extra
    fm << images_to_frontmatter(album['images'] || [])
    fm << "---\n"
    fm
  end

  # Standalone image lines (`![alt](url)`, optional blank line + *caption*)
  # become album entries: [{src, caption}].
  def extract_body_images(body)
    results = []
    lines = body.to_s.lines.map(&:chomp)
    i = 0
    while i < lines.length
      if lines[i] =~ /^!\[([^\]]*)\]\(([^)]+)\)\s*$/
        alt = $1.to_s.strip
        src = unwrap_liquid($2.to_s.strip)
        caption = alt
        if i + 2 < lines.length && lines[i + 1].strip.empty? && lines[i + 2] =~ /^\*(.+)\*$|^_(.+)_$/
          caption = ($1 || $2).to_s.strip
          i += 2
        end
        results << { 'src' => src, 'caption' => caption } if src =~ %r{/assets/images/}
      end
      i += 1
    end
    results
  end

  # The editor wraps paths as {{ '/assets/...' | relative_url }}.
  def unwrap_liquid(src)
    src =~ /\A\{\{\s*'([^']+)'\s*\|\s*relative_url\s*\}\}\z/ ? $1 : src
  end

  # Every /assets/images/... URL anywhere in a body (inline images too), for
  # cleanup when a post is deleted.
  def body_image_srcs(body)
    body.to_s.scan(%r{/assets/images/[^\s)"'<>]+}).uniq
  end

  # Merge body-extracted images with explicit album images, deduplicating by src.
  # Album images come first and keep their captions.
  def merge_images(body_images, album_images)
    seen = {}
    (album_images + body_images).each_with_object([]) do |img, merged|
      key = img['src'].to_s.strip
      next if key.empty? || seen[key]
      seen[key] = true
      merged << img
    end
  end

  # Files (posts, drafts, albums) whose text contains `src`.
  def find_image_references(src, exclude_path: nil)
    (all_post_files + album_files).reject { |p| p == exclude_path }.select { |p| File.read(p).include?(src) }
  end

  # Delete an image (plus -thumb/-med and its manifest entry) if nothing else
  # references it and it lives in a content image folder. true if deleted.
  # The canonical site path for a content image (/assets/images/<dir>/<file>),
  # built from the expanded, confined path; nil outside the content folders.
  def canonical_src(src)
    abs = image_src_path(src)
    abs && '/' + abs.sub(ROOT + '/', '')
  end

  def variant_file?(path)
    File.basename(path.to_s) =~ /-(thumb|med)\.jpg\z/i
  end

  # References are checked against the canonical path as well as the given
  # one, so "posts/./x.png" cannot slip past a file that uses "posts/x.png".
  # Variants are never deleted on their own, only with their source.
  def delete_image_if_orphaned(src, exclude_path: nil)
    return false if src.to_s.strip.empty?
    abs = image_src_path(src)
    return false unless abs && !variant_file?(abs)
    [src, canonical_src(src)].uniq.each { |s| return false unless find_image_references(s, exclude_path: exclude_path).empty? }
    deleted = File.exist?(abs) && File.delete(abs) && true
    if VARIANT_EXTS.include?(File.extname(abs).downcase) && File.basename(abs) !~ /-(thumb|med)\.jpg\z/i
      %w[thumb med].each do |v|
        variant_abs = variant_abs_path(abs, v)
        File.delete(variant_abs) if File.exist?(variant_abs)
      end
      remove_image_manifest_entry(image_meta_key(abs))
    end
    deleted
  end

  def ext_for_mime(mime)
    { 'image/jpeg' => 'jpg', 'image/jpg' => 'jpg', 'image/png' => 'png', 'image/gif' => 'gif',
      'image/webp' => 'webp', 'image/svg+xml' => 'svg' }.fetch(mime.to_s.downcase, 'bin')
  end

  # Move images from _editor_tmp/ to assets/images/ when a post is saved.
  # Also auto-generates responsive thumbnails + updates the image_meta manifest.
  def promote_temp_images(body, images = [])
    scannable = body.to_s + images.map { |i| " #{i['src']}" }.join
    scannable.scan(%r{/assets/images/(posts|drafts|albums)/([^\s\)"']+)}).each do |subdir, filename|
      temp = confined_path(File.join(TEMP_IMAGES_DIR, subdir, filename), File.join(TEMP_ROOT, subdir))
      dest = confined_path(File.join(IMAGES_ROOT, subdir, filename), File.join(IMAGES_ROOT, subdir))
      next unless temp && dest
      if File.exist?(temp)
        FileUtils.mkdir_p(File.dirname(dest))
        FileUtils.mv(temp, dest)
        generate_thumbnails_for(dest)
      elsif File.exist?(dest)
        generate_thumbnails_for(dest) unless thumbnails_fresh?(dest)
      end
    end
  end

  # Returns the repo-relative manifest key for an absolute path under
  # assets/images/, e.g. "posts/20260101-foo.png". nil for anything outside.
  def image_meta_key(abs_path)
    prefix = File.join(ROOT, 'assets', 'images') + '/'
    return nil unless abs_path.start_with?(prefix)
    abs_path.sub(prefix, '')
  end

  def variant_abs_path(source_abs, variant)
    dir = File.dirname(source_abs)
    base = File.basename(source_abs, File.extname(source_abs))
    File.join(dir, "#{base}-#{variant}.jpg")
  end

  def thumbnails_fresh?(source_abs)
    thumb_abs = variant_abs_path(source_abs, 'thumb')
    med_abs = variant_abs_path(source_abs, 'med')
    File.exist?(thumb_abs) && File.exist?(med_abs) &&
      File.mtime(thumb_abs) >= File.mtime(source_abs) &&
      File.mtime(med_abs) >= File.mtime(source_abs)
  end

  # Generate thumb + med JPEG variants next to source_abs and update the
  # _data/image_meta.yml manifest. No-op without mini_magick + ImageMagick.
  def generate_thumbnails_for(source_abs)
    return unless File.exist?(source_abs)
    return unless VARIANT_EXTS.include?(File.extname(source_abs).downcase)
    return if File.basename(source_abs) =~ /-(thumb|med)\.jpg\z/i
    return unless MINI_MAGICK_AVAILABLE

    key = image_meta_key(source_abs)
    return unless key

    thumb_abs = variant_abs_path(source_abs, 'thumb')
    med_abs = variant_abs_path(source_abs, 'med')
    thumb_w, thumb_h, orig_w, orig_h = write_image_variant(source_abs, thumb_abs, THUMB_W, THUMB_Q)
    med_w, med_h, = write_image_variant(source_abs, med_abs, MED_W, MED_Q)

    update_image_manifest(key) do |entry|
      entry['w'] = orig_w
      entry['h'] = orig_h
      entry['thumb'] = { 'src' => image_meta_key(thumb_abs), 'w' => thumb_w, 'h' => thumb_h }
      entry['med']   = { 'src' => image_meta_key(med_abs),   'w' => med_w,   'h' => med_h }
    end
  rescue StandardError => e
    warn "generate_thumbnails_for(#{source_abs}): #{e.message}"
  end

  def write_image_variant(source_abs, out_abs, max_w, quality)
    img = MiniMagick::Image.open(source_abs)
    orig_w = img.width
    orig_h = img.height
    img.combine_options do |c|
      c.auto_orient
      if File.extname(source_abs).downcase == '.png'
        c.background 'white'
        c.alpha 'remove'
        c.alpha 'off'
      end
      c.strip
      c.resize "#{max_w}x>"
      c.interlace 'Plane'
      c.quality quality.to_s
    end
    img.format 'jpg'
    img.write(out_abs)
    out = MiniMagick::Image.open(out_abs)
    [out.width, out.height, orig_w, orig_h]
  end

  def load_image_manifest
    return {} unless File.exist?(IMAGE_META_PATH)
    data = YAML.safe_load(File.read(IMAGE_META_PATH), aliases: false) || {}
    data.is_a?(Hash) ? data : {}
  rescue StandardError
    {}
  end

  def write_image_manifest(data)
    FileUtils.mkdir_p(File.dirname(IMAGE_META_PATH))
    sorted = data.keys.sort.each_with_object({}) { |k, acc| acc[k] = data[k] }
    header = <<~HEADER
      # Generated by scripts/generate_thumbnails.rb. Do not edit by hand.
      # Each key is a path under assets/images/. `cf_id` (when set) is reserved
      # for Cloudflare Images integration and is preserved on regeneration.
    HEADER
    tmp = "#{IMAGE_META_PATH}.tmp"
    File.write(tmp, header + sorted.to_yaml(line_width: -1))
    File.rename(tmp, IMAGE_META_PATH)
  end

  def update_image_manifest(key)
    manifest = load_image_manifest
    entry = manifest[key] || {}
    preserved_cf = entry['cf_id']
    yield entry
    entry['cf_id'] = preserved_cf if preserved_cf
    manifest[key] = entry
    write_image_manifest(manifest)
  end

  def remove_image_manifest_entry(key)
    return unless key
    manifest = load_image_manifest
    return unless manifest.key?(key)
    manifest.delete(key)
    write_image_manifest(manifest)
  end

  # Copy an image with its -thumb/-med variants and manifest entry (under the
  # new key). Regenerates variants when the source had none.
  def copy_image(src_abs, dest_abs)
    FileUtils.mkdir_p(File.dirname(dest_abs))
    FileUtils.cp(src_abs, dest_abs)
    return unless VARIANT_EXTS.include?(File.extname(src_abs).downcase)
    %w[thumb med].each do |v|
      from = variant_abs_path(src_abs, v)
      FileUtils.cp(from, variant_abs_path(dest_abs, v)) if File.exist?(from)
    end
    manifest = load_image_manifest
    entry = manifest[image_meta_key(src_abs)]
    if entry
      entry = Marshal.load(Marshal.dump(entry))
      %w[thumb med].each { |v| entry[v]['src'] = image_meta_key(variant_abs_path(dest_abs, v)) if entry[v].is_a?(Hash) }
      manifest[image_meta_key(dest_abs)] = entry
      write_image_manifest(manifest)
      generate_thumbnails_for(dest_abs) unless thumbnails_fresh?(dest_abs)
    else
      # No entry to copy (even if variant files exist): regenerate, which also
      # writes the manifest entry for the posts/ copy.
      generate_thumbnails_for(dest_abs)
    end
  end

  # Publishing a draft: images under assets/images/drafts/ (gitignored) are
  # copied to posts/ (with variants and manifest entry) and the body/images
  # paths rewritten. Returns [body, draft srcs]; the caller deletes each draft
  # copy after writing the post, and only if nothing else still uses it.
  # (Going the other way, post -> draft, leaves images in posts/.)
  def promote_draft_images(body, images)
    body = body.to_s.dup
    names = body.scan(%r{/assets/images/drafts/([^\s\)"'<>]+)}).flatten
    names += images.map { |i| i['src'][%r{\A/assets/images/drafts/(.+)\z}, 1] }.compact
    moved = []
    names.uniq.each do |fname|
      src = confined_path(File.join(DRAFT_IMAGES_DIR, fname), DRAFT_IMAGES_DIR)
      dest = confined_path(File.join(IMAGES_DIR, fname), IMAGES_DIR)
      next unless src && dest
      if File.exist?(src) && File.exist?(dest) && !FileUtils.compare_file(src, dest)
        warn "promote_draft_images: a different #{rel_path(dest)} exists; leaving #{fname} in drafts/"
        next
      end
      copy_image(src, dest) if File.exist?(src) && !File.exist?(dest)
      old_src = "/assets/images/drafts/#{fname}"
      body.gsub!(old_src, "/assets/images/posts/#{fname}")
      images.each { |img| img['src'] = "/assets/images/posts/#{fname}" if img['src'] == old_src }
      moved << old_src
    end
    [body, moved]
  end

  # Extract markdown images that embed base64 data URLs:
  #   ![alt](data:image/png;base64,AAAA...)
  # Writes decoded files under drafts/posts images folder and rewrites URLs.
  def extract_base64_images(body, slug:, draft:)
    out = body.to_s.dup
    dest_dir = draft ? DRAFT_IMAGES_DIR : IMAGES_DIR
    url_prefix = draft ? '/assets/images/drafts/' : '/assets/images/posts/'
    idx = 0
    # Stop at ')' to avoid swallowing the whole file. This matches the common markdown pattern.
    re = /!\[(?<alt>[^\]]*)\]\((?<data>data:(?<mime>image\/[^;)\s]+);base64,(?<b64>[^)]+))\)/
    out.gsub!(re) do
      idx += 1
      ext = ext_for_mime(Regexp.last_match(:mime))
      b64 = Regexp.last_match(:b64)
      alt = Regexp.last_match(:alt).to_s
      filename_base = "embedded-#{sanitize_slug(slug)}-#{idx}"
      filename = "#{filename_base}.#{ext}"
      n = 1
      while File.exist?(File.join(dest_dir, filename))
        filename = "#{filename_base}-#{n}.#{ext}"
        n += 1
      end
      FileUtils.mkdir_p(dest_dir)
      File.binwrite(File.join(dest_dir, filename), Base64.decode64(b64))
      "![#{alt}](#{url_prefix}#{filename})"
    end
    out
  end

  # 409 when the client's copy is older than the file on disk (unless forced).
  def check_version!(path, data)
    sent = data['version'].to_s
    return if sent.empty? || data['force'] || !File.exist?(path)
    current = file_version(path)
    return if sent == current
    json_error(409, "#{rel_path(path)} changed on disk since you opened it.", 'code' => 'stale', 'version' => current)
  end

  # Create (existing_path nil), update, or publish (force_post) a post/draft.
  # One code path so every write gets the same date, uniqueness, image, and
  # front matter rules. Returns the response hash.
  def save_post(data, existing_path: nil, force_post: false)
    existing_data = existing_path ? front_matter!(existing_path)[0] : {}
    check_version!(existing_path, data) if existing_path
    title = data['title'].to_s.strip
    body = data['body'].to_s
    halt 400, 'title required' if title.empty?
    halt 400, 'body required' if body.strip.empty?

    slug = sanitize_slug(data['slug'] || (existing_path && slug_from_path(existing_path)) || title)
    halt 400, 'title must contain letters or numbers' if slug.empty?
    draft = force_post ? false : !!data['draft']

    # Drafts keep a date if they have one (a post turned back into a draft
    # keeps its date and URL, and gets it back on publish). Posts always have
    # one: the form's, else the existing one, else now.
    existing_date = date_string(existing_data['date'])
    date_str = data['date'].to_s.strip
    if !date_str.empty?
      time, date = resolve_date(date_str, existing_date)
    elsif existing_date
      time = (Time.parse(existing_date) rescue Time.now)
      date = existing_date
    elsif !draft
      time, date = resolve_date('')
    end

    tags = Array(data['tags'] || []).map { |t| t.to_s.strip }.reject(&:empty?)
    description = data.key?('description') ? data['description'].to_s.strip : existing_data['description'].to_s.strip
    images = data.key?('images') ? parse_images_from_data(data) : parse_image_list(existing_data['images'])
    text = text_fields(POST_TEXT_KEYS, data, existing_data)

    new_path = draft ? File.join(DRAFTS_DIR, "#{slug}.md") : File.join(POSTS_DIR, "#{time.strftime('%Y-%m-%d')}-#{slug}.md")
    json_error(409, "#{rel_path(new_path)} already exists.") if new_path != existing_path && File.exist?(new_path)
    unless draft
      other = find_post_path('post', slug)
      json_error(409, "A post with the slug \"#{slug}\" already exists (#{rel_path(other)}).") if other && other != existing_path
    end

    body = extract_base64_images(body, slug: slug, draft: draft)
    promote_temp_images(body, images)
    body, promoted = draft ? [body, []] : promote_draft_images(body, images)
    images = merge_images(extract_body_images(body), images)

    fm = post_front_matter(layout: existing_data['layout'] || 'post', title: title, date: date, tags: tags,
                           description: description, images: images, text: text,
                           extra: extra_front_matter(existing_data, POST_KEYS))
    File.write(new_path, fm + body)
    File.delete(existing_path) if existing_path && existing_path != new_path && File.exist?(existing_path)
    # Draft copies of promoted images go once no other draft still uses them.
    promoted.each { |src| delete_image_if_orphaned(src) }

    { 'slug' => slug, 'kind' => (draft ? 'draft' : 'post'), 'date' => time&.strftime('%Y-%m-%dT%H:%M'),
      'path' => rel_path(new_path), 'version' => file_version(new_path), 'url' => post_url(new_path, date, slug) }
  end

  def save_album(data, existing_path: nil)
    existing_data = existing_path ? front_matter!(existing_path)[0] : {}
    check_version!(existing_path, data) if existing_path
    title = data['title'].to_s.strip
    halt 400, 'title required' if title.empty?
    slug = sanitize_slug(data['slug'] || (existing_path && File.basename(existing_path, '.md')) || title)
    halt 400, 'title must contain letters or numbers' if slug.empty?
    new_path = File.join(ALBUMS_DIR, "#{slug}.md")
    json_error(409, "#{rel_path(new_path)} already exists.") if new_path != existing_path && File.exist?(new_path)

    images = parse_images_from_data(data)
    time, date = resolve_date(data['date'], date_string(existing_data['date']))
    promote_temp_images('', images)
    album = {
      'title' => title, 'date' => date, 'description' => data['description'].to_s.strip[0, 500],
      'draft' => !!data['draft'], 'images' => images
    }.merge(text_fields(ALBUM_TEXT_KEYS, data, existing_data))
    File.write(new_path, album_to_file(album, layout: existing_data['layout'] || 'album',
                                              extra: extra_front_matter(existing_data, ALBUM_KEYS)))
    File.delete(existing_path) if existing_path && existing_path != new_path && File.exist?(existing_path)
    { 'slug' => slug, 'date' => time.strftime('%Y-%m-%dT%H:%M'), 'path' => rel_path(new_path), 'version' => file_version(new_path) }
  end

  # --- git (publish flow) ---

  # Run git with an argument list (never a shell string) in the repo root.
  def git(*args)
    Open3.capture3(GIT_ENV, 'git', *args, chdir: ROOT)
  end

  def git_out(*args)
    out, _err, st = git(*args)
    st.success? ? out.strip : nil
  end

  # Changed files under GIT_CONTENT_PATHS as [{status, path}]. -z and
  # --no-renames keep the parsing trivial (no quoting, no "a -> b").
  def git_changed_files
    out, _err, st = git('status', '--porcelain=v1', '-z', '--untracked-files=all', '--no-renames', '--', *GIT_CONTENT_PATHS)
    return [] unless st.success?
    out.split("\0").map { |e| { 'status' => e[0, 2].strip, 'path' => e[3..].to_s } }.reject { |f| f['path'].empty? }
  end

  # Name of an operation that makes committing unsafe, or nil.
  def git_busy
    git_dir = git_out('rev-parse', '--absolute-git-dir')
    return 'unknown git directory' unless git_dir
    {
      'rebase-merge' => 'rebase', 'rebase-apply' => 'rebase', 'MERGE_HEAD' => 'merge',
      'CHERRY_PICK_HEAD' => 'cherry-pick', 'REVERT_HEAD' => 'revert'
    }.each { |file, name| return name if File.exist?(File.join(git_dir, file)) }
    nil
  end

  # Label changed files for the publish panel: titles for posts/albums, and
  # `draft_only` for draft albums and images that only draft albums or
  # _drafts/ files use (the panel leaves those unticked).
  def annotate_files(files)
    texts = (all_post_files + album_files).to_h { |p| [p, File.read(p)] }
    draft_album = lambda do |p|
      p.start_with?(ALBUMS_DIR + '/') && (parse_album(p)['draft'] rescue false)
    end
    draft_src = lambda do |src|
      refs = texts.select { |_, t| t.include?(src) }.keys
      refs.any? && refs.all? { |p| p.start_with?(DRAFTS_DIR + '/') || draft_album.call(p) }
    end
    files.each do |f|
      abs = File.join(ROOT, f['path'])
      if f['path'] =~ %r{\A_(posts|albums)/.+\.md\z} && File.exist?(abs)
        item = (f['path'].start_with?('_albums/') ? parse_album(abs) : parse_post(abs) rescue nil)
        f['title'] = item['title'] if item
        f['draft_only'] = true if item && draft_album.call(abs)
      elsif (m = f['path'].match(%r{\Aassets/images/(posts|albums)/(.+?)(-thumb\.jpg|-med\.jpg)?\z}))
        sub = m[1]
        base = m[3] ? m[2] : m[2].sub(/\.[^.]+\z/, '')
        # A -thumb/-med file belongs to the source image with the same base name.
        source = Dir[File.join(IMAGES_ROOT, sub, "#{base}.*")].find { |p| p !~ /-(thumb|med)\.jpg\z/i }
        src = source && "/assets/images/#{sub}/#{File.basename(source)}"
        f['draft_only'] = true if src && draft_src.call(src)
      elsif f['path'] == '_data/image_meta.yml'
        # Draft-only when every entry that differs from HEAD belongs to a
        # draft image (drafts/ or used only by draft albums / _drafts files).
        old = (YAML.safe_load(git_out('show', 'HEAD:_data/image_meta.yml').to_s) rescue nil) || {}
        cur = load_image_manifest
        keys = (old.keys | cur.keys).reject { |k| old[k] == cur[k] }
        f['draft_only'] = true if keys.any? && keys.all? { |k| k.start_with?('drafts/') || draft_src.call("/assets/images/#{k}") }
      end
    end
  end

  def git_state(fetch: false)
    fetch_error = nil
    if fetch
      _out, err, st = git('fetch', '--quiet', 'origin')
      fetch_error = err.strip.empty? ? 'git fetch failed' : err.strip unless st.success?
    end
    branch = git_out('rev-parse', '--abbrev-ref', 'HEAD')
    upstream = git_out('rev-parse', '--abbrev-ref', '--symbolic-full-name', '@{u}')
    behind, ahead = (upstream && git_out('rev-list', '--left-right', '--count', '@{u}...HEAD').to_s.split.map(&:to_i)) || [0, 0]
    unpushed = upstream ? git_out('log', '--format=%h %s', '@{u}..HEAD').to_s.lines.map(&:strip).reject(&:empty?) : []
    {
      'branch' => branch,
      'upstream' => upstream,
      'ahead' => ahead || 0,
      'behind' => behind || 0,
      'unpushed' => unpushed,
      'fetched' => fetch && fetch_error.nil?,
      'fetch_error' => fetch_error,
      'head' => git_out('rev-parse', '--short', 'HEAD'),
      'busy' => git_busy,
      'files' => annotate_files(git_changed_files),
      'content_paths' => GIT_CONTENT_PATHS,
      'actions_url' => ACTIONS_URL
    }
  end

  # Files in _editor_tmp/ older than a day (abandoned uploads).
  def stale_uploads
    cutoff = Time.now - STALE_UPLOAD_SECONDS
    Dir[File.join(TEMP_IMAGES_DIR, '{posts,drafts,albums}', '*')].select { |p| File.file?(p) && File.mtime(p) < cutoff }
  end
end

before do
  # DNS rebinding: a hostile page can resolve its own name to 127.0.0.1, but it
  # cannot make the browser send Host: 127.0.0.1:4001.
  halt 403, 'Forbidden host' unless allowed_host?(request.env['HTTP_HOST'])

  h = {
    'Access-Control-Allow-Methods' => 'GET,POST,PUT,DELETE,OPTIONS',
    'Access-Control-Allow-Headers' => 'Content-Type'
  }
  origin = request.env['HTTP_ORIGIN']
  h['Access-Control-Allow-Origin'] = origin if origin && allowed_origin?(origin)
  headers h

  # Any other website open in the browser can send requests here (CORS only
  # hides the response). Refuse them outright. Requests without an Origin
  # header (curl, same-origin GETs) are still allowed.
  if origin && !request.options? && !allowed_origin?(origin)
    # A studio served from another local port may read why (it can then say
    # "start the API with STUDIO_SITE_PORT=..."); other sites learn nothing.
    headers 'Access-Control-Allow-Origin' => origin if origin =~ %r{\Ahttp://(127\.0\.0\.1|localhost):\d+\z}
    halt 403, 'Forbidden origin'
  end
end

# CORS preflight for every route (the before filter never blocks OPTIONS).
options '*' do
  200
end

# What this server can do (the studio warns once when thumbnails are off).
get '/info' do
  json({ 'thumbnails' => MINI_MAGICK_AVAILABLE, 'image_tool' => IMAGE_TOOL, 'site_port' => SITE_PORT,
         'stale_uploads' => stale_uploads.length })
end

get '/posts' do
  json(all_post_files.map { |path| summary(path, 'post') })
end

get '/posts/:kind/:slug' do
  path = find_post_path(params[:kind].to_s, sanitize_slug(params[:slug]))
  halt 404 unless path
  front_matter!(path)
  json(parse_post(path))
end

post '/posts' do
  locked do
    json(save_post(json_body), 201)
  end
end

put '/posts/:kind/:slug' do
  locked do
    existing_path = find_post_path(params[:kind].to_s, sanitize_slug(params[:slug]))
    halt 404 unless existing_path
    json(save_post(json_body, existing_path: existing_path))
  end
end

# Same as PUT with draft: false (kept for scripts and older clients).
post '/publish/:slug' do
  locked do
    draft_path = find_post_path('draft', sanitize_slug(params[:slug]))
    halt 404 unless draft_path
    json(save_post(json_body, existing_path: draft_path, force_post: true), 201)
  end
end

delete '/posts/:kind/:slug' do
  locked do
    path = find_post_path(params[:kind].to_s, sanitize_slug(params[:slug]))
    halt 404 unless path
    data, body = front_matter!(path)
    check_version!(path, 'version' => params['version'])

    # Every image the file mentions: `images:` plus any /assets/images/ URL in
    # the body (inline images included), collected before the file goes away.
    image_srcs = (parse_image_list(data['images']).map { |i| i['src'] } + body_image_srcs(body)).uniq
    File.delete(path)
    image_srcs.each { |src| delete_image_if_orphaned(src, exclude_path: path) }
    status 204
  end
end

# --- Standalone Album CRUD ---

get '/albums' do
  json(album_files.map { |path| summary(path, 'album') })
end

get '/albums/:slug' do
  path = File.join(ALBUMS_DIR, "#{sanitize_slug(params[:slug])}.md")
  halt 404 unless File.exist?(path)
  front_matter!(path)
  json(parse_album(path))
end

post '/albums' do
  locked do
    json(save_album(json_body), 201)
  end
end

put '/albums/:slug' do
  locked do
    existing_path = File.join(ALBUMS_DIR, "#{sanitize_slug(params[:slug])}.md")
    halt 404 unless File.exist?(existing_path)
    json(save_album(json_body, existing_path: existing_path))
  end
end

delete '/albums/:slug' do
  locked do
    path = File.join(ALBUMS_DIR, "#{sanitize_slug(params[:slug])}.md")
    halt 404 unless File.exist?(path)
    data, body = front_matter!(path)
    check_version!(path, 'version' => params['version'])
    image_srcs = (parse_image_list(data['images']).map { |i| i['src'] } + body_image_srcs(body)).uniq
    File.delete(path)
    image_srcs.each { |src| delete_image_if_orphaned(src, exclude_path: path) }
    status 204
  end
end

# --- Images ---

# Delete an image the editor removed, if no post or album references it.
# Body: { "src": "/assets/images/albums/photo.jpg" }. Only files under
# assets/images/{posts,drafts,albums}/ can be deleted. The studio calls this
# after its undo window; while a saved file still references the image the
# answer is "still referenced" and the studio retries after the next save.
# Also removes an unsaved upload still waiting in _editor_tmp/, plus the
# -thumb/-med variants and the image_meta.yml entry of a promoted image.
post '/images/delete' do
  locked do
    data = json_body
    src = data['src'].to_s.strip
    halt 400, 'src required' if src.empty?
    abs = image_src_path(src)
    halt 400, 'src must be inside /assets/images/{posts,drafts,albums}/' unless abs
    # Only the exact canonical path is accepted (no ./, //, or ..), and never a
    # -thumb/-med variant: those go only together with their source.
    halt 400, "src must be written canonically (#{canonical_src(src)})" unless canonical_src(src) == src
    halt 400, 'thumbnail variants are deleted together with their source image' if variant_file?(abs)

    refs = find_image_references(src)
    json({ deleted: false, reason: 'still referenced', references: refs.length }) unless refs.empty?

    temp = confined_path(File.join(TEMP_IMAGES_DIR, src.sub(%r{\A/+assets/images/}, '')), TEMP_ROOT)
    temp_deleted = temp && File.file?(temp) ? (File.delete(temp) && true) : false
    deleted = delete_image_if_orphaned(src)
    json(deleted || temp_deleted ? { deleted: true, src: src } : { deleted: false, reason: 'file not found' })
  end
end

# Serve uploaded images directly so the editor preview works without
# waiting for Jekyll to rebuild. Checks temp dir first, then final location.
# ?variant=thumb serves the 600px -thumb.jpg when one exists (studio grid).
get '/assets/images/*' do |path|
  temp_path = confined_path(File.join(TEMP_IMAGES_DIR, path), TEMP_ROOT)
  final_path = confined_path(File.join(IMAGES_ROOT, path), IMAGES_ROOT)
  halt 400, 'invalid path' unless temp_path && final_path
  if File.file?(temp_path)
    send_file temp_path
  elsif File.file?(final_path)
    thumb = variant_abs_path(final_path, 'thumb')
    send_file(params['variant'] == 'thumb' && File.file?(thumb) ? thumb : final_path)
  else
    halt 404
  end
end

post '/images' do
  locked do
    file = params['image'] && params['image'][:tempfile]
    filename = params['image'] && params['image'][:filename]
    halt 400, 'no image' unless file && filename

    safe = filename.gsub(/[^a-zA-Z0-9.\-]/, '_')
    basename = File.basename(safe, '.*')
    ext = File.extname(safe)
    halt 415, 'SVG images are not supported' if ext.downcase == '.svg'
    ts = Time.now.strftime('%Y%m%d%H%M%S')
    is_album = params['album'].to_s == 'true'
    is_draft = params['draft'].to_s == 'true'
    subdir = is_album ? 'albums' : (is_draft ? 'drafts' : 'posts')
    # Several files uploaded in the same second with the same name would collide.
    final_name = "#{ts}-#{basename}#{ext}"
    n = 1
    while File.exist?(File.join(TEMP_IMAGES_DIR, subdir, final_name)) || File.exist?(File.join(IMAGES_ROOT, subdir, final_name))
      final_name = "#{ts}-#{basename}-#{n}#{ext}"
      n += 1
    end
    # Write to _editor_tmp/ so Jekyll doesn't detect the change and rebuild.
    # Images are promoted to assets/images/ when the post is saved.
    FileUtils.cp(file.path, File.join(TEMP_IMAGES_DIR, subdir, final_name))
    json({ url: "/assets/images/#{subdir}/#{final_name}", basename: basename }, 201)
  end
end

# Abandoned uploads: GET counts them, POST deletes them. Body for POST:
# { "keep": [srcs still used by unsaved edits in the browser] }.
get '/uploads/stale' do
  files = stale_uploads
  json({ 'count' => files.length, 'bytes' => files.sum { |p| File.size(p) } })
end

post '/uploads/cleanup' do
  locked do
    keep = Array(json_body['keep']).map(&:to_s)
    removed = stale_uploads.reject { |p| keep.include?('/assets/images/' + p.sub(TEMP_ROOT + '/', '')) }
    removed.each { |p| File.delete(p) }
    json({ 'deleted' => removed.length })
  end
end

# --- Git (publish to site) ---

# Branch, ahead/behind vs upstream, unpushed commits, and changed content
# files. ?fetch=1 runs `git fetch origin` first so "behind" is current.
get '/git/status' do
  json(git_state(fetch: params['fetch'] == '1'))
end

# Commit and push content files on main. Body: { "message": "...",
# "paths": [subset of the changed files] } or { "push_only": true } to push
# commits that are already made. Fetches first; refuses anything but an
# up-to-date main with no merge/rebase running. Never uses `git add -A` and
# never commits files outside GIT_CONTENT_PATHS, even if others are staged.
post '/git/publish' do
  locked do
    data = json_body
    push_only = data['push_only'] == true
    message = data['message'].to_s.delete("\0").strip
    json_error(400, 'Commit message is empty.') if message.empty? && !push_only

    branch = git_out('rev-parse', '--abbrev-ref', 'HEAD')
    json_error(409, "Publishing only runs on main (current branch: #{branch}).") unless branch == 'main'
    busy = git_busy
    json_error(409, "A #{busy} is in progress. Finish or abort it first.") if busy

    state = git_state(fetch: true)
    json_error(502, "Could not fetch from GitHub, so nothing was published: #{state['fetch_error']}") if state['fetch_error']
    json_error(409, "main is #{state['behind']} commit(s) behind #{state['upstream']}. Run `git pull --rebase` first.") if state['behind'].to_i > 0

    steps = []
    run = lambda do |args|
      out, err, st = git(*args)
      steps << { 'cmd' => "git #{args.first}", 'stdout' => out, 'stderr' => err, 'ok' => st.success? }
      st.success?
    end

    unless push_only
      changed = state['files'].map { |f| f['path'] }
      paths = Array(data['paths']).map(&:to_s)
      json_error(400, 'Only changed content files can be published.') unless (paths - changed).empty?
      json_error(409, 'Nothing to publish.') if paths.empty?
      unless run.call(['add', '--', *paths]) && run.call(['commit', '-m', message, '--', *paths])
        json_error(500, 'git could not commit these files.', 'steps' => steps, 'head' => git_out('rev-parse', '--short', 'HEAD'))
      end
    end
    json_error(409, 'Nothing to push.') if push_only && state['ahead'].to_i.zero?

    head = git_out('rev-parse', '--short', 'HEAD')
    unless run.call(['push', 'origin', 'main'])
      json_error(502, push_only ? 'GitHub rejected the push.' : "Committed #{head} locally, but GitHub rejected the push. Run `git pull --rebase`, then use Push.",
                 'steps' => steps, 'head' => head, 'committed' => !push_only)
    end
    json({ 'ok' => true, 'steps' => steps, 'head' => head, 'actions_url' => ACTIONS_URL })
  end
end

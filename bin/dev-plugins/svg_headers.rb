# frozen_string_literal: true

# Dev-only Jekyll plugin, loaded by bin/dev through its temporary config
# (plugins_dir: [_plugins, bin/dev-plugins]); production builds never load it.
#
# `jekyll serve` on :4000 is an origin the studio API trusts, and it serves
# the uploaded SVGs. The upload sanitizer removes script from them; this adds
# a second layer: every image/svg+xml response from the dev server gets the
# same CSP as the API (no script, no outside loads, sandboxed) and nosniff.
# Other responses (the studio page itself) are untouched.
require 'webrick'

module StudioSvgHeaders
  CSP = "default-src 'none'; style-src 'unsafe-inline'; img-src data:; sandbox"

  def setup_header
    super
    return unless self['content-type'].to_s.start_with?('image/svg+xml')
    self['Content-Security-Policy'] = CSP
    self['X-Content-Type-Options'] = 'nosniff'
  end
end

WEBrick::HTTPResponse.prepend(StudioSvgHeaders) unless WEBrick::HTTPResponse < StudioSvgHeaders

# Jekyll site built by GitHub Actions (.github/workflows/deploy.yml).
# Ruby version: see .ruby-version.
source "https://rubygems.org"

gem "jekyll", "~> 3.8"
gem "webrick", "~> 1.7"
gem "kramdown-parser-gfm"
gem "jekyll-sitemap"
gem "jekyll-feed"

# Local editor server and thumbnail generation (never installed in CI).
group :development do
  gem "sinatra", "~> 3.0"
  gem "mini_magick", "~> 4.12"
end

# Link/HTML checks run by .github/workflows/ci.yml.
group :test do
  gem "html-proofer", "~> 5.0"
end

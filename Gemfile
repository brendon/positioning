source "https://rubygems.org"

# Specify your gem's dependencies in positioning.gemspec
gemspec

gem "rake", "~> 13.3"

# Active Support 7.2.4+ requires minitest < 6. Without this, Bundler picks
# minitest 6 and an older Rails 7.2 patch release instead.
if ENV["RAILS_VERSION"] &&
    Gem::Version.new(ENV["RAILS_VERSION"]) < Gem::Version.new("8.0")
  gem "minitest", "~> 5.25"
else
  gem "minitest", "~> 6.0"
end
gem "minitest-hooks", "~> 1.5.3"
gem "mocha", "~> 3.0.1"

gem "standard", "~> 1.52.0"

# RAILS_VERSION is a minor version (e.g. "7.2"); test against its latest patch release.
if ENV["RAILS_VERSION"]
  gem "activerecord", "~> #{ENV["RAILS_VERSION"]}.0"
  gem "activesupport", "~> #{ENV["RAILS_VERSION"]}.0"
end

case ENV["DB"]
when "sqlite"
  gem "sqlite3", "~> 2.9.0"
when "postgresql"
  gem "pg", "~> 1.6.3"
else
  gem "mysql2", "0.5.6"
end

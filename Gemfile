source "https://rubygems.org"

# Specify your gem's dependencies in positioning.gemspec
gemspec

gem "rake", "~> 13.0"

gem "minitest", "~> 5.0"

gem "standard", "~> 1.3"

if ENV["RAILS_VERSION"]
  gem "activerecord", ENV["RAILS_VERSION"]
  gem "activesupport", ENV["RAILS_VERSION"]

  if Gem::Version.new(ENV["RAILS_VERSION"]) >= Gem::Version.new("7.1.0")
    gem "activerecord-enhancedsqlite3-adapter", "~> 0.8.0"
  end
end

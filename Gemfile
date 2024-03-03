source "https://rubygems.org"

# Specify your gem's dependencies in positioning.gemspec
gemspec

gem "rake", "~> 13.0"

gem "minitest", "~> 5.0"

gem "standard", "~> 1.3"

if ENV["RAILS"]
  gem "activerecord", ENV["RAILS"]
  gem "activesupport", ENV["RAILS"]
end

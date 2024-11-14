source "https://rubygems.org"

# Specify your gem's dependencies in positioning.gemspec
gemspec

gem "rake", "~> 13.0"

gem "minitest", "~> 5.0"
gem "minitest-hooks", "~> 1.5.1"
gem "mocha", "~> 2.1.0"

gem "standard", "~> 1.3"

if ENV["RAILS_VERSION"]
  gem "activerecord", ENV["RAILS_VERSION"]
  gem "activesupport", ENV["RAILS_VERSION"]
end

case ENV["DB"]
when "sqlite"
  if ENV["RAILS_VERSION"] &&
    Gem::Version.new(ENV["RAILS_VERSION"]) >= Gem::Version.new("7.2")
    gem "sqlite3", "~> 2.2.0"
  else
    gem "sqlite3", "~> 1.7.2"
  end
when "postgresql"
  gem "pg", "~> 1.5.5"
else
  gem "mysql2", "~> 0.5.6"
end

source "https://rubygems.org"

# Specify your gem's dependencies in positioning.gemspec
gemspec

gem "rake", "~> 13.3"

gem "minitest", "~> 6.0"
gem "minitest-hooks", "~> 1.5.3"
gem "mocha", "~> 3.0.1"

gem "standard", "~> 1.52.0"

if ENV["RAILS_VERSION"]
  gem "activerecord", ENV["RAILS_VERSION"]
  gem "activesupport", ENV["RAILS_VERSION"]
end

case ENV["DB"]
when "sqlite"
  gem "sqlite3", "~> 2.9.0"
when "postgresql"
  gem "pg", "~> 1.6.3"
else
  gem "mysql2", "0.5.6"
end

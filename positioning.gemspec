require_relative "lib/positioning/version"

Gem::Specification.new do |spec|
  spec.name = "positioning"
  spec.version = Positioning::VERSION
  spec.authors = ["Brendon Muir"]
  spec.email = ["brendon@spike.net.nz"]

  spec.summary = "Simple positioning for Active Record models."
  spec.homepage = "https://github.com/brendon/positioning"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.8"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/brendon/positioning"
  spec.metadata["changelog_uri"] = "https://github.com/brendon/positioning/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Uncomment to register a new dependency of your gem
  spec.add_dependency "activesupport", ">= 4.2" # Decreased to enable compatibility
  spec.add_dependency "activerecord", ">= 4.2" # Decreased to enable compatibility
  spec.add_dependency "bigdecimal", "~> 1.4.0" # Added to avoid error running tests
  spec.add_development_dependency "minitest-hooks", "~> 1.5.1"
  spec.add_development_dependency "mocha", "~> 2.1.0"
  spec.add_development_dependency "mysql2", "~> 0.5.6"
  spec.add_development_dependency "pg", "~> 1.5.5"
  spec.add_development_dependency "sqlite3", "~> 1.7.2"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end

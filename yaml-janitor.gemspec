# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = "yaml-janitor"
  spec.version       = "0.1.0"
  spec.authors       = ["ducks"]
  spec.email         = ["ducks@discourse.org"]

  spec.summary       = "YAML linter that preserves comments using psych-pure"
  spec.description   = "A YAML linter built on psych-pure that can detect and fix common issues while preserving comments"
  spec.homepage      = "https://github.com/ducks/yaml-janitor"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 3.0.0"

  spec.files = Dir["lib/**/*", "bin/*", "README.md", "LICENSE"]
  spec.bindir = "bin"
  spec.executables = ["yaml-janitor"]
  spec.require_paths = ["lib"]

  spec.add_dependency "psych-pure", "~> 0.2"

  spec.add_development_dependency "minitest", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
end

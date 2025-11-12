# frozen_string_literal: true

require "psych/pure"
require "yaml"

require_relative "yaml_janitor/version"
require_relative "yaml_janitor/linter"
require_relative "yaml_janitor/rule"
require_relative "yaml_janitor/violation"
require_relative "yaml_janitor/rules/multiline_certificate"

module YamlJanitor
  class Error < StandardError; end

  class SemanticMismatchError < Error; end

  class << self
    # Convenience method to lint a file
    def lint_file(path, rules: :all, fix: false)
      linter = Linter.new(rules: rules)
      linter.lint_file(path, fix: fix)
    end

    # Convenience method to lint a string
    def lint(yaml_string, rules: :all, fix: false)
      linter = Linter.new(rules: rules)
      linter.lint(yaml_string, fix: fix)
    end
  end
end

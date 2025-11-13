# frozen_string_literal: true

require "psych/pure"
require "yaml"

require_relative "yaml_janitor/version"
require_relative "yaml_janitor/config"
require_relative "yaml_janitor/emitter"
require_relative "yaml_janitor/linter"
require_relative "yaml_janitor/violation"

module YamlJanitor
  class Error < StandardError; end

  class SemanticMismatchError < Error; end

  class << self
    # Convenience method to format a file
    def format_file(path, config: nil)
      linter = Linter.new(config: config)
      linter.lint_file(path, fix: true)
    end

    # Convenience method to format a string
    def format(yaml_string, config: nil)
      linter = Linter.new(config: config)
      linter.lint(yaml_string, fix: true)
    end
  end
end

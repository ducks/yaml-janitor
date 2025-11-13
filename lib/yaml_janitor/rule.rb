# frozen_string_literal: true

module YamlJanitor
  class Rule
    def initialize(config = {})
      @config = config
    end
    # Check for violations in the loaded YAML structure
    # Returns an array of Violation objects
    def check(loaded, file: nil)
      violations = []
      walk(loaded) do |node, path|
        if violation = check_node(node, path)
          violations << Violation.new(
            rule: rule_name,
            message: violation,
            file: file
          )
        end
      end
      violations
    end

    # Fix violations in the loaded YAML structure
    # Modifies the structure in place
    def fix!(loaded)
      walk(loaded) do |node, path|
        fix_node(node, path)
      end
    end

    # Override this to check individual nodes
    def check_node(node, path)
      nil
    end

    # Override this to fix individual nodes
    def fix_node(node, path)
      # No-op by default
    end

    # Override this to provide the rule name
    def rule_name
      self.class.name.split("::").last.downcase
    end

    private

    # Walk the YAML structure, yielding each node with its path
    def walk(node, path = [], &block)
      yield node, path

      # Handle both regular and LoadedHash/LoadedArray from psych-pure
      if hash_like?(node)
        node.each do |key, value|
          walk(value, path + [key], &block)
        end
      elsif array_like?(node)
        node.each_with_index do |value, index|
          walk(value, path + [index], &block)
        end
      end
    end

    def hash_like?(node)
      node.is_a?(Hash) || node.class.name == 'Psych::Pure::LoadedHash'
    end

    def array_like?(node)
      node.is_a?(Array) || node.class.name == 'Psych::Pure::LoadedArray'
    end
  end
end

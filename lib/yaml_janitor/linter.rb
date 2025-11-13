# frozen_string_literal: true

module YamlJanitor
  class Linter
    attr_reader :rules

    def initialize(rules: :all, config: nil, config_path: nil)
      @config = config || Config.new(config_path: config_path)
      @rules = load_rules(rules)
    end

    # Lint a file, optionally fixing issues
    def lint_file(path, fix: false)
      yaml_content = File.read(path)
      result = lint(yaml_content, fix: fix, file: path)

      if fix && result[:fixed]
        File.write(path, result[:output])
      end

      result
    end

    # Lint YAML content, optionally fixing issues
    def lint(yaml_content, fix: false, file: nil)
      violations = []

      # Load with comments
      loaded = Psych::Pure.load(yaml_content, comments: true)

      # Check for violations
      @rules.each do |rule|
        violations += rule.check(loaded, file: file)
      end

      # Apply fixes if requested
      output = yaml_content
      fixed = false

      if fix && violations.any?
        @rules.each do |rule|
          rule.fix!(loaded)
        end

        # Dump back to YAML with configured options
        output = Psych::Pure.dump(loaded, **@config.dump_options)
        fixed = true

        # Paranoid mode: verify semantics match
        verify_semantics!(yaml_content, output)
      end

      {
        violations: violations,
        fixed: fixed,
        output: output
      }
    rescue => e
      {
        violations: [Violation.new(
          rule: :parse_error,
          message: e.message,
          file: file
        )],
        fixed: false,
        output: yaml_content,
        error: e
      }
    end

    private

    def load_rules(rule_specs)
      available_rules = {
        multiline_certificate: Rules::MultilineCertificate,
        trailing_whitespace: Rules::TrailingWhitespace,
        consistent_indentation: Rules::ConsistentIndentation
      }

      if rule_specs == :all
        # Load all enabled rules from config
        rule_names = available_rules.keys.select do |name|
          @config.rule_enabled?(name)
        end
      elsif rule_specs.is_a?(Array)
        rule_names = rule_specs
      else
        raise Error, "Invalid rules specification: #{rule_specs.inspect}"
      end

      rule_names.map do |name|
        rule_class = available_rules[name.to_sym]
        raise Error, "Unknown rule: #{name}" unless rule_class
        next unless @config.rule_enabled?(name)

        rule_class.new(@config.rule_config(name))
      end.compact
    end

    def verify_semantics!(original, fixed)
      original_data = YAML.load(original)
      fixed_data = YAML.load(fixed)

      if original_data != fixed_data
        raise SemanticMismatchError, "Fixed YAML has different semantics than original"
      end
    end
  end
end

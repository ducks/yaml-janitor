# frozen_string_literal: true

module YamlJanitor
  class Linter
    attr_reader :rules

    def initialize(rules: :all)
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

        # Dump back to YAML
        output = Psych::Pure.dump(loaded)
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
      if rule_specs == :all
        # Load all available rules
        [
          Rules::MultilineCertificate.new
        ]
      elsif rule_specs.is_a?(Array)
        # Load specific rules by name
        rule_specs.map do |name|
          case name
          when :multiline_certificate
            Rules::MultilineCertificate.new
          else
            raise Error, "Unknown rule: #{name}"
          end
        end
      else
        raise Error, "Invalid rules specification: #{rule_specs.inspect}"
      end
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

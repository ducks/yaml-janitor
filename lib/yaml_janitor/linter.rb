# frozen_string_literal: true

module YamlJanitor
  class Linter
    def initialize(config: nil, config_path: nil)
      @config = config || Config.new(config_path: config_path)
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

      # Format using our custom emitter
      formatted = Emitter.new(loaded, @config).emit

      # Check if formatting would change the file
      if yaml_content != formatted
        violations << Violation.new(
          rule: :formatting,
          message: "File needs formatting (indentation, style, or whitespace issues)",
          file: file
        )
      end

      # Apply fixes if requested
      output = yaml_content
      fixed = false

      if fix
        output = formatted
        fixed = true

        # Paranoid mode: verify semantics match
        verify_semantics!(yaml_content, output)
      end

      {
        violations: violations,
        fixed: fixed,
        output: output,
        original: yaml_content,
        formatted: formatted
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

    # Generate unified diff between original and formatted content
    def generate_diff(original, formatted, path)
      require 'tempfile'

      # Write to temp files and use system diff
      Tempfile.create(['original', '.yml']) do |orig_file|
        Tempfile.create(['formatted', '.yml']) do |fmt_file|
          orig_file.write(original)
          orig_file.flush
          fmt_file.write(formatted)
          fmt_file.flush

          # Use git diff if available (better formatting), fall back to diff
          diff_cmd = if system('which git > /dev/null 2>&1')
            "git diff --no-index --color=always #{orig_file.path} #{fmt_file.path}"
          else
            "diff -u #{orig_file.path} #{fmt_file.path}"
          end

          diff_output = `#{diff_cmd}`

          # Replace temp file paths with actual path
          # Git adds a/ and b/ prefixes (or just a/b for temp files)
          orig_path_pattern = Regexp.escape(orig_file.path)
          fmt_path_pattern = Regexp.escape(fmt_file.path)

          # Handle various git diff formats
          diff_output.gsub(/a\/#{orig_path_pattern}/, path)
                    .gsub(/b\/#{fmt_path_pattern}/, "#{path} (formatted)")
                    .gsub(/a#{orig_path_pattern}/, path)
                    .gsub(/b#{fmt_path_pattern}/, "#{path} (formatted)")
                    .gsub(/#{orig_path_pattern}/, path)
                    .gsub(/#{fmt_path_pattern}/, "#{path} (formatted)")
        end
      end
    rescue => e
      "Error generating diff: #{e.message}"
    end

    private

    def verify_semantics!(original, fixed)
      original_data = YAML.load(original)
      fixed_data = YAML.load(fixed)

      if original_data != fixed_data
        raise SemanticMismatchError, "Fixed YAML has different semantics than original"
      end
    end
  end
end

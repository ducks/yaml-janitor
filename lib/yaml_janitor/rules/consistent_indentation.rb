# frozen_string_literal: true

module YamlJanitor
  module Rules
    class ConsistentIndentation < Rule
      def rule_name
        "consistent_indentation"
      end

      # This rule checks the original YAML source for inconsistent indentation
      # The fix is automatic via Psych::Pure.dump with configured indentation
      def check(loaded, file: nil)
        return [] unless file

        # Read the original source
        source = File.read(file)

        violations = []
        indentation_levels = detect_indentation_levels(source)

        if indentation_levels.length > 1
          violations << Violation.new(
            rule: rule_name,
            message: "Inconsistent indentation detected: #{indentation_levels.sort.join(', ')} spaces used",
            file: file
          )
        end

        violations
      end

      # Fix is automatic - Psych::Pure.dump will use configured indentation
      def fix!(loaded)
        # No-op - the dumper handles this via config.dump_options
      end

      private

      def detect_indentation_levels(source)
        # Track the indentation increment between parent and child
        indents = []
        prev_indent = 0

        source.each_line do |line|
          # Skip empty lines, comments, and document markers
          next if line.strip.empty?
          next if line.strip.start_with?('#')
          next if line.strip.start_with?('---')
          next if line.strip.start_with?('...')
          next unless line.include?(':') # Only look at key lines

          # Count leading spaces
          spaces = 0
          spaces = line[/^ +/].length if line.start_with?(' ')

          # Calculate the indent increment from previous level
          if spaces > prev_indent
            indent_increment = spaces - prev_indent
            indents << indent_increment
          end

          prev_indent = spaces if line.strip.end_with?(':')
        end

        # Find unique indentation increments
        indents.uniq
      end
    end
  end
end

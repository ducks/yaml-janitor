# frozen_string_literal: true

module YamlJanitor
  module Rules
    class TrailingWhitespace < Rule
      def rule_name
        "trailing_whitespace"
      end

      def check_node(node, path)
        return unless string_like?(node)
        return unless has_trailing_whitespace?(node)

        key = path.last
        "Key '#{key}' contains trailing whitespace"
      end

      def fix_node(node, path)
        return unless string_like?(node)
        return unless has_trailing_whitespace?(node)

        # For LoadedObject (psych-pure's wrapper), modify the underlying string
        if node.respond_to?(:__getobj__)
          underlying = node.__getobj__
          underlying.gsub!(/[ \t]+$/, '')
          # Mark as dirty if it's a LoadedObject
          node.instance_variable_set(:@dirty, true) if node.respond_to?(:instance_variable_set)
        else
          # Direct string modification
          node.gsub!(/[ \t]+$/, '')
        end
      end

      private

      def string_like?(node)
        node.is_a?(String) || (node.respond_to?(:__getobj__) && node.__getobj__.is_a?(String))
      end

      def has_trailing_whitespace?(string)
        string.match?(/[ \t]+$/)
      end
    end
  end
end

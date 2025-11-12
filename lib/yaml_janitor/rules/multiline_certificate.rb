# frozen_string_literal: true

module YamlJanitor
  module Rules
    class MultilineCertificate < Rule
      CERT_PATTERNS = [
        /BEGIN CERTIFICATE/,
        /BEGIN RSA PRIVATE KEY/,
        /BEGIN PRIVATE KEY/,
        /BEGIN PUBLIC KEY/
      ].freeze

      def rule_name
        "multiline_certificate"
      end

      def check_node(node, path)
        return unless node.is_a?(String)
        return unless contains_certificate?(node)
        return unless has_embedded_newlines?(node)

        key = path.last
        "Key '#{key}' contains a multi-line certificate in double-quoted format (causes psych-pure bug)"
      end

      def fix_node(node, path)
        return unless node.is_a?(String)
        return unless contains_certificate?(node)
        return unless has_embedded_newlines?(node)

        # For LoadedObject (psych-pure's wrapper), we need to modify the underlying string
        if node.respond_to?(:__getobj__)
          underlying = node.__getobj__
          # Mark as dirty if it's a LoadedObject
          node.instance_variable_set(:@dirty, true) if node.respond_to?(:instance_variable_set)
        else
          underlying = node
        end

        # Can't actually fix this yet - psych-pure doesn't support setting style hints on strings
        # This would need psych-pure to support something like:
        # node.psych_style = :literal
        #
        # For now, just detect the issue
      end

      private

      def contains_certificate?(string)
        CERT_PATTERNS.any? { |pattern| string.match?(pattern) }
      end

      def has_embedded_newlines?(string)
        string.include?("\n")
      end
    end
  end
end

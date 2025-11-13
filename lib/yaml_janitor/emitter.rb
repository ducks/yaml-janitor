# frozen_string_literal: true

module YamlJanitor
  # Emitter takes a loaded YAML document (with comments) and formats it
  # according to configuration rules. Unlike Psych::Pure.dump, we have
  # complete control over formatting choices.
  class Emitter
    def initialize(node, config)
      @node = node
      @config = config
      @output = []
    end

    def emit
      # Emit any leading comments on the root document
      emit_comments(get_comments(@node, :leading), 0)

      emit_document(@node)
      @output.join("\n") + "\n"
    end

    private

    def emit_document(node, indent: 0)
      case node
      when Psych::Pure::LoadedHash
        emit_mapping(node, indent)
      when Hash
        emit_mapping(node, indent)
      when Psych::Pure::LoadedObject
        # Check if it wraps an array
        inner = node.__getobj__
        if inner.is_a?(Array)
          emit_sequence(inner, indent, loaded_object: node)
        else
          emit_node(inner, indent)
        end
      when Array
        emit_sequence(node, indent)
      else
        emit_scalar(node, indent)
      end
    end

    def emit_mapping(hash, indent)
      # Use psych_keys if available (LoadedHash), otherwise fall back to regular iteration
      entries = if hash.respond_to?(:psych_keys)
        hash.psych_keys.map { |pk| [pk.key_node, pk.value_node] }
      else
        hash.to_a
      end

      entries.each_with_index do |(key, value), index|
        # Add blank line between top-level keys if configured
        actual_value = value.is_a?(Psych::Pure::LoadedObject) ? value.__getobj__ : value
        @output << "" if index > 0 && indent == 0 && should_add_blank_line?(actual_value)

        # Emit any leading comments
        emit_comments(get_comments(key, :leading), indent)

        # Emit the key-value pair
        key_str = scalar_to_string(key.is_a?(Psych::Pure::LoadedObject) ? key.__getobj__ : key)

        # Unwrap LoadedObject to check the actual type
        actual_value = value.is_a?(Psych::Pure::LoadedObject) ? value.__getobj__ : value

        case actual_value
        when Hash, Psych::Pure::LoadedHash, Array
          # Complex value - put on next line
          line = "#{' ' * indent}#{key_str}:"

          # Check for inline comment on the value
          if (trailing = get_comments(value, :trailing))
            inline = trailing.find { |c| c.inline? }
            if inline
              line += "  #{inline.value}"
              trailing = trailing.reject { |c| c.inline? }
            end
          end

          @output << line
          emit_node(value, indent + indentation)

          # Emit any non-inline trailing comments
          emit_comments(trailing, indent) if trailing&.any?
        else
          # Simple value - same line
          value_str = scalar_to_string(actual_value)
          line = "#{' ' * indent}#{key_str}: #{value_str}"

          # Check for inline comment on the value
          if (trailing = get_comments(value, :trailing))
            inline = trailing.find { |c| c.inline? }
            line += "  #{inline.value}" if inline
          end

          @output << line
        end

        # Emit any trailing comments on the key itself
        emit_comments(get_comments(key, :trailing), indent)
      end
    end

    def emit_sequence(array, indent, loaded_object: nil)
      array.each_with_index do |item, index|
        # Emit any leading comments (check both the item and the LoadedObject wrapper)
        comments = get_comments(item, :leading) || (loaded_object ? get_comments(loaded_object, :leading) : nil)
        emit_comments(comments, indent)

        case item
        when Hash, Psych::Pure::LoadedHash
          # Complex item - put on next lines
          @output << "#{' ' * indent}-"
          emit_node(item, indent + indentation)
        when Array
          # Nested array
          @output << "#{' ' * indent}-"
          emit_node(item, indent + indentation)
        else
          # Simple item - same line
          item_str = scalar_to_string(item)
          @output << "#{' ' * indent}- #{item_str}"
        end

        # Emit any trailing comments
        emit_comments(get_comments(item, :trailing), indent)
      end
    end

    def emit_node(node, indent)
      case node
      when Psych::Pure::LoadedHash, Hash
        emit_mapping(node, indent)
      when Psych::Pure::LoadedObject
        emit_node(node.__getobj__, indent)
      when Array
        emit_sequence(node, indent)
      else
        @output << "#{' ' * indent}#{scalar_to_string(node)}"
      end
    end

    def emit_scalar(value, indent)
      @output << "#{' ' * indent}#{scalar_to_string(value)}"
    end

    def scalar_to_string(value)
      case value
      when String
        format_string(value)
      when Symbol
        ":#{value}"
      when NilClass
        "null"
      when TrueClass, FalseClass
        value.to_s
      when Numeric
        value.to_s
      else
        value.to_s
      end
    end

    def format_string(str)
      # Choose appropriate string style
      if str.include?("\n")
        # Multi-line string - use literal block scalar
        format_literal_string(str)
      elsif needs_quoting?(str)
        # Quote if necessary
        if str.include?('"') && !str.include?("'")
          "'#{str.gsub("'", "''")}'"
        else
          "\"#{str.gsub('"', '\\"')}\""
        end
      else
        str
      end
    end

    def format_literal_string(str)
      # For now, just quote it - we can enhance this later
      "\"#{str.gsub('"', '\\"').gsub("\n", '\\n')}\""
    end

    def needs_quoting?(str)
      # Basic rules - quote if:
      # - Starts/ends with whitespace
      # - Contains : or # or special chars
      # - Looks like a boolean/null/number
      return true if str.match?(/\A\s|\s\z/)
      return true if str.match?(/[:#\[\]{}]/)
      return true if str.match?(/\A(true|false|null|~|yes|no|on|off)\z/i)
      return true if str.match?(/\A[-+]?[0-9]/)
      false
    end

    def emit_comments(comments, indent)
      return unless comments&.any?

      comments.each do |comment|
        @output << "#{' ' * indent}#{comment.value}"
      end
    end

    def get_comments(node, type)
      return nil unless node.respond_to?(:psych_node)
      return nil unless node.psych_node.respond_to?(:comments?)
      return nil unless node.psych_node.comments?

      case type
      when :leading
        node.psych_node.comments.leading
      when :trailing
        node.psych_node.comments.trailing
      end
    end

    def should_add_blank_line?(value)
      # Add blank line before complex structures
      value.is_a?(Hash) || value.is_a?(Array)
    end

    def indentation
      @config.indentation
    end
  end
end

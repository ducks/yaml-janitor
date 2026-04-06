# frozen_string_literal: true

module YamlJanitor
  # Emitter takes a loaded YAML document (with comments) and formats it
  # according to configuration rules. Unlike Psych::Pure.dump, we have
  # complete control over formatting choices.
  class Emitter
    def initialize(node, config, ast: nil)
      @node = node
      @config = config
      @output = []
      @ast = ast
      @ast_root = extract_ast_root(ast)
    end

    def emit
      # Emit any leading comments on the root document
      emit_comments(get_comments(@node, :leading), 0)

      emit_document(@node, ast_node: @ast_root)
      @output.join("\n") + "\n"
    end

    private

    def emit_document(node, indent: 0, ast_node: nil)
      case node
      when Psych::Pure::LoadedHash
        emit_mapping(node, indent, ast_node: ast_node)
      when Hash
        emit_mapping(node, indent, ast_node: ast_node)
      when Psych::Pure::LoadedObject
        # Check if it wraps an array
        inner = node.__getobj__
        if inner.is_a?(Array)
          emit_sequence(inner, indent, loaded_object: node, ast_node: ast_node)
        else
          emit_node(inner, indent, ast_node: ast_node)
        end
      when Array
        emit_sequence(node, indent, ast_node: ast_node)
      else
        emit_scalar(node, indent)
      end
    end

    def emit_mapping(hash, indent, ast_node: nil)
      ast_pairs = ast_mapping_pairs(ast_node)

      # If the AST has anchors or aliases, use AST-driven emission
      # because the loaded hash may have already expanded the aliases
      has_anchors_or_aliases = ast_pairs.any? do |_, v|
        v.is_a?(Psych::Nodes::Alias) ||
          (v.respond_to?(:anchor) && v.anchor) ||
          (v.is_a?(Psych::Nodes::Mapping) && v.children.each_slice(2).any? { |_, cv| cv.is_a?(Psych::Nodes::Alias) })
      end
      if has_anchors_or_aliases
        emit_mapping_from_ast(ast_pairs, indent)
        return
      end

      # Use psych_keys if available (LoadedHash), otherwise fall back to regular iteration
      entries = if hash.respond_to?(:psych_keys)
        hash.psych_keys.map { |pk| [pk.key_node, pk.value_node] }
      else
        hash.to_a
      end

      entries.each_with_index do |(key, value), index|
        _ast_key, ast_value = ast_pairs[index] || [nil, nil]

        # Add blank line between top-level keys if configured
        actual_value = value.is_a?(Psych::Pure::LoadedObject) ? value.__getobj__ : value
        @output << "" if index > 0 && indent == 0 && should_add_blank_line?(actual_value)

        # Emit any leading comments
        emit_comments(get_comments(key, :leading), indent)

        # Emit the key-value pair
        key_str = scalar_to_string(key.is_a?(Psych::Pure::LoadedObject) ? key.__getobj__ : key)

        # Check if this value is an alias in the AST
        if ast_value&.is_a?(Psych::Nodes::Alias)
          @output << "#{' ' * indent}#{key_str}: *#{ast_value.anchor}"
          emit_comments(get_comments(key, :trailing), indent)
          next
        end

        # Check if the value has an anchor
        anchor_suffix = ""
        if ast_value&.respond_to?(:anchor) && ast_value.anchor
          anchor_suffix = " &#{ast_value.anchor}"
        end

        # Unwrap LoadedObject to check the actual type
        actual_value = value.is_a?(Psych::Pure::LoadedObject) ? value.__getobj__ : value

        case actual_value
        when Hash, Psych::Pure::LoadedHash, Array
          # Complex value - put on next line
          line = "#{' ' * indent}#{key_str}:#{anchor_suffix}"

          # Check for inline comment on the value
          if (trailing = get_comments(value, :trailing))
            inline = trailing.find { |c| c.inline? }
            if inline
              line += "  #{inline.value}"
              trailing = trailing.reject { |c| c.inline? }
            end
          end

          @output << line
          emit_node(value, indent + indentation, ast_node: ast_value)

          # Emit any non-inline trailing comments
          emit_comments(trailing, indent) if trailing&.any?
        else
          # Simple value - same line
          value_str = scalar_to_string(actual_value)
          line = "#{' ' * indent}#{key_str}:#{anchor_suffix} #{value_str}"

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

    def emit_sequence(array, indent, loaded_object: nil, ast_node: nil)
      array.each_with_index do |item, index|
        # Emit any leading comments (check both the item and the LoadedObject wrapper)
        comments = get_comments(item, :leading) || (loaded_object ? get_comments(loaded_object, :leading) : nil)
        emit_comments(comments, indent)

        case item
        when Hash, Psych::Pure::LoadedHash
          # Complex item - use compact style (dash on same line as first key)
          emit_compact_hash_item(item, indent)
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

    def emit_compact_hash_item(hash, indent)
      # Emit hash as array item in compact style:
      # - key1: value1
      #   key2: value2

      # Use psych_keys if available (LoadedHash), otherwise fall back to regular iteration
      entries = if hash.respond_to?(:psych_keys)
        hash.psych_keys.map { |pk| [pk.key_node, pk.value_node] }
      else
        hash.to_a
      end

      entries.each_with_index do |(key, value), index|
        # Emit any leading comments
        emit_comments(get_comments(key, :leading), indent + (index > 0 ? indentation : 0))

        # Get the actual key and value (unwrap LoadedObject)
        key_str = scalar_to_string(key.is_a?(Psych::Pure::LoadedObject) ? key.__getobj__ : key)
        actual_value = value.is_a?(Psych::Pure::LoadedObject) ? value.__getobj__ : value

        # First item gets the dash, rest are indented
        prefix = index == 0 ? "#{' ' * indent}- " : "#{' ' * (indent + indentation)}"

        case actual_value
        when Hash, Psych::Pure::LoadedHash, Array
          # Complex value - put on next line
          line = "#{prefix}#{key_str}:"

          # Check for inline comment on the value
          if (trailing = get_comments(value, :trailing))
            inline = trailing.find { |c| c.inline? }
            if inline
              line += "  #{inline.value}"
              trailing = trailing.reject { |c| c.inline? }
            end
          end

          @output << line
          emit_node(value, indent + indentation * 2)

          # Emit any non-inline trailing comments
          emit_comments(trailing, indent + indentation) if trailing&.any?
        else
          # Simple value - same line
          value_str = scalar_to_string(actual_value)
          line = "#{prefix}#{key_str}: #{value_str}"

          # Check for inline comment on the value
          if (trailing = get_comments(value, :trailing))
            inline = trailing.find { |c| c.inline? }
            line += "  #{inline.value}" if inline
          end

          @output << line
        end

        # Emit any trailing comments on the key itself
        emit_comments(get_comments(key, :trailing), indent + (index > 0 ? indentation : 0))
      end
    end

    def emit_node(node, indent, ast_node: nil)
      case node
      when Psych::Pure::LoadedHash, Hash
        emit_mapping(node, indent, ast_node: ast_node)
      when Psych::Pure::LoadedObject
        emit_node(node.__getobj__, indent, ast_node: ast_node)
      when Array
        emit_sequence(node, indent, ast_node: ast_node)
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

    # Emit a mapping by walking the AST directly.
    # Used when the mapping contains aliases that got expanded in the loaded data.
    def emit_mapping_from_ast(ast_pairs, indent)
      ast_pairs.each_with_index do |(ast_key, ast_value), index|
        key_str = ast_key.value rescue ast_key.to_s

        if ast_value.is_a?(Psych::Nodes::Alias)
          # Emit alias reference
          @output << "#{' ' * indent}#{key_str}: *#{ast_value.anchor}"
        elsif ast_value.is_a?(Psych::Nodes::Mapping)
          anchor_suffix = ast_value.anchor ? " &#{ast_value.anchor}" : ""
          @output << "#{' ' * indent}#{key_str}:#{anchor_suffix}"
          # Recurse into the mapping's AST children
          child_pairs = ast_value.children.each_slice(2).to_a
          if child_pairs.any? { |_, v| v.is_a?(Psych::Nodes::Alias) }
            emit_mapping_from_ast(child_pairs, indent + indentation)
          else
            child_pairs.each do |ck, cv|
              ck_str = ck.value rescue ck.to_s
              if cv.is_a?(Psych::Nodes::Scalar)
                @output << "#{' ' * (indent + indentation)}#{ck_str}: #{format_ast_scalar(cv)}"
              elsif cv.is_a?(Psych::Nodes::Alias)
                @output << "#{' ' * (indent + indentation)}#{ck_str}: *#{cv.anchor}"
              elsif cv.is_a?(Psych::Nodes::Mapping)
                anchor_suffix = cv.anchor ? " &#{cv.anchor}" : ""
                @output << "#{' ' * (indent + indentation)}#{ck_str}:#{anchor_suffix}"
                emit_mapping_from_ast(cv.children.each_slice(2).to_a, indent + indentation * 2)
              elsif cv.is_a?(Psych::Nodes::Sequence)
                anchor_suffix = cv.anchor ? " &#{cv.anchor}" : ""
                @output << "#{' ' * (indent + indentation)}#{ck_str}:#{anchor_suffix}"
                emit_sequence_from_ast(cv.children, indent + indentation * 2)
              end
            end
          end
        elsif ast_value.is_a?(Psych::Nodes::Scalar)
          anchor_suffix = ast_value.anchor ? " &#{ast_value.anchor}" : ""
          @output << "#{' ' * indent}#{key_str}:#{anchor_suffix} #{format_ast_scalar(ast_value)}"
        elsif ast_value.is_a?(Psych::Nodes::Sequence)
          anchor_suffix = ast_value.anchor ? " &#{ast_value.anchor}" : ""
          @output << "#{' ' * indent}#{key_str}:#{anchor_suffix}"
          emit_sequence_from_ast(ast_value.children, indent + indentation)
        end
      end
    end

    # Emit a sequence from AST nodes
    def emit_sequence_from_ast(children, indent)
      children.each do |child|
        if child.is_a?(Psych::Nodes::Scalar)
          @output << "#{' ' * indent}- #{format_ast_scalar(child)}"
        elsif child.is_a?(Psych::Nodes::Alias)
          @output << "#{' ' * indent}- *#{child.anchor}"
        elsif child.is_a?(Psych::Nodes::Mapping)
          pairs = child.children.each_slice(2).to_a
          pairs.each_with_index do |(k, v), i|
            prefix = i == 0 ? "#{' ' * indent}- " : "#{' ' * (indent + indentation)}"
            k_str = k.value rescue k.to_s
            if v.is_a?(Psych::Nodes::Scalar)
              @output << "#{prefix}#{k_str}: #{format_ast_scalar(v)}"
            elsif v.is_a?(Psych::Nodes::Alias)
              @output << "#{prefix}#{k_str}: *#{v.anchor}"
            end
          end
        end
      end
    end

    # Format an AST scalar value, preserving its original type.
    # The AST node knows its tag (int, bool, null, etc.) so we
    # can emit without spurious quoting.
    def format_ast_scalar(node)
      return "null" if node.tag == "tag:yaml.org,2002:null" || node.value.nil?

      case node.tag
      when "tag:yaml.org,2002:int", "tag:yaml.org,2002:float"
        node.value
      when "tag:yaml.org,2002:bool"
        node.value
      else
        # For plain scalars, use the raw value if it was unquoted in the original
        if node.plain
          node.value
        else
          scalar_to_string(node.value)
        end
      end
    end

    def indentation
      @config.indentation
    end

    # Extract the root mapping node from a parsed AST
    def extract_ast_root(ast)
      return nil unless ast
      return nil unless ast.respond_to?(:children)

      case ast
      when Psych::Nodes::Document
        # Document -> Mapping
        ast.children&.each do |child|
          return child if child.is_a?(Psych::Nodes::Mapping)
        end
      when Psych::Nodes::Stream
        # Stream -> Document -> Mapping
        ast.children&.each do |doc|
          next unless doc.is_a?(Psych::Nodes::Document)
          doc.children&.each do |child|
            return child if child.is_a?(Psych::Nodes::Mapping)
          end
        end
      end
      nil
    end

    # Get key/value AST node pairs from a mapping node
    def ast_mapping_pairs(ast_node)
      return [] unless ast_node.is_a?(Psych::Nodes::Mapping)
      ast_node.children.each_slice(2).to_a
    end
  end
end

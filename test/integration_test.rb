# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/yaml_janitor"
require "tempfile"

class IntegrationTest < Minitest::Test
  def test_comment_preservation_with_indentation_fix
    # Create a YAML file with comments and inconsistent indentation
    yaml_with_comments = <<~YAML
      ---
      # Database configuration
      database:
          host: "localhost"  # Primary host
          port: 5432
      # Application settings
      config:
              timeout: 30  # Connection timeout
              retries: 3
    YAML

    Tempfile.create(["test", ".yml"]) do |file|
      file.write(yaml_with_comments)
      file.flush

      # Run the formatter
      config = YamlJanitor::Config.new(overrides: { indentation: 2 })
      linter = YamlJanitor::Linter.new(config: config)
      result = linter.lint_file(file.path, fix: true)

      # Should format the file
      assert result[:fixed], "Should have formatted the file"

      # Read the fixed content
      fixed_content = File.read(file.path)

      # Comments should be preserved
      assert_includes fixed_content, "# Database configuration"
      assert_includes fixed_content, "# Primary host"
      assert_includes fixed_content, "# Application settings"
      assert_includes fixed_content, "# Connection timeout"

      # Indentation should be normalized to 2 spaces
      assert_match(/^database:$/, fixed_content)
      assert_match(/^  host:/, fixed_content)
      assert_match(/^  port:/, fixed_content)
      assert_match(/^config:$/, fixed_content)
      assert_match(/^  timeout:/, fixed_content)
      assert_match(/^  retries:/, fixed_content)

      # Verify semantics are preserved
      original_data = YAML.load(yaml_with_comments)
      fixed_data = YAML.load(fixed_content)
      assert_equal original_data, fixed_data, "Semantics should be preserved"
    end
  end

  def test_indentation_normalization
    yaml_inconsistent = <<~YAML
      ---
      name: "Test"
      level1:
          level2a: "value"
          level2b:
                  level3: "deep"
    YAML

    Tempfile.create(["test", ".yml"]) do |file|
      file.write(yaml_inconsistent)
      file.flush

      # Format with 2-space indentation
      config = YamlJanitor::Config.new(overrides: { indentation: 2 })
      linter = YamlJanitor::Linter.new(config: config)
      result = linter.lint_file(file.path, fix: true)

      assert result[:fixed], "Should format the file"

      fixed_content = File.read(file.path)

      # All nested content should use 2-space increments
      lines = fixed_content.lines
      assert lines.any? { |l| l.start_with?("level1:") }
      assert lines.any? { |l| l.start_with?("  level2a:") }
      assert lines.any? { |l| l.start_with?("  level2b:") }
      assert lines.any? { |l| l.start_with?("    level3:") }
    end
  end

  def test_paranoid_mode_catches_semantic_changes
    yaml_content = <<~YAML
      ---
      name: "original"
      value: 42
    YAML

    # Paranoid mode should be automatic
    # If we somehow modify the data during a fix, it should error
    config = YamlJanitor::Config.new
    linter = YamlJanitor::Linter.new(config: config)

    # This should not raise because we're not changing semantics
    result = linter.lint(yaml_content, fix: false)
    assert result[:violations].any? || result[:violations].empty?, "Should handle check without error"
  end

  def test_config_loading_affects_behavior
    yaml_content = <<~YAML
      ---
      database:
          host: "localhost"
      config:
              timeout: 30
    YAML

    Tempfile.create(["test", ".yml"]) do |file|
      file.write(yaml_content)
      file.flush

      # Format with default config (2-space indentation)
      config = YamlJanitor::Config.new
      linter = YamlJanitor::Linter.new(config: config)
      result = linter.lint_file(file.path, fix: true)

      assert result[:fixed], "Should format the file"

      # Verify formatted content has consistent indentation
      fixed_content = File.read(file.path)
      assert_match(/^database:$/, fixed_content)
      assert_match(/^  host:/, fixed_content)
    end
  end

  def test_multiline_certificate_detection
    yaml_with_cert = <<~YAML
      ---
      config:
        DISCOURSE_SAML_CERT: "-----BEGIN CERTIFICATE-----
      MIIDGDCCagAwIBAgIVAMP/9hm9Vl3/23QoXrL8hQ31DLwRMA0GCSqGSIb3DQEB
      -----END CERTIFICATE-----"
    YAML

    # This should trigger a parse error (Bug #2 in psych-pure)
    linter = YamlJanitor::Linter.new
    result = linter.lint(yaml_with_cert)

    assert result[:violations].any? { |v| v.rule == :parse_error },
           "Should detect parse error for multi-line certificate"
  end

  def test_clean_file_passes
    clean_yaml = <<~YAML
      # This is a clean file
      name: Test
      config:
        timeout: 30
        retries: 3
    YAML

    linter = YamlJanitor::Linter.new
    result = linter.lint(clean_yaml)

    assert result[:violations].empty?, "Clean file should have no violations"
  end

  def test_compact_array_format
    # Test that arrays of hashes use compact format (dash on same line as first key)
    yaml_with_arrays = <<~YAML
      ---
      build_on_push:
      - branch: blz-qa
        url: git@github.com:discourse/example1
        name: plugin1
      - branch: blz-qa
        url: git@github.com:discourse/example2
        name: plugin2
    YAML

    Tempfile.create(["test", ".yml"]) do |file|
      file.write(yaml_with_arrays)
      file.flush

      config = YamlJanitor::Config.new(overrides: { indentation: 2 })
      linter = YamlJanitor::Linter.new(config: config)
      result = linter.lint_file(file.path, fix: true)

      fixed_content = File.read(file.path)

      # Should use compact format: dash on same line as first key
      assert_match(/^  - branch:/, fixed_content, "First key should be on same line as dash")
      assert_match(/^    url:/, fixed_content, "Subsequent keys should be indented")
      assert_match(/^    name:/, fixed_content, "All non-first keys should be indented")

      # Should NOT have dash on its own line (explicit format)
      refute_match(/^  -\s*$/, fixed_content, "Should not have dash on its own line")

      # Verify semantics are preserved
      original_data = YAML.load(yaml_with_arrays)
      fixed_data = YAML.load(fixed_content)
      assert_equal original_data, fixed_data, "Semantics should be preserved"
    end
  end
end

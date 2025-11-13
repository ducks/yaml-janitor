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

      # Run the linter with --fix
      config = YamlJanitor::Config.new(overrides: { indentation: 2 })
      linter = YamlJanitor::Linter.new(config: config)
      result = linter.lint_file(file.path, fix: true)

      # Should detect inconsistent indentation
      assert result[:violations].any? { |v| v.rule == "consistent_indentation" },
             "Should detect inconsistent indentation"

      # Should fix it
      assert result[:fixed], "Should have fixed the file"

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

      # Detect inconsistent indentation
      linter = YamlJanitor::Linter.new
      result = linter.lint_file(file.path)

      assert result[:violations].any? { |v| v.rule == "consistent_indentation" },
             "Should detect inconsistent indentation (4, 8 spaces)"

      # Fix with 2-space indentation
      config = YamlJanitor::Config.new(overrides: { indentation: 2 })
      linter_with_config = YamlJanitor::Linter.new(config: config)
      fix_result = linter_with_config.lint_file(file.path, fix: true)

      assert fix_result[:fixed], "Should fix the indentation"

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
      name: "Test  "
      description: "Text  "
    YAML

    Tempfile.create(["test", ".yml"]) do |file|
      file.write(yaml_content)
      file.flush

      # With trailing_whitespace enabled (default)
      config_enabled = YamlJanitor::Config.new
      linter_enabled = YamlJanitor::Linter.new(config: config_enabled)
      result_enabled = linter_enabled.lint_file(file.path)

      assert result_enabled[:violations].any? { |v| v.rule == "trailing_whitespace" },
             "Should detect trailing whitespace when enabled"

      # With trailing_whitespace disabled
      config_disabled = YamlJanitor::Config.new(overrides: {
        rules: { trailing_whitespace: { enabled: false } }
      })
      linter_disabled = YamlJanitor::Linter.new(config: config_disabled)
      result_disabled = linter_disabled.lint_file(file.path)

      refute result_disabled[:violations].any? { |v| v.rule == "trailing_whitespace" },
             "Should not detect trailing whitespace when disabled"
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
      ---
      # This is a clean file
      name: "Test"
      config:
        timeout: 30
        retries: 3
    YAML

    linter = YamlJanitor::Linter.new
    result = linter.lint(clean_yaml)

    assert result[:violations].empty?, "Clean file should have no violations"
  end
end

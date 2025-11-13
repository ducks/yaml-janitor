# yaml-janitor

A YAML linter built on psych-pure that preserves comments while detecting and
fixing issues.

## Why?

Traditional YAML tools destroy comments when editing files. yaml-janitor uses
psych-pure's comment-preserving parser to lint and fix YAML files without
losing valuable documentation.

## Installation

```bash
gem install yaml-janitor
```

Or in your Gemfile:

```ruby
gem 'yaml-janitor'
```

## Usage

### CLI

Check a single file:
```bash
yaml-janitor config.yml
```

Check all YAML files in a directory:
```bash
yaml-janitor containers/
```

Auto-fix issues:
```bash
yaml-janitor --fix config.yml
```

Run specific rules:
```bash
yaml-janitor --rules multiline_certificate config.yml
```

### Ruby API

```ruby
require 'yaml_janitor'

# Lint a file
result = YamlJanitor.lint_file("config.yml")
result[:violations].each do |violation|
  puts violation
end

# Lint and fix
result = YamlJanitor.lint_file("config.yml", fix: true)
if result[:fixed]
  puts "Fixed! New content:\n#{result[:output]}"
end

# Lint a string
yaml_string = File.read("config.yml")
result = YamlJanitor.lint(yaml_string)
```

## Configuration

Create a `.yaml-janitor.yml` file in your project root:

```yaml
# Formatting options (applied during --fix)
indentation: 2
line_width: 80
sequence_indent: false

# Rule configuration
rules:
  multiline_certificate:
    enabled: true
  trailing_whitespace:
    enabled: true
```

### Configuration Options

**Formatting**:
- `indentation`: Number of spaces for indentation (default: 2)
- `line_width`: Maximum line width before wrapping (default: 80)
- `sequence_indent`: Indent sequences under their key (default: false)

**Rules**:
- `multiline_certificate`: Detects multi-line certificates in double-quoted strings
- `trailing_whitespace`: Detects and removes trailing whitespace from string values

### Command Line Overrides

```bash
# Override config file settings
yaml-janitor --indentation 4 --line-width 100 config.yml

# Use a specific config file
yaml-janitor --config production.yml containers/
```

## Rules

### multiline_certificate

Detects multi-line certificates embedded in double-quoted strings. This pattern
triggers a psych-pure parser bug.

```yaml
# BAD (will trigger violation)
DISCOURSE_SAML_CERT: "-----BEGIN CERTIFICATE-----
MIIDGDCCAgCgAwIBAgIVAMP/9hm9Vl3/23QoXrL8hQ31DLwRMA0GCSqGSIb3DQEB
-----END CERTIFICATE-----"

# GOOD (use block literal style)
DISCOURSE_SAML_CERT: |
  -----BEGIN CERTIFICATE-----
  MIIDGDCCAgCgAwIBAgIVAMP/9hm9Vl3/23QoXrL8hQ31DLwRMA0GCSqGSIb3DQEB
  -----END CERTIFICATE-----
```

**Auto-fix**: Not yet implemented (requires psych-pure enhancements)

### trailing_whitespace

Detects trailing whitespace in string values.

```yaml
# BAD (will trigger violation)
name: "John Doe  "
description: "Some text   "

# GOOD
name: "John Doe"
description: "Some text"
```

**Auto-fix**: Yes, strips trailing whitespace when using `--fix`

## Development

```bash
bundle install
bundle exec rake test
```

## Background

This tool was built to support YAML comment preservation in Discourse ops
automation. See the original discussion:
https://dev.discourse.org/t/should-we-lint-our-yaml-files/33593

Built on top of Kevin Newton's psych-pure gem, which provides a pure Ruby YAML
parser with comment preservation.

## License

MIT

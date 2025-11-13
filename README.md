# yaml-janitor

A YAML linter and formatter built on psych-pure that preserves comments while
formatting files.

## Why?

Traditional YAML tools destroy comments when editing files. yaml-janitor uses
psych-pure's comment-preserving parser to format YAML files without losing
valuable documentation.

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

Check a single file (reports formatting issues):
```bash
yaml-janitor config.yml
```

Check all YAML files in a directory:
```bash
yaml-janitor containers/
```

Format files in-place:
```bash
yaml-janitor --fix config.yml
```

Format with custom indentation:
```bash
yaml-janitor --fix --indentation 4 config.yml
```

### Ruby API

```ruby
require 'yaml_janitor'

# Check a file for formatting issues
result = YamlJanitor.lint_file("config.yml")
result[:violations].each do |violation|
  puts "#{violation.file}: #{violation.message}"
end

# Format a file in-place
result = YamlJanitor.format_file("config.yml")
if result[:fixed]
  puts "Formatted!"
end

# Format a string
yaml_string = File.read("config.yml")
result = YamlJanitor.format(yaml_string)
puts result[:output]

# Use custom config
config = YamlJanitor::Config.new(overrides: { indentation: 4 })
linter = YamlJanitor::Linter.new(config: config)
result = linter.lint_file("config.yml", fix: true)
```

## Configuration

Create a `.yaml-janitor.yml` file in your project root:

```yaml
# Formatting options
indentation: 2
line_width: 80
```

### Configuration Options

- `indentation`: Number of spaces for indentation (default: 2)
- `line_width`: Maximum line width before wrapping (default: 80, not yet implemented)

### Command Line Overrides

```bash
# Override config file settings
yaml-janitor --indentation 4 --line-width 100 config.yml

# Use a specific config file
yaml-janitor --config production.yml containers/
```

## How It Works

yaml-janitor uses a two-phase approach:

1. **Parse**: Load YAML with psych-pure, preserving comment metadata
2. **Format**: Emit YAML using custom formatter with full control over style

When you run `yaml-janitor --fix`, it:
- Loads your YAML file with comments preserved
- Formats it according to configuration (indentation, line width, etc.)
- Verifies semantics are unchanged (paranoid mode)
- Writes the formatted output back to the file

### Formatting Rules

The formatter enforces:
- **Consistent indentation** (default: 2 spaces)
- **Block style for arrays and mappings** (never flow style like `[a, b, c]`)
- **Normalized string quoting** (only quotes when necessary)
- **Proper line breaks** between top-level keys

### Comment Preservation

Comments are preserved in most locations:
- Leading comments (before keys)
- Trailing comments (after values)
- Mid-document comments (between keys)

Known limitation: Inline comments on mapping keys (e.g., `servers: # comment`)
may be repositioned as leading comments on the next key due to psych-pure's
comment tracking.

### Safety

All formatting changes are verified with paranoid mode: the original YAML and
formatted YAML are both parsed and compared for semantic equality. If they
differ, the tool errors out instead of writing the file.

## Development

### Running Tests

```bash
# Run integration tests
ruby -I lib test/integration_test.rb

# Or with rake (if configured)
bundle install
bundle exec rake test
```

### Test Coverage

Integration tests verify:
- Comment preservation during formatting
- Indentation normalization
- Paranoid mode (semantic verification)
- Config loading and overrides
- Parse error detection
- Idempotent formatting (clean files pass without violations)

## Background

This tool was built to support YAML comment preservation in Discourse ops
automation. See the original discussion:
https://dev.discourse.org/t/should-we-lint-our-yaml-files/33593

Built on top of Kevin Newton's psych-pure gem, which provides a pure Ruby YAML
parser with comment preservation.

## License

MIT

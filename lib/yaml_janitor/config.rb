# frozen_string_literal: true

require 'yaml'

module YamlJanitor
  class Config
    DEFAULT_CONFIG = {
      indentation: 2,
      line_width: 80,
      sequence_indent: false,
      rules: {
        multiline_certificate: { enabled: true },
        consistent_indentation: { enabled: true }
      }
    }.freeze

    attr_reader :config

    def initialize(config_path: nil, overrides: {})
      @config = deep_dup(DEFAULT_CONFIG)
      load_config_file(config_path) if config_path
      merge_overrides(overrides)
    end

    def indentation
      @config[:indentation]
    end

    def line_width
      @config[:line_width]
    end

    def sequence_indent
      @config[:sequence_indent]
    end

    def rule_enabled?(rule_name)
      rule_config = @config[:rules][rule_name.to_sym]
      rule_config && rule_config[:enabled] != false
    end

    def rule_config(rule_name)
      @config[:rules][rule_name.to_sym] || {}
    end

    def dump_options
      {
        indentation: indentation,
        line_width: line_width,
        sequence_indent: sequence_indent
      }
    end

    private

    def load_config_file(path)
      return unless File.exist?(path)

      file_config = YAML.safe_load(File.read(path), symbolize_names: true)
      deep_merge!(@config, file_config)
    rescue => e
      warn "Warning: Could not load config file #{path}: #{e.message}"
    end

    def merge_overrides(overrides)
      deep_merge!(@config, overrides)
    end

    def deep_dup(hash)
      hash.each_with_object({}) do |(key, value), result|
        result[key] = value.is_a?(Hash) ? deep_dup(value) : value
      end
    end

    def deep_merge!(hash, other_hash)
      other_hash.each do |key, value|
        if value.is_a?(Hash) && hash[key].is_a?(Hash)
          deep_merge!(hash[key], value)
        else
          hash[key] = value
        end
      end
      hash
    end
  end
end

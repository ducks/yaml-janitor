# frozen_string_literal: true

module YamlJanitor
  class Violation
    attr_reader :rule, :message, :line, :column, :file

    def initialize(rule:, message:, line: nil, column: nil, file: nil)
      @rule = rule
      @message = message
      @line = line
      @column = column
      @file = file
    end

    def to_s
      location = []
      location << file if file
      location << "line #{line}" if line
      location << "column #{column}" if column

      prefix = location.empty? ? "" : "#{location.join(":")} - "
      "#{prefix}[#{rule}] #{message}"
    end
  end
end

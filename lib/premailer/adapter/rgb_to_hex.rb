# frozen_string_literal: true
# RGB helper for adapters, currently only nokogiri supported

module AdapterHelper
  module RgbToHex
    def to_hex(str)
      str.to_i.to_s(16).rjust(2, '0').upcase
    end

    def rgb?(color)
      pattern = %r{
      rgb
      \(\s*                    # literal open, with optional whitespace
      (\d{1,3})                # capture 1-3 digits
      (?:\s*,\s*|\s+)          # comma or whitespace
      (\d{1,3})                # capture 1-3 digits
      (?:\s*,\s*|\s+)          # comma or whitespacee
      (\d{1,3})                # capture 1-3 digits
      \s*(?:/\s*\d*\.?\d*%?)? # optional alpha modifier
      \s*\)                    # literal close, with optional whitespace
      }x

      pattern.match(color)
    end

    def ensure_hex(color)
      match_data = rgb?(color)
      if match_data
        "#{to_hex(match_data[1])}#{to_hex(match_data[2])}#{to_hex(match_data[3])}"
      else
        color
      end
    end
  end
end

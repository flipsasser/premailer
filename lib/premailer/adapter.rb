# frozen_string_literal: true
class Premailer
  # Manages the adapter classes. Currently supports:
  #
  # * nokogiri
  # * nokogiri_fast
  # * nokogumbo
  module Adapter
    autoload :Nokogiri, 'premailer/adapter/nokogiri'
    autoload :NokogiriFast, 'premailer/adapter/nokogiri_fast'
    autoload :Nokogumbo, 'premailer/adapter/nokogumbo'

    # adapter to required file mapping.
    REQUIREMENT_MAP = [
      ["nokogiri", :nokogiri],
      ["nokogiri", :nokogiri_fast],
      ["nokogumbo", :nokogumbo]
    ].freeze

    # Returns the adapter to use.
    def self.use
      return @use if @use
      self.use = default
      @use
    end

    # The default adapter based on what you currently have loaded and
    # installed. First checks to see if any adapters are already loaded,
    # then checks to see which are installed if none are loaded.
    # @raise [RuntimeError] unless suitable adapter found.
    def self.default
      return :nokogiri if defined?(::Nokogiri)
      return :nokogiri_fast if defined?(::NokogiriFast)
      return :nokogumbo if defined?(::Nokogumbo)

      REQUIREMENT_MAP.each do |(library, adapter)|
        require library
        return adapter
      rescue LoadError
        next
      end

      raise "No suitable adapter for Premailer was found, please install nokogiri or nokogumbo"
    end

    # Sets the adapter to use.
    # @raise [ArgumentError] unless the adapter exists.
    def self.use=(new_adapter)
      @use = find(new_adapter)
    end

    # Returns an adapter.
    # @raise [ArgumentError] unless the adapter exists.
    def self.find(adapter)
      return adapter if adapter.is_a?(Module)

      Premailer::Adapter.const_get(adapter.to_s.split('_').map(&:capitalize).join.to_s)
    rescue NameError
      raise ArgumentError, "Invalid adapter: #{adapter}"
    end
  end
end

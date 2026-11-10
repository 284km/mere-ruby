module OpenSSL
  class ConfigError < OpenSSLError; end
  class Config
    include Enumerable
    DEFAULT_CONFIG_FILE = (OpenSSL.__native_available ? Backend.call('config.default_file') : '').freeze
    def initialize(filename = nil)
      initialize_data(filename.nil? ? {} : Backend.call('config.parse', File.binread(filename)))
    end
    def self.load(filename = nil); new(filename); end
    def self.parse(source)
      allocate.send(:initialize_data, Backend.call('config.parse', ::OpenSSL::PKey.string(source)))
    end
    def self.parse_config(source)
      config = parse(source)
      config.sections.to_h { |section| [section, config[section]] }
    end
    def initialize_data(data)
      @data = data
      @data.each do |section, values|
        section.freeze
        values.each { |key, value| key.freeze; value.freeze }
        values.freeze
      end
      @data.freeze
      freeze
    end
    private :initialize_data
    def initialize_copy(other)
      @data = other.instance_variable_get(:@data)
      freeze
    end
    def [](section); (@data[::OpenSSL::PKey.string(section)] || {}).dup; end
    def sections; @data.keys; end
    def get_value(section, key)
      section = ::OpenSSL::PKey.string(section)
      key = ::OpenSSL::PKey.string(key)
      return ENV[key] if section == 'ENV'
      section = 'default' if section.empty?
      (@data[section] || {})[key] || (@data['default'] || {})[key]
    end
    def each(&block)
      return enum_for(:each) unless block
      @data.each { |section, values| values.each { |key, value| block.call([section, key, value]) } }
      self
    end
    def to_s
      @data.map { |section, values| "[ #{section} ]\n" + values.map { |key, value| "#{key}=#{value}\n" }.join + "\n" }.join
    end
    def inspect; "#<#{self.class} sections=#{sections.inspect}>"; end
  end
end

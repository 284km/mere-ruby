require 'psych'
require 'psych/class_loader' if ARGV.include?('--direct')

def check(value)
  raise 'Psych protocol mismatch' unless value
end

loader = Psych::ClassLoader.new
scanner = Psych::ScalarScanner.new(loader)
check(scanner.tokenize('null').nil?)
check(scanner.tokenize('yes') == true)
check(scanner.tokenize('off') == false)
check(scanner.tokenize('0b101') == 5)
check(scanner.tokenize('0xFF') == 255)
check(scanner.tokenize('012') == 10)
check(scanner.tokenize('1,000') == 1000)
check(scanner.tokenize('190:20:30') == 685230)
check(scanner.tokenize('1.25') == 1.25)
check(scanner.tokenize('.inf').infinite? == 1)
check(scanner.tokenize('.nan').nan?)
check(scanner.tokenize(':approved') == :approved)
check(Psych::ScalarScanner.new(loader, parse_symbols: false).tokenize(':approved') == ':approved')
check(Psych::ScalarScanner.new(loader, strict_integer: true).tokenize('1,000') == '1,000')
check(scanner.tokenize('1980-12-16') == Date.new(1980, 12, 16))
check(scanner.tokenize('2001-12-15T02:59:43.1Z') == Time.utc(2001, 12, 15, 2, 59, 43, 100000))
check(scanner.tokenize('2000-15-01') == '2000-15-01')

module PsychProtocolFixture
  class Value; end
  NUMBER = 42
  def self.const_missing(name)
    raise 'ClassLoader must not call const_missing'
  end
end
check(loader.load('PsychProtocolFixture::Value') == PsychProtocolFixture::Value)
check(loader.load('PsychProtocolFixture') == PsychProtocolFixture)
check(loader.load(nil).nil?)
check(loader.load('').nil?)
begin
  loader.load('PsychProtocolFixture::Missing')
  raise 'missing constant accepted'
rescue ArgumentError
end
begin
  loader.load('PsychProtocolFixture::NUMBER')
  raise 'non-class constant accepted'
rescue TypeError
end
Struct.new('PsychProtocolValue', :value)
check(loader.load('PsychProtocolValue') == Struct::PsychProtocolValue)
Struct.send(:remove_const, :PsychProtocolValue)
restricted = Psych::ClassLoader::Restricted.new(['Date', 'Symbol'], ['approved'])
check(restricted.load('Date') == Date)
check(restricted.symbolize('approved') == :approved)
begin
  restricted.load('Time')
  raise 'unpermitted class accepted'
rescue Psych::DisallowedClass => error
  check(error.message == 'Tried to load unspecified class: Time')
  check(error.is_a?(Psych::Exception))
end
begin
  restricted.symbolize('other')
  raise 'unpermitted symbol accepted'
rescue Psych::DisallowedClass => error
  check(error.message == 'Tried to load unspecified class: Symbol')
end
check(!loader.respond_to?(:path2class))

handler = Psych::Handler.new
check(handler.start_stream(1).nil?)
check(handler.start_document([], [], true).nil?)
check(handler.scalar('value', nil, nil, true, false, 1).nil?)
check(handler.end_document(true).nil?)
check(handler.end_stream.nil?)
options = Psych::Handler::DumperOptions.new
check([options.line_width, options.indentation, options.canonical] == [0, 2, false])
check(Psych::Handler::EVENTS.include?(:alias))
puts 'Psych scalar, class-loader and handler protocols match'

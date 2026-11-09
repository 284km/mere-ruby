require 'psych'
require 'psych/handlers/recorder'
require 'yaml'
p YAML.equal?(Psych)

stream = Psych.parse_stream("--- &root\n- one\n- *root\n--- {two: three}\n")
p stream.children.map { |doc| [doc.class.name, doc.root.class.name] }
value = stream.children.first.to_ruby
p [value[0], value.equal?(value[1])]
p Psych.unsafe_load(stream.yaml).first
handler = Psych::Handlers::Recorder.new
parser = Psych::Parser.new(handler)
parser.parse('--- [one, two]')
p handler.events.map(&:first)
begin
  parser.parse('--- [')
rescue Psych::SyntaxError => error
  p [error.class, error.line, !error.problem.nil?]
end
handler.events.clear
parser.parse('--- three')
p handler.events.map(&:first)

[false, true].each do |aliases|
  begin
    value = Psych.safe_load("--- &a [*a]\n", aliases: aliases)
    p value.equal?(value[0])
  rescue Psych::AliasesNotEnabled => error
    p error.class
  end
end
begin
  Psych.safe_load('--- !ruby/object:Object {}')
rescue Psych::DisallowedClass => error
  p error.message
end
p Psych.load_stream(Psych.dump_stream(22, "foo \n", {}))
p Psych.unsafe_load(Psych.dump([1..3, 4..5, false]))

# Psych allocates collection subclasses without calling their constructors.
class PsychStoredString < String
  def initialize; raise 'constructor called'; end
end
class PsychStoredArray < Array
  def initialize; raise 'constructor called'; end
end
class PsychStoredHash < Hash
  def initialize; raise 'constructor called'; end
end
[PsychStoredString, PsychStoredArray, PsychStoredHash].each do |klass|
  object = klass.allocate
  p [object.class.name, object.empty?]
end
h = {}
begin
  h.merge!({'kept' => 1}, [2])
rescue TypeError
  p h
end

# Exception's internal message must coexist with an ordinary @message ivar.
class PsychStoredException < StandardError
  def initialize
    super('internal')
    @message = 'user'
  end
end
exception = PsychStoredException.new
[exception, Psych.unsafe_load(Psych.dump(exception)), Marshal.load(Marshal.dump(exception))].each do |item|
  p [item.message, item.instance_variable_get(:@message), item.instance_variables]
end

module PsychRescueScope
  class Exception < RuntimeError; end
  def self.capture
    begin
      raise 'ordinary error'
    rescue ::Exception => error
      error
    end
  end
end
p PsychRescueScope.capture.message

p respond_to?(:y, true)
require 'psych/y'
p respond_to?(:y, true)
y({'helper' => true})

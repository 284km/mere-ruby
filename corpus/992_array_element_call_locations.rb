object = Object.new
def object.+(other) = raise('binary')
object.define_singleton_method(:-@) { raise('unary') }
def object.to_s = raise('interpolation')
def object.[](key) = raise('index')
def object.call = raise('method')
def location_call_992 = raise('bare')
# Existing call, indexing and bare-call paths are controls. The other shapes
# must carry the same real source line into the evaluator's backtrace.
['object + 1', '-object', '"#{object}"', '!location_call_992',
 'object.call', 'object[0]', 'location_call_992'].each do |element|
  source = "[\n  1,\n  #{element}\n]"
  begin
    eval(source, binding, 'array-element-location.rb', 40)
  rescue => error
    location = error.backtrace_locations.find { |frame| frame.path == 'array-element-location.rb' }
    p [element, error.message, location.lineno]
  end
end
# Continued and nested expressions use their physical line, while a preceding
# multiline literal must not move the next element back to the opening line.
begin
  eval("[\n 'first\nsecond',\n object + 1\n]", binding, 'array-element-location.rb', 70)
rescue => error
  p error.backtrace_locations.find { |frame| frame.path == 'array-element-location.rb' }.lineno
end
require 'tmpdir'
Dir.mktmpdir do |dir|
  ['object + 1', '-object', '"#{object}"', '!location_call_992',
   'object.call', 'object[0]', 'location_call_992'].each do |element|
    path = File.join(dir, 'array-file.rb')
    prefix = <<~'CODE'
      object = Object.new
      def object.+(other) = raise('binary')
      object.define_singleton_method(:-@) { raise('unary') }
      def object.to_s = raise('interpolation')
      def object.[](key) = raise('index')
      def object.call = raise('method')
      def location_call_992 = raise('bare')
      begin
    CODE
    suffix = <<~'CODE'
      rescue => error
        location = error.backtrace_locations.select { |frame| frame.path == __FILE__ }.last
        p [error.message, location.lineno]
      end
    CODE
    File.write(path, prefix + "[\n 1,\n #{element}\n]\n" + suffix)
    print IO.popen([RbConfig.ruby, path], &:read)
    p $?.exitstatus
  end
end
# Crossing a nested expression's newline must invalidate the shared position;
# a semicolon on the same physical line and a continuation keep real lines.
[
  "0 + 1,\n object + 1",
  "Array.new(\n 1), object + 1",
  "(1;\n 2), object + 1",
  "[1,\n 2], object + 1",
  "1 + \\\n 1, object + 1",
  "1\n .to_s, object + 1"
].each do |elements|
  begin
    eval("[\n" + elements + "\n]", binding, 'array-element-location.rb', 100)
  rescue => error
    p [error.class, error.backtrace_locations.find { |frame| frame.path == 'array-element-location.rb' }.lineno]
  end
end
# A large computed literal must share its line lookup across its elements.
# This also exercises the new call-capable shapes on a later physical line.
large = eval("[\n" + '1 + 1,' * 100_000 + "\n]", binding, 'large-operators.rb', 1)
p [large.length, large.first, large.last]

# Eliding a repeated annotation must preserve later calls on the same line,
# including after literals and after nested expressions on different lines.
steady = Object.new
steady.define_singleton_method(:+) { |number| raise('later binary') if number == 1; 0 }
steady.define_singleton_method(:call) { 0 }
steady.define_singleton_method(:to_s) { 'steady' }
[
  "steady + 0, steady + 1",
  "1, steady + 0, steady + 1",
  "steady + 0,\n 1, steady + 1",
  "steady + 0,\n [1,\n 2], steady + 1",
  "steady.call, steady + 1",
  "Array.new(\n 1), steady + 1",
  "<<HERE, steady + 1\n\#{steady}\nHERE"
].each do |elements|
  begin
    eval("[\n" + elements + "\n]", binding, 'array-element-location.rb', 200)
  rescue => error
    p [error.message, error.backtrace_locations.find { |frame| frame.path == 'array-element-location.rb' }.lineno]
  end
end

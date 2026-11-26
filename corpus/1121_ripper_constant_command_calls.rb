require 'ripper'
[
  'a::C {}', 'a.C {}', 'a.foo {}', 'a::foo {}', 'a::C', 'a.C',
  'a::C() {}', 'a::C 1', 'a::C { 2 }', 'self::C {}', 'a::Ä {}',
  'a::C! {}', 'a::C? {}', 'a.C! {}', 'a.C? {}',
  'a::C! do end', 'a::C? do end', 'a::C1 {}', 'a::C_name {}',
  'a::C! 1', 'a::C? 1'
].each { |source| p [source, Ripper.sexp(source)] }

class CommandCallbacks1121 < Ripper
  attr_reader :calls
  def initialize(source)
    @calls = []
    super(source)
  end
  def on_call(*arguments)
    @calls << [:call, arguments.length]
  end
  def on_command_call(*arguments)
    @calls << [:command_call, arguments.length]
  end
end
[
  'a::C {}', 'a::C do end', 'a::C! {}', 'a::C? {}',
  'a::C! do end', 'a::C? do end', 'a::C! 1', 'a::C? 1'
].each do |source|
  parser = CommandCallbacks1121.new(source)
  parser.parse
  p [source, parser.calls]
end

# Object ids and autoloads as test_objectspace and test_autoload ask (note
# 385): every Integer's object_id reads back through ObjectSpace._id2ref,
# past a machine int too, and so do Symbols' (a near miss is "not a symbol id
# value"); _id2ref takes only an Integer; a class's singleton class the
# program opened is one each_object sees; `autoload` with a module as self
# registers in that module; `Object::X` and `::X::Y` fire a top-level autoload,
# another thread's autoload is waited for, and what it defines keeps the file's
# private_constant; defined?(Object::X) is the top-level X.
require "tmpdir"
$VERBOSE = nil
[-0x4000000000000001, -0x4000000000000000, -1, 0, 0x3fffffffffffffff, 0x4000000000000000, :a, :==, nil, true].each do |o|
  p [o, ObjectSpace._id2ref(o.object_id).equal?(o)]
end
[nil, :a, "0"].each do |a|
  begin
    ObjectSpace._id2ref(a)
  rescue TypeError => e
    p e.message
  end
end
begin
  ObjectSpace._id2ref(:a.object_id + 256)
rescue RangeError => e
  p e.message.end_with?("is not a symbol id value")
end
class C361
  class << self
    $c361 = self
  end
end
p ObjectSpace.each_object(Class).any? { |o| o == $c361 }
Dir.mktmpdir("m361") do |dir|
  m = Module.new { autoload :X, dir + "/x.rb" }
  p [m.const_defined?(:X), m.autoload?(:X) == dir + "/x.rb", Object.autoload?(:X)]
  File.write(dir + "/a.rb", "class AutoA361; sleep 0.2; X = 1; end")
  Object.autoload(:AutoA361, dir + "/a.rb")
  p defined?(Object::AutoA361)
  t1 = Thread.new { ::AutoA361::X }
  t2 = Thread.new { AutoA361::X }
  p [t1.value, t2.value]
  File.write(dir + "/b.rb", "class AutoB361; end")
  Object.class_eval { autoload(:AutoB361, dir + "/b.rb") }
  p Object::AutoB361
  File.write(dir + "/z.rb", "class AutoZ361; ZZZ = 1; private_constant :ZZZ; end")
  class AutoZ361; end
  AutoZ361.autoload(:ZZZ, dir + "/z.rb")
  begin
    AutoZ361::ZZZ
  rescue NameError => e
    p e.message
  end
end

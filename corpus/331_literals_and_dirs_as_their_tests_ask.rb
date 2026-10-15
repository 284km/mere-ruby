# Literals and Dir as test_literal and test_dir ask for them (note 355).
def ev(s, b = TOPLEVEL_BINDING) = (begin; eval(s, b); rescue Exception => e; e.class; end)

# ---- 1. the magic comment, as ruby reads it --------------------------------
p eval("# -*- frozen-string-literal: true -*-\n'foo'").frozen?
p eval("# frozen-string-literal: true\n'foo'").frozen?
p eval("# frozen_string_literal: true\n'foo'").frozen?
p eval("# x frozen-string-literal: true\n'foo'").frozen?
p eval("# frozen-string-literal: true x\n'foo'").frozen?
p eval("# frozen-string-literal: true\n['foo', 'bar']").map(&:frozen?)
p eval("# -*- coding: utf-8; frozen_string_literal: true -*-\n'foo'").frozen?

# ---- 2. control and meta escapes, and underscores in numbers ---------------
p "\cA".bytes, "\C-a".bytes, "\M-a".bytes, "\M-\C-a".bytes, "\C-\M-a".bytes, "\c?".bytes
p "a\cbc".bytes, "\cA#{1}".bytes, "\C-\x33".bytes, "\M-\x33".bytes
p ev('"\c啕"'), ev('"\C-啕"'), ev('"\M-啕"')
p eval(%[?\\\u{201c}])
p [ev("1_"), (Float("1_") rescue $!.class)]
p [ev("1__0"), ev("1.0_"), ev("0x_1"), ev("0b1_"), ev("1e1_")]
p [1_000, 0x1_f, 1_0.0_1, 0b1_0]

# ---- 3. value omission and duplicated keys ---------------------------------
FOO = "foo"
b = binding
b.local_variable_set(:if, "if")
b.local_variable_set(:self, "self")
p eval('{FOO:, if:, self:}', b)
p ev('x = 1; {"#{x}":}')
$stderr = $stdout
%w[:foo "a" 1000 1.0 1_000_000_000_000_000_000_000 1.0r 1.0i 1.72723e-77 // __LINE__ __ENCODING__].each do |key|
  eval("{#{key} => :bar, #{key} => :foo}")
end
eval("# frozen_string_literal: false\n{\"b\" => 1, \"b\" => 2}")
$stderr = STDERR

# ---- 4. Dir: NUL, HOME, nested chdir, inspect -------------------------------
$stderr = $stdout
require "tmpdir"
Dir.mktmpdir do |root|
  %i[entries foreach children each_child empty?].each do |m|
    r = begin; x = Dir.send(m, root + "\0"); x = x.to_a if x.respond_to?(:to_a) && !x.is_a?(Array); x.class; rescue => e; [e.class, e.message]; end
    p [m, r]
  end
  p((Dir.chdir(root + "\0") rescue [$!.class, $!.message]))
  p((Dir.open(root + "\0") rescue [$!.class, $!.message]))
  p((Dir.glob(root + "\0") rescue $!.class))
  d = Dir.open(root); p d.inspect.sub(root, "ROOT"); d.close
  p Dir.allocate.inspect.sub(/0x\h+/, "XX")
  pwd = Dir.pwd
  Dir.chdir(root) do
    Dir.chdir(pwd)
    Dir.chdir(root)
    # (a chdir WITH a block comes back itself: no warning)
    Dir.chdir(pwd) { }
  end
  Dir.chdir(pwd)
  dd = Dir.new(root)
  dd.chdir do
    dd.chdir
  end
  dd.close
  Dir.chdir(pwd)
  h = ENV.delete("HOME"); l = ENV.delete("LOGDIR")
  p((Dir.chdir rescue [$!.class, $!.message]))
  ENV["HOME"] = h if h
  ENV["LOGDIR"] = l if l
  q = Thread::Queue.new
  t = Thread.new { q.pop; Dir.chdir(pwd) rescue [$!.class, $!.message] }
  Dir.chdir(pwd) { q.push nil; p t.value }
end

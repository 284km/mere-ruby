# Round 2 of note 533 (language, command_line, proc, method, unboundmethod,
# exception): the method's block reaches a super inside a block a builtin
# iterator runs; a proc's &param is the proc that was passed with &; a class
# scope written as a method call; $/ keeps a frozen String; a singleton's
# alias of a builtin; and the NameError a vcall's method_missing super raises.
require "rbconfig"
require "tmpdir"

# --- super() in a block run by a builtin iterator passes the method's block
class Base
  def m(*) = yield
end
class ViaTimes < Base
  def m(v) = (r = nil; 1.times { r = super() }; r)
end
class ViaEach < Base
  def m(v) = (r = nil; [1].each { r = super(v) }; r)
end
class ViaMap < Base
  def m(v) = [1].map { super() }.first
end
class ViaTap < Base
  def m(v) = (r = nil; tap { r = super }; r)
end
class DropsIt < Base
  def m(v) = [1].map { (super(&nil) rescue $!.class) }.first
end
p ViaTimes.new.m(:a) { :times }
p ViaEach.new.m(:a) { :each }
p ViaMap.new.m(:a) { :map }
p ViaTap.new.m(:a) { :tap }
p DropsIt.new.m(:a) { :never }

# --- a block parameter &b is the proc that was passed with &
l = -> {}
pr = proc { |x, &b| b }
la = ->(x, &b) { b }
kw = ->(x, f: 2, &b) { b }
p pr.(1, &l).equal?(l), la.call(1, &l).equal?(l), kw.(1, &l).equal?(l)
p la.(1, &(q = proc {})).equal?(q)
p pr.call(1) { }.lambda?, pr.call(1).nil?
# ...and a literal block is no &pr: a source proc an empty each never read
src = proc { :src }
{}.each(&src)
p Proc.new { :lit }.call
[].each(&src)
p proc { :lit2 }.call

# --- Proc#=== with a block, by send; and #inspect is BINARY like #to_s
%i[call === yield []].each { |m| p [m, proc { |&b| b.send(m) }.send(m) { 1 + 1 }] }
p proc {}.inspect.encoding, -> {}.to_s.encoding

# --- `class expr::Name` where expr is a method call
module Home; end
def home = Home
class home::Inner; end
p Home::Inner
o = Object.new
begin
  o.instance_eval("class singleton_class::A; @@zz; end")
rescue NameError => e
  p [e.class, e.receiver.equal?(o.singleton_class::A)]
end
begin
  class nil::Nope; end
rescue TypeError => e
  p e.message
end
# ...and no class or module is a statement of a method body (a block in one
# included), but `class << obj` is, and its body is no method body
["def f; class X; end; end", "def f; module M; end; end", "def f; [1].each { class X; end }; end",
 "def f = (class X; end)", "def f; class << self; class X; end; end; end", "x = def f; end; class X2; end"].each do |src|
  eval(src)
  p :ok
rescue SyntaxError => e
  p e.message[/unexpected \w+ definition in method body/]
end

# --- $/ keeps a new frozen String, or the String itself when it already is one
sub = Class.new(String)
s = sub.new("abc")
s.instance_variable_set(:@iv, 1)
$/ = s
p [$/.frozen?, $/.class, $/.instance_variable_defined?(:@iv), $/ == s, $/.equal?(s)]
f = "xyz".freeze
$-0 = f
p $/.equal?(f)
$/ = "\n"

# --- a singleton's alias of a builtin is a method of the class
class Made
  class << self
    alias_method :make, :new
  end
end
p Made.respond_to?(:make), Made.make.class
p Made.method(:new) == Made.method(:make)
p Made.method(:make) == Class.instance_method(:new).bind(Made)
p Made.method(:new) == Class.instance_method(:new).bind(Made)
p String.method(:new) == Class.instance_method(:new).bind(String)

# --- a method_missing's super for a bare name is a NameError
class MM
  def method_missing(*) = super
  def bare = foo
  def called = foo()
end
mm = MM.new
[-> { mm.bare }, -> { mm.called }, -> { mm.instance_eval("foo") },
 -> { mm.instance_eval { foo } }, -> { mm.public_send("bar", true) }].each do |c|
  c.call
rescue NameError => e
  p [e.class, e.message, e.name]
end

# --- -r does not run for a script that is not there
Dir.mktmpdir do |d|
  lib = File.join(d, "req.rb")
  File.write(lib, "puts 'REQUIRED'\n")
  out = IO.popen([RbConfig.ruby, "-r", lib, File.join(d, "missing.rb"), err: [:child, :out]], &:read)
  p [out.include?("REQUIRED"), out.include?("No such file or directory"), $?.success?]
end

# --- a proc's return at a loaded file's top level ends that file, not the
# program (and not a method the load was called from)
Dir.mktmpdir do |d|
  f = File.join(d, "topret.rb")
  File.write(f, "$r << :before\nproc { return }.call\n$r << :after\n")
  $r = []
  load f
  p $r
  def loads_it(f) = (load f; :after_load)
  p loads_it(f), $r
end
p :still_running

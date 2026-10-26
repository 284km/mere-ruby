# What ruby/spec's language and core/kernel files ask of the corners: a
# lambda yielded to returns from itself on break, a block's parameters and
# block-locals share one namespace, constants that start with a non-ASCII
# capital, the unused-block warning, a top-level return with a value, load and
# require paths, eval's own scope, and the refusals that go with them
require "rbconfig"
require "tmpdir"

warned = []
Warning.singleton_class.define_method(:warn) { |m, **| warned << m.sub(/\A.*?warning: /, "").sub(/ defined at .*? may/, " defined at ... may") }

def try424
  yield
rescue ScriptError, StandardError => e
  e
end

def iy; r = yield; [:after, r]; end
l = -> { break :brk; :no }
p iy(&l)

def m1(a) yield a end
p((m1([1, 2]) { |a, b:, c:| } rescue $!.message))
def y2(a, b) yield a, b end
p y2(1, 2) { |_, _| _ }
["[1].each {|foo; foo| }", "[1].each {|a, b; c, b| }", "lambda { |x,x| }", "def f(a, *b, *c); end"].each do |c|
  p [c, try424 { eval(c); :ok }.class]
end

mod = Module.new
mod.const_set("ἍBB", 1)
p eval("mod::ἍBB")
ÉCOLE = 3
p defined?(ÉCOLE), Object.const_defined?(:ÉCOLE)
p try424 { eval("def t424\n ÉTÉ = 1\nend") }.class

def f2(a, b, *c); end
p((f2(1) rescue $!.message))
def f3(a, b = 2, *c) = [a, b, c]
p((f3 rescue $!.message), f3(1))
o = Object.new
c = o.singleton_class
c.singleton_class.freeze
p((def c.foo; end rescue $!.message.sub(/0x\h+/, "XX")))

["def m\n", "class A", "def m\n\0end"].each { |c| p try424 { eval(c) }.message[/unexpected end-of-input/] }

$VERBOSE = true
$lazy_g ||= 42
def unused_blk; 42; end
def uses_yield; yield; end
unused_blk { }
unused_blk { }
uses_yield { }
parent = Class.new { def m; end }
child = Class.new(parent) { def m; super; end }
child.new.m { }
eval("x = 1\n# frozen_string_literal: true\nnil")
$VERBOSE = false
p warned

begin
  begin
    raise "from block"
  rescue (raise "from rescue expression")
  end
rescue => e
  p [e.message, e.cause.message]
end
p eval('1.+ (raise("x") rescue 1)')
p try424 { eval("a = 1 rescue RuntimeError 2"); :ok }.class
p((eval("a = nil.x rescue defined? 1")))

eval("a424 = 2")
p((eval("a424") rescue $!.class))
x424 = 1
eval("x424 += 1")
p x424
alias aliased_eval424 eval
aliased_eval424("x424 += 40")
p x424
module ET424; def self.call_yield; yield; end; end
p((eval("ET424.call_yield") { :content } rescue $!.class))

Dir.mktmpdir do |dir|
  sub = File.join(dir, "sub")
  Dir.mkdir(sub)
  File.write(File.join(sub, "la424.rb"), "p :loaded_from_to_path")
  File.write(File.join(dir, "home424.rb"), "p :loaded_from_home")
  File.write(File.join(dir, "cls424.rb"), "class Cls424\n  return\nend\n")
  File.write(File.join(dir, "begin424.rb"), "BEGIN {\n  p :in_begin\n  return\n}\np :after_begin\n")
  File.write(File.join(dir, "ret424.rb"), "return 10\n")
  File.write(File.join(dir, "ae424.rb"), "at_exit { puts 'handler ran' }\n")
  unread = File.join(dir, "unread424.rb")
  File.write(unread, "p 1")
  File.chmod(0, unread)
  tp = Object.new
  tp.define_singleton_method(:to_path) { sub }
  $LOAD_PATH.unshift tp
  load "la424.rb"
  $LOAD_PATH.shift
  home = ENV["HOME"]
  ENV["HOME"] = dir
  load "~/home424.rb"
  ENV["HOME"] = home
  p try424 { load unread; :ok }.class
  File.chmod(0644, unread)
  p try424 { load File.join(dir, "cls424.rb"); :ok }.class
  load File.join(dir, "begin424.rb")
  rr = try424 { require_relative File.join(dir, "sub", "..", "nope424") }
  p rr.path == File.join(dir, "nope424"), rr.message.include?("/sub/..")
  p IO.popen([RbConfig.ruby, File.join(dir, "ret424.rb"), err: [:child, :out]], &:read).sub(/\A.*: warning/, "warning")
  p IO.popen([RbConfig.ruby, "-r", File.join(dir, "ae424.rb"), "-e", "{", err: [:child, :out]], &:read).include?("handler ran")
  p IO.popen([RbConfig.ruby, "-n", "-e", "print Kernel.public_methods(false).include?(:chomp)"], "r+") { |io| io.puts; io.close_write; io.read }
end

autoload :KSAutoload424, "main_autoload_not_exist_424.rb"
main = TOPLEVEL_BINDING.eval("self")
main.define_singleton_method(:require) { |path| puts "main.require #{path}"; false }
p((KSAutoload424 rescue $!.class))

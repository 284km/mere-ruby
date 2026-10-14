# Exceptions as CRuby's test_exception asks them (note 329): the refusals
# that were silently accepted -- a rescue splat of non-classes, a raise of
# four arguments, a warn keyword it does not take, a cause that leads back
# to its exception, a visibility change naming no method, an include of a
# non-module -- and the backtrace and full_message rules around them.
def t(n)
  r = begin; yield.inspect; rescue Exception => e; "#{e.class}: #{e.message}"; end
  puts "#{n}: #{r.gsub(/0x\h+/, '0x')}"
end
t(1) { begin; raise "x"; rescue *Array(1); end }
t(2) { raise 1, 1, 1, 1 }
t(3) { warn("x", foo: 1) }
t(4) { warn("x", foo: 1, bar: 2) }
t(5) { Marshal.load("\x04\bo:\x11RuntimeError\b:\tmesgI\"\berr\x06:\x06ET:\abt[\x00:\ncause@\x05") }
t(6) { Module.new { module_function :foo } }
t(7) { Class.new { private :nope } }
t(8) { Class.new { private :to_s; public :inspect; protected :hash }.private_instance_methods(false).sort }
t(9) { obj = Object.new; Class.new { include obj } }
class Exc307 < StandardError; attr_reader :arg; def initialize(arg) = (@arg = arg; super(arg.to_s)); end
t(10) { begin; raise Exc307, "a" => 1, b: 2, cause: RuntimeError.new("z"); rescue Exc307 => e; [e.arg, e.cause]; end }
t(11) { c = Class.new(StandardError) { def backtrace = :bt }; begin; raise c; rescue c => e; [($@ rescue $!.message), (e.full_message rescue $!.class)]; end }
t(12) { [RuntimeError.new("a\n").full_message(highlight: false).end_with?("\n\n"), (RuntimeError.new("a").full_message(order: :middle) rescue $!.message)] }
t(13) { e = Class.new(Exception) { def to_s = "" }; [e.new.inspect == e.inspect, Exception.new("foo\nbar").inspect, Exception.new("foo bar").inspect] }
t(14) { [Errno.constants.grep_v(/\AE/), Errno::NOERROR.superclass, Errno::NOERROR::Errno, SystemCallError.new("m", 0).class] }
t(15) { [(::Warning.warn(nil) rescue $!.message), (::Warning.warn(1) rescue $!.message), (::Warning.warn("\x00a".force_encoding("UTF-16BE")) rescue $!.class)] }
class Ex307; end
def x307(a) = nil
t(16) { x307(**Ex307.new) }
# ...and an ALIAS of a builtin is a method a visibility change may name
# (ostruct's `alias_method :raise!, :raise; private :raise!`)
class Fo307; alias_method :raise!, :raise; private :raise!; alias_method :fr307, :freeze; public :fr307; end
class Class; alias _rc307 remove_const; public :_rc307; end
t(17) { [Fo307.new.respond_to?(:fr307), Fo307.new.fr307.frozen?] }

# Round 13 of note 541 (the small items): a binding's local named self is
# no receiver; `raise e` of a rescued SystemStackError keeps its frames;
# a Regexp made at run time holds instance variables, extends, has an
# object_id of its own and survives Marshal; a copy of Time answers Time's
# class methods; defined? of __FILE__, `%x`, :"#{}", a named-capture =~ and
# `1 => 1`; `Const op= v` in a class body; a literal's element as a
# multiple-assignment target; `return *a, **kw`; `alias $a $b` and a
# backtick in a class body; InstructionSequence#to_a's misc hash and
# compile_file's errno; OpenSSL::KDF's argument errors; write_nonblock
# leaves the stream non-blocking.
require "socket"
require "io/nonblock"
require "openssl"

# --- a binding's local named self
def bind_self
  b = binding
  b.local_variable_set(:self, "S")
  b.local_variable_set(:if, "I")
  [self.class, b.local_variable_get(:self), b.local_variable_defined?(:self), eval("{if:, self:}", b)]
end
p bind_self

# --- re-raising keeps the frames
def deep = deep
e = (begin; deep; rescue SystemStackError => x; x; end)
n = e.backtrace.size
e2 = (begin; raise e; rescue SystemStackError => y; y; end)
p n > 100, n == e2.backtrace.size, e2.equal?(e), e.message

# --- a Regexp made at run time
module Meths; def hi = :hi; end
r = Regexp.new("ab")
r.instance_variable_set(:@a, 1)
r.extend(Meths)
p r.instance_variables, r.hi, (class << r; ancestors; end).take(2).last
p Regexp.new("x").object_id == Regexp.new("x").object_id, r.object_id == r.object_id
p((/lit/.extend(Meths) rescue $!.class), (/lit/.instance_variable_set(:@a, 1) rescue $!.class))
r2 = Marshal.load(Marshal.dump(r))
p r2.source, r2.instance_variable_get(:@a), r2.hi

# --- a copy of Time
t = Time.dup
a = t.at(0)
p a.to_i, t.new(2000).year, a.is_a?(Time), t.now.class == t

# --- defined?
p defined?(__FILE__), defined? __FILE__, defined? __ENCODING__, defined?(%x[true])
p defined?(:"#{1}"), defined?(/(?<foo>bar)/ =~ "x"), defined?(1 => 1)
class DefinedYield; p defined? yield; end

# --- a constant op-assigned in a class body
class OpConst
  X = 1
  X += 1
  X *= 5
  Y ||= 7
  p [X, Y]
end
$VERBOSE = nil
p((eval("class OpConst; Q += 1; end") rescue $!.class))

# --- a literal's element as a target
_, {}[:foo] = 1
{}[:bar], _ = 1, 2
a1, [][0] = 3, 4
p a1

# --- return with splats
def rsplat(*a, **k) = (return *a, *a, **k)
def rdsplat = (return **{foo: 1})
p rsplat(1, foo: 0), rdsplat

# --- alias $a $b and a backtick, in a class body
class GAlias; alias $round13_new $round13_old; end
$round13_old = :old
p $round13_new
class Tick
  def self.`(c) = c * 2
  p `pit`
end

# --- InstructionSequence
iseq = RubyVM::InstructionSequence.compile_prism("proc { <<END }\n hello\nEND")
p iseq.to_a[4][:node_id] >= 0
p((RubyVM::InstructionSequence.compile_file_prism("idontexist.rb") rescue $!))

# --- OpenSSL::KDF
p((OpenSSL::KDF.pbkdf2_hmac("s", salt: "x", iterations: Object.new, length: 4, hash: "SHA1") rescue $!))
p((OpenSSL::KDF.pbkdf2_hmac("s", salt: "x", iterations: 0, length: 4, hash: "SHA1") rescue $!))
p((OpenSSL::KDF.pbkdf2_hmac("s", salt: "x", iterations: 1, length: 4, hash: "wd40") rescue $!.class))
p((OpenSSL::KDF.scrypt("s") rescue $!))
p((OpenSSL::KDF.scrypt("s", salt: "x", N: 3, r: 1, p: 1, length: 4) rescue $!.class))
p OpenSSL::KDF.pbkdf2_hmac("s", salt: "x", iterations: 1, length: 4, hash: "SHA1").unpack1("H*")

# --- write_nonblock and nonblock?
rs, ws = IO.pipe
ws.nonblock = false
ws.write_nonblock("aaa")
p ws.nonblock?

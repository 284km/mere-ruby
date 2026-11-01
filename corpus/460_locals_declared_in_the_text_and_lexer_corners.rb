# Locals ruby declares by where they are WRITTEN, not by what ran
for a in []; end
p a
for b, c in []; end
p [b, c]
r = for x in [1, 2]; end
p r, x
begin; for u, v in []; end; end if u != v
p :guarded
w = 5 unless w
p w
(y = 1) if y.nil?
p y
def m460; z = 2 unless defined?(z); z; end
p m460
for i,
    j in [[1, 2]]
end
p [i, j]

# a colon or a ? right after a value is an operator
p({"k":"v"}, {'k':'v'})
t = 1
p(t ? 'x':'y', t ? 2 :"y", t ? t :"q")
"a1" =~ /(1)/
p($1?2:3, 1?1:$&, $1?%w[a b]*$1:2)
@iv = 1
p(@iv ?"x":"y")
s = "a"
p(s>?-?:v:3)
p(t ? ('x'):s)
def d460() :ok end
p d460

# percent literals
p 'a%s'.% %%b%
p %q`a#{b`, %w['a'#{], %i[a#{ b]
p %(#{t}x)

# special globals are values
$* << 7
p $*.size
$*.clear

# operator method names take paren-less splat params; rescue ... then
class C460; def []*a; a; end; def <=>o; 0; end; end
p C460.new[1, 2], C460.new <=> 1
n = 0
begin
  n += 1
  raise "x" if n < 3
rescue then retry
end
p n
begin; raise "y"; rescue RuntimeError => e then p e.message; end

# `alias end close` names a method: the lexer's opener table keeps the module
# open (-w's indentation check measured the module against the wrong `end`)
require "tmpdir"
Dir.mktmpdir do |d|
  f = File.join(d, "m460.rb")
  File.write(f, "module M460\n  def close = 1\n  alias end close\n  def x = 2\nend\n")
  got = []
  Warning.singleton_class.class_eval { alias_method :__w460, :warn }
  Warning.define_singleton_method(:warn) { |m, **| got << m }
  v, $VERBOSE = $VERBOSE, true
  begin
    load f
  ensure
    $VERBOSE = v
    Warning.singleton_class.class_eval { alias_method :warn, :__w460 }
  end
  p got, M460.instance_methods.sort
end

# a named format reference is a name in the format's encoding
k = "\u{3012}".encode("EUC-JP")
begin
  sprintf("%{#{k}}", {})
rescue KeyError => e
  p e.message.encoding, e.message.b, e.key.encoding
end
begin
  sprintf("%<#{k}>{key}s", k.to_sym => "value")
rescue ArgumentError => e
  p e.message.encoding, e.message.b
end

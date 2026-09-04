# `defined?` -- the categories, and the two questions it does NOT ask.
#
# 116 of language/defined_spec's assertions failed on one file. The rules that
# were missing, in the order they were found:
#
#   - `&&`, `||`, `and`, `or` are CONTROL FLOW, not method calls, so they are
#     "expression" however undefined their operands are. Every other operator
#     IS a method call, and there ruby EVALUATES the operands (side effects and
#     all), answers nil if that raises, and then asks whether the value the
#     left operand produced actually has the operator.
#   - a desugared string or regexp LITERAL is "expression", not the `+` chain
#     it is built from -- including one whose interpolation would raise,
#     because defined? never evaluates it.
#   - `a[0] = 1` is the []= CALL ("method"); `x = 1` is an "assignment". Only a
#     plain `=` splits that way: an op-assign is "assignment" either way.
#   - $! and $~ are "global-variable" even when nothing was raised or matched;
#     $&, $`, $' and $+ are read out of $~, so they follow the last match.
#   - a bare word inside defined?(...) is taken as a NAME, so __LINE__ and
#     `break` never reach the nodes they would parse to.
#   - an array literal is defined only if every element is.
#   - the answer is a FROZEN string.
#   - `defined? super` without parens is a real super node, and it walks the
#     ancestors -- modules included -- exactly as a real super does.
#   - a constant read walks the lexical nesting and then the ancestors.

def show(label)
  puts "%-38s %s" % [label, (yield).inspect]
end

x = 1
a = [1]
h = { k: 1 }
$g = 1
@iv = 1
CONST = 1
def m; 1; end

$ran = :not_executed
module DS
  def self.side_effects; $ran = :ran; :recorded; end
  def self.fixnum_method; 42; end
  def self.raises; raise "boom"; end
end

# control flow against method calls
show('$undef && true')   { defined?($ds_undef && true) }
show('true and false')   { defined?(true and false) }
show('true || false')    { defined?(true || false) }
show('@undef_iv && true'){ defined?(@ds_undef_iv && true) }
show('DS.side_effects && true') { defined?(DS.side_effects && true) }
show('  did it run?')    { $ran }
show('1 + 1')            { defined?(1 + 1) }
show('1 == 1')           { defined?(1 == 1) }
show('!true')            { defined?(!true) }
show('undef == 1')       { defined?(ds_nope1 == 1) }
show('1 == undef')       { defined?(1 == ds_nope2) }
show('!undef')           { defined?(!ds_nope3) }
show('not undef')        { defined?(not ds_nope4) }
show('!@unset_iv')       { defined?(!@ds_unset_iv) }
show('!$unset_gv')       { defined?(!$ds_unset_gv) }
show('not DS.raises')    { defined?(not DS.raises) }
show('DS.raises == 1')   { defined?(DS.raises == 1) }
$ran = :not_executed
show('DS.side_effects == 1') { defined?(DS.side_effects == 1) }
show('  did it run?')    { $ran }
show('DS.fixnum_method / 2') { defined?(DS.fixnum_method / 2) }

# literals
show('"plain"')          { defined?("plain") }
show('"a #{42}"')        { defined?("a #{42}") }
show('"a #{DS.nope}"')   { defined?("a #{DS.undefined_method}") }
show('/a #{42}/')        { defined?(/a #{42}/) }
show('/a #{DS.nope}/')   { defined?(/a #{DS.undefined_method}/) }
show('/plain/')          { defined?(/plain/) }
show('[1, 2]')           { defined?([1, 2]) }
show('[Object, Array]')  { defined?([Object, Array]) }
show('[Object, Nope]')   { defined?([Object, DsNopeConst]) }

# assignment against the setter call
show('x = 1')            { defined?(x = 1) }
show('@iv = 1')          { defined?(@iv = 1) }
show('CN = 1')           { defined?(CN = 1) }
show('a[0] = 1')         { defined?(a[0] = 1) }
show('h[:k] = 1')        { defined?(h[:k] = 1) }
show('x += 1')           { defined?(x += 1) }
show('a[0] += 1')        { defined?(a[0] += 1) }
show('x ||= 1')          { defined?(x ||= 1) }
show('(p9, q9 = 1, 2)')  { defined?((p9, q9 = 1, 2)) }
show('frozen?')          { defined?(x = 1).frozen? }
show('frozen? (method)') { defined?(m).frozen? }

# the categories
show('x')                { defined?(x) }
show('CONST')            { defined?(CONST) }
show('NOPE')             { defined?(DsNopeConst2) }
show('@iv')              { defined?(@iv) }
show('@nope')            { defined?(@ds_nope_iv) }
show('$g')               { defined?($g) }
show('$nope')            { defined?($ds_nope_gv) }
show('m')                { defined?(m) }
show('nope')             { defined?(ds_nope_meth) }
show('self')             { defined?(self) }
show('nil')              { defined?(nil) }
show('__FILE__')         { defined?(__FILE__) }
show('__LINE__')         { defined?(__LINE__) }
show('__ENCODING__')     { defined?(__ENCODING__) }

# The match globals, read at TOP LEVEL. `$~` is scoped to the frame that
# matched, and a block does not yet see its DEFINING frame's match here
# (KNOWN_GAPS), so putting these inside `show { }` would be testing that gap
# instead of this one.
puts "$! (nothing raised)                   #{defined?($!).inspect}"
puts "$~ (nothing matched)                  #{defined?($~).inspect}"
puts "$& (nothing matched)                  #{defined?($&).inspect}"
"mis" =~ /z(z)z/
puts "$~ after a failed match                #{defined?($~).inspect}"
puts "$& after a failed match                #{defined?($&).inspect}"
"abc" =~ /a(b)c/
puts "$~ after a match                       #{defined?($~).inspect}"
puts "$& after a match                       #{defined?($&).inspect}"
puts "$1 after a match                       #{defined?($1).inspect}"
puts "$+ after a match                       #{defined?($+).inspect}"
p $~
p [$~]

# super, through a superclass and through a module
class Sup; def only_sup; end; end
class SubA < Sup
  def only_sup; defined? super; end
  def only_sup_paren; defined?(super); end
  def no_super; defined? super; end
end
module SupMod; def sm; end; end
module MidMod; def sm; defined?(super); end; end
class SupHost
  include SupMod
  include MidMod
  def sm; super; end
end
show('super (bare)')      { SubA.new.only_sup }
show('super (parens)')    { SubA.new.only_sup_paren }
show('super (none)')      { SubA.new.no_super }
show('super via a module'){ SupHost.new.sm }

# a constant through an included module
module Mixin
  MixinConstant = 1
  def mixin_method; end
end
class Host
  include Mixin
  def self.d_mod;   defined?(Mixin); end
  def self.d_const; defined?(MixinConstant); end
  def d_meth;       defined?(mixin_method); end
end
show('defined?(Mixin)')          { Host.d_mod }
show('defined?(MixinConstant)')  { Host.d_const }
show('defined?(mixin_method)')   { Host.new.d_meth }

# a method asked of a receiver
show('1.to_s')            { defined?(1.to_s) }
show('1.foo')             { defined?(1.foo) }
show('"s".upcase')        { defined?("s".upcase) }
show('"s".nope')          { defined?("s".nope) }
show('[].map')            { defined?([].map) }
show(':s.to_proc')        { defined?(:s.to_proc) }
show('1[0]')              { defined?(1[0]) }
show('nil.nope')          { defined?(nil.nope) }

# respond_to? has to give the same answer the call does -- the operators were
# invisible to it, and Symbol had no entry at all.
%w[+ - * / % ** < <= > >= << >> & | ^ ~ ! [] === =~].each do |op|
  row = [1, 1.0, "s", [], {}, :s, nil, true, (1..2), /r/, Rational(1, 2), 2**70].map do |v|
    v.respond_to?(op.to_sym) ? "y" : "."
  end
  puts "%-4s %s" % [op, row.join]
end
p :s.respond_to?(:to_proc), :s.respond_to?(:length), :s.respond_to?(:id2name)
p :abc.id2name, :abc.name, :abc.name.frozen?

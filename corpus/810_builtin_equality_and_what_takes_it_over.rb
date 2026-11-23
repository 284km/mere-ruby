# coding: utf-8
# `==` / `!=` of a builtin value -- a String, Symbol, nil, true, false, Array,
# Hash -- answered by the VM without a scope when nothing is in the way, and
# the general way when something is: an argument with #to_str / #to_ary or
# its own #==, a Numeric that coerces, a subclass's or a singleton's #==, a
# refinement, a prepended #==, a redefined Array#==, an undefined Symbol#==.
def t(label) = (p [label, yield] rescue p [label, $!.class, $!.message])
t(:plain) { ["a" == "a", "a" == "b", "a" != "a", "a" == 1, :s == :s, :s != :t, nil == nil, nil == false, true != false, [1, [2]] == [1, [2]], {a: 1} == {a: 1}, [1] == [1.0], "é" == "é".b, "a" == "a".b, "é".encode("UTF-16LE") == "é"] }
class ToStr; def to_str = "x"; def ==(o) = (o == "x"); end
class ToAry; def to_ary = [1]; def ==(o) = (o == [1]); end
class EqObj; def ==(o) = :custom; end
t(:to_str) { ["x" == ToStr.new, "y" == ToStr.new, [1] == ToAry.new, [EqObj.new] == [EqObj.new], 1 == EqObj.new] }
class Coer; def coerce(o) = [o, 5]; def ==(o) = (o == 5); end
t(:coerce) { [5 == Coer.new, 5.0 == Coer.new] }
class SubS < String; def ==(o) = :subs; end
t(:subclass) { [SubS.new("a") == "a", "a" == SubS.new("a")] }
s = +"q"; def s.==(o) = :sng
t(:singleton) { [s == "q", s != "q"] }
module Ref; refine(String) { def ==(o) = :refined }; end
module UseRef; using Ref; def self.go = ["a" == "a"]; end
t(:refine) { UseRef.go + ["a" == "a"] }
module PreEq; def ==(o) = :prepended; end
String.prepend(PreEq)
t(:prepend) { ["a" == "a", "a" != "b"] }
class Array; def ==(o) = :redef_ary; end
t(:redef) { [[1] == [1], [1] != [1]] }
class Symbol; undef_method :==; end rescue p $!
t(:undef) { :a == :a }

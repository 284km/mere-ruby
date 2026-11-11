# Round 21 of note 544 (stage 6, RubyGems): a class body's value outlives its
# env, a decorated #message on a raised exception, Comparable's != and an
# Array's eql?, rows of objects sorted, a constant asked of a compact class,
# a loop modifier's local, a superclass from the enclosing class's ancestors,
# a standard stream's position, OpenSSL::Digest by Symbol, and an Indic
# conjunct as one grapheme cluster.

# module_eval's value read as another call's argument (the env it ran in
# goes back to the pool before the call)
class EvalSelf
  def show(*a) = a
  def go = [show(self.class.module_eval("self")), show(self.class.module_eval { self }), show(1, EvalSelf.class_exec { self })]
end
p EvalSelf.new.go

# super into Exception#message from an exception raised as `raise Cls, msg`
class Decorated < StandardError
  def message = "<" + super + ">"
end
begin
  raise Decorated, "inner"
rescue => e
  p e.message
end

# != is Comparable's == negated; Array#eql? asks each pair eql?
class Ver
  include Comparable
  attr_reader :s
  def initialize(s) = @s = s
  def <=>(o) = o.is_a?(Ver) ? s.to_f <=> o.s.to_f : nil
  def eql?(o) = o.is_a?(Ver) && s == o.s
  def hash = s.hash
  def inspect = "v#{s}"
end
a, b = Ver.new("1.3"), Ver.new("1.30")
p a == b, a != b, [a].eql?([b]), [["~>", a]] == [["~>", b]], [["~>", a]].eql?([["~>", Ver.new("1.3")]])
p [["=", Ver.new("2")], ["=", Ver.new("1")]].sort, [["=", a], ["=", b]].sort.hash == [["=", b], ["=", a]].sort.hash

# defined? of a constant inside `class A::B::C` sees C and the top level, as
# reading it does -- not A::B or A
module Outer21; Hidden = 1; module Mid; end; end
class Outer21::Mid::Inner
  def self.probe = [defined?(Hidden), (Hidden rescue :name_error)]
end
p Outer21::Mid::Inner.probe

# a loop modifier's statement is written before its condition
def drain(xs)
  line = xs.shift until line == "b"
  n = (n || 0) + 1 while n.nil? || n < 3
  [line, n, xs]
end
p drain(%w[a b c])

# `class E < X` inside `class S < Base` finds X among Base's constants
class Base21
  class Empty21 < Base21
    def empty? = true
  end
end
class Scope21 < Base21
  class EmptyScope21 < Empty21; end
end
p Scope21::EmptyScope21.superclass, Scope21::EmptyScope21.new.empty?, Object.const_defined?(:Empty21)

# a standard stream reopened onto a file has that file's position
require "tempfile"
Tempfile.create("out21") do |tf|
  saved = $stdout.dup
  $stdout.reopen(tf)
  print "captured"
  $stdout.flush
  pos = $stdout.pos
  $stdout.rewind
  at = $stdout.pos
  $stdout.reopen(saved)
  saved.close
  p [pos, at, File.read(tf.path)]
end

# OpenSSL::Digest takes the name as a Symbol too
require "openssl"
p OpenSSL::Digest(:SHA256).hexdigest("x")[0, 16]

# GB9c: a consonant, a virama and a consonant are one cluster
p "क्त".grapheme_clusters.size, "क्तक".grapheme_clusters.size, "कत".grapheme_clusters.size

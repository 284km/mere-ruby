# The shapes the review of the first R2 round asked about, and the next
# ActiveSupport ones: super into a value's builtin must neither come back to
# a module prepended to the builtin class nor lose what the builtin keeps.

def try
  yield
rescue SystemStackError
  "SystemStackError"
rescue => e
  "#{e.class}: #{e.message[0, 60]}"
end

# a module prepended to String / Range, super into the builtin
module GsubPassing
  def gsub(*a, &b) = super
  def sub(*a, &b) = super
end
String.prepend GsubPassing
p try { "aa".gsub("a", "b") }, try { "[aa]".sub("aa", "bb") }, try { "aa".gsub("a") { "c" } }
module CoverPassing
  def cover?(v) = super
  def include?(v) = super
end
Range.prepend CoverPassing
p try { (1..5).cover?(3) }, try { (1..5).cover?(9) }, try { (1..5).cover?(2..3) }, try { ("a".."e").cover?("c") }
p try { (1..5).include?(3) }

# a Hash subclass with its own #each keeps Hash#select / #reject
class EachHash < Hash
  def each(&b) = super
  def select(&b) = super
  def reject(&b) = super
end
eh = EachHash[{a: 1, b: 2}]
p try { eh.select { |_k, v| v > 1 } }, try { eh.reject { |_k, v| v > 1 } }, try { eh.select { true }.class }

# a frozen String subclass refuses gsub! / sub! through super
class FrozenBuf < String
  def gsub!(*a) = super
  def sub!(*a) = super
end
fb = FrozenBuf.new("aa").freeze
p try { fb.gsub!("a", "b") }, fb, try { fb.sub!("a", "b") }

# Kernel#=== by name only where Kernel's is reachable
class Bare < BasicObject; end
p try { Bare.new.__send__(:===, 1) }
class NoCaseEq; undef_method :===; end
p try { NoCaseEq.new.__send__(:===, 1) }

# Object#respond_to_missing? takes two arguments, from a value's super too
class Array
  def respond_to_missing?(*a) = super
end
p try { [].send(:respond_to_missing?, :x) }, try { [].send(:respond_to_missing?, :x, false) }

# a protected method of a String / Hash subclass, called from another of its
# methods on another value of the class (SafeBuffer#* calls mark_unsafe!)
class Marked < String
  def *(n)
    made = self.class.new(super)
    made.mark!
    [made.class, made.marked?]
  end
  def marked? = !!@marked
  protected def mark! = @marked = true
end
p try { Marked.new("ab") * 2 }
class MarkedHash < Hash
  def copy_marked = (o = MarkedHash.new; o.mark!; o.marked?)
  def marked? = !!@marked
  protected def mark! = @marked = true
end
p try { MarkedHash.new.copy_marked }

# String#initialize through super keeps the encoding of the string given
class EncBuf < String
  def initialize(str = "") = super
end
p EncBuf.new.encoding, EncBuf.new("x").encoding, EncBuf.new("x".encode("EUC-JP")).encoding
class KwBuf < String
  def initialize(s, **kw) = super
end
k = KwBuf.new("z", encoding: "EUC-JP")
p k, k.encoding

# method_missing on a String / Array subclass (ActiveSupport::StringInquirer)
class Inquiry < String
  private
  def respond_to_missing?(name, include_private = false) = name.end_with?("?") || super
  def method_missing(name, ...) = name.end_with?("?") ? self == name[0..-2] : super
end
env = Inquiry.new("production")
p try { env.production? }, try { env.development? }, env.respond_to?(:staging?)
class ArrayInquiry < Array
  private
  def method_missing(name, *) = name.end_with?("?") ? include?(name[0..-2].to_sym) : super
end
p try { ArrayInquiry.new([:a, :b]).a? }, try { ArrayInquiry.new([:a]).c? }

# HashWithIndifferentAccess#transform_keys(mapping) calls super, with or
# without a block
class KeyHash < Hash
  NONE = Object.new
  def transform_keys(mapping = NONE, &block)
    if NONE.equal?(mapping)
      block ? self.class[super(&block)] : to_enum(:transform_keys)
    else
      self.class[super]
    end
  end
end
kh = KeyHash[{ "a" => 1, "b" => 2 }]
p try { kh.transform_keys(&:upcase) }, try { kh.transform_keys({ "a" => "x" }) }
p try { kh.transform_keys({ "a" => "x" }) { |k| k * 2 } }

# gsub with a Hash replacement looks each match up as a string of the
# receiver's encoding (ActiveSupport's JSON escaping maps U+2028's bytes,
# BINARY, to a six-character escape). The bytes are packed, so that nothing
# between the source and the interpreter can change them.
sep = [0xE2, 0x80, 0xA8].pack("C*")
escaped = ["5c", "75", "32", "30", "32", "38"].map { |x| x.to_i(16) }.pack("C*")
escapes = { sep => escaped, ">".b => "&gt;".b }
json = ("[" + '"' + sep + '",' + '"x>"' + "]").b
p json.gsub(Regexp.union(*escapes.keys), escapes), json.gsub(/\xE2\x80\xA8/n, escapes).bytes.size
bin = ("a" + sep + "b").b
p bin.gsub(/\xE2\x80\xA8/n, sep => "S"), bin.gsub(Regexp.union(sep), sep => "S"), bin.sub(/\xE2\x80\xA8/n, sep => "T")
p "a>b".gsub(/>/, ">" => "G")

# a String subclass's value, with a module prepended to String calling super
module AroundGsub
  def gsub(*a, &b) = "<" + super + ">"
  def sub(*a, &b) = "<" + super + ">"
end
String.prepend AroundGsub
class PlainSub < String; end
p try { PlainSub.new("aa").gsub("a", "b") }, try { PlainSub.new("aa").sub("a", "b") }
class BangSub < String
  def gsub(*a) = super
  def gsub!(*a) = super
  def sub!(*a) = super
end
p try { BangSub.new("aa").gsub("a", "b") }
bs = BangSub.new("aa")
p try { bs.gsub!("a", "b") }, bs, try { bs.gsub!("z", "y") }, try { bs.sub!("b", "c") }, bs

# transform_keys! through super refuses a frozen Hash subclass, and the plain
# form still answers from it
class FrozenKeys < Hash
  def transform_keys!(*a, &b) = super
  def transform_keys(*a, &b) = super
end
fk = FrozenKeys[a: 1].freeze
p try { fk.transform_keys!({ a: :b }) }, fk, try { fk.transform_keys({ a: :b }) }, fk

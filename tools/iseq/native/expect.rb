# tools/iseq/native/expect.rb -- what the native ISeq compiler has to answer
# (note 552 §11): for each file, the sequences lib/iseq_compiler_ext.rb
# compiles for the VM -- Compiler__.to_a(unit, true), as __vm_file asks --
# written as text, and Prism's serialized tree, which is the native
# compiler's input.
#
#   ruby expect.rb <lib/iseq_compiler_ext.rb> <out dir> <file.rb>...   (the reference ruby)
#
# writes <out dir>/<n>.pm and <n>.exp for the n-th file and prints a line a
# file: n, a tab, the path. A file the compiler refuses has the refusal as
# its .exp ("REFUSED: ..."); one ruby does not parse, "SYNTAX".
#
# The text is one both sides can write from what they hold, and a line an
# instruction so a diff reads:
#
#   nil true false 12 -3        themselves
#   a Float                     f and its 16 hex digits
#   a Symbol                    :name, with @ENCODING unless US-ASCII
#   a String                    "bytes"@ENCODING
#   a Regexp                    /source/options@ENCODING -- what its maker is
#                               handed: the source's bytes and encoding, the
#                               options' number
#   a Range                     (a..b) (a...b)
#   a Rational, a Complex       (r n d) (c re im)
#   a class, an Encoding        <Object> <enc UTF-8>
#   an Array, a Hash            [a b] {k=>v k=>v}
#   a sequence                  (seq, its nine heads a line each, its body
#                               an item a line, and ) -- indented by depth
#
# and in a name or a string a byte outside 0x20..0x7e, a `"` and a `\` are
# written \xHH.
require "prism"
require File.expand_path(ARGV.shift)
C = RubyVM::InstructionSequence::Compiler__
out = ARGV.shift

# A Regexp literal is written as what its maker is handed -- the source in
# its encoding and the options -- not as the Regexp ruby makes of them: what
# encoding and options that ends up with is the maker's business
# (Regexp.__rx_new under mere-ruby), and the native compiler hands it the
# same three.
RxIn = Struct.new(:src, :o)
# (`class << C`: the compiler has a function of its own named singleton_class)
class << C
  prepend(Module.new do
    def literal_regexp(src, o, enc)
      RxIn.new(src.dup, o | (enc == "n" ? Regexp::NOENCODING : enc.empty? ? 0 : Regexp::FIXEDENCODING)).freeze
    end
  end)
end

def esc(s) = s.b.gsub(/[^\x20-\x7e]|["\\]/n) { |c| format("\\x%02X", c.ord) }

def canon(v, ind)
  case v
  when nil then "nil"
  when true then "true"
  when false then "false"
  when Integer then v.to_s
  when Float then "f" + [v].pack("G").unpack1("H*")
  when Symbol then ":" + esc(v.to_s) + (v.encoding == Encoding::US_ASCII ? "" : "@" + v.encoding.name)
  when String then "\"" + esc(v) + "\"@" + v.encoding.name
  when RxIn then "/" + esc(v.src) + "/" + v.o.to_s + "@" + v.src.encoding.name
  when Regexp then "?Regexp"
  when Range then "(" + canon(v.begin, ind) + (v.exclude_end? ? "..." : "..") + canon(v.end, ind) + ")"
  when Rational then "(r " + canon(v.numerator, ind) + " " + canon(v.denominator, ind) + ")"
  when Complex then "(c " + canon(v.real, ind) + " " + canon(v.imaginary, ind) + ")"
  when Encoding then "<enc " + v.name + ">"
  when Module then "<" + v.name.to_s + ">"
  when Hash then "{" + v.map { |k, x| canon(k, ind) + "=>" + canon(x, ind) }.join(" ") + "}"
  when Array
    if v[0].is_a?(String) && v[0].start_with?("YARVInstructionSequence")
      pad = " " * (ind + 1)
      s = +"(seq\n"
      # (the label and the two paths as their bytes: which encoding a label
      #  string happens to be in is nothing a program is told)
      (4..12).each { |i| s << pad << ((5..7).include?(i) ? "\"" + esc(v[i]) + "\"" : canon(v[i], ind + 1)) << "\n" }
      v[13].each { |x| s << pad << " " << canon(x, ind + 2) << "\n" }
      s << " " * ind << ")"
    # (toregexp's note for the VM -- the flags and which pieces are literal --
    #  as its bytes: its encoding is whatever the join left it in)
    elsif v[0] == :toregexp && v.last.is_a?(String)
      "[" + v[0..-2].map { |x| canon(x, ind) }.join(" ") + " \"" + esc(v.last) + "\"]"
    else
      "[" + v.map { |x| canon(x, ind) }.join(" ") + "]"
    end
  else "?" + v.class.name
  end
end

ARGV.each_with_index do |f, n|
  src = File.binread(f).force_encoding(Encoding::UTF_8)
  File.binwrite(File.join(out, "#{n}.pm"), Prism.dump(src, filepath: f, line: 1))
  text =
    begin
      RubyVM::InstructionSequence.compile(src, f, f, 1)
      u = C.compile(src, f, f, 1, "<main>".encode(Encoding::US_ASCII), { vm_file: true, coverage_branches: false })
      canon(C.to_a(u, true), 0) + "\n"
    rescue SyntaxError
      "SYNTAX\n"
    rescue NotImplementedError => e
      "REFUSED: #{e.message.sub(/\ARubyVM::InstructionSequence: /, "")}\n"
    rescue Exception => e
      # (the Ruby compiler itself failing: a defect of its own, not the
      #  native one's -- check.sh lists these)
      "RUBYFAILED: #{e.class}: #{e.message.lines.first.to_s.chomp[0, 160]}\n"
    end
  File.binwrite(File.join(out, "#{n}.exp"), text)
  puts "#{n}\t#{f}"
end

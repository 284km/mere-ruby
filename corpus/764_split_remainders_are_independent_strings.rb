# Unsplit remainders keep fresh Ruby identities even when bytes can be shared.
["", "a", "a=b=c", "=a=", "a::b::c::", "\0\0=\0", "é=日本"].each do |source|
  ["=", "::", "absent"].each do |separator|
    [-2, -1, 0, 1, 2, 3, 5].each do |limit|
      p [source, separator, limit, source.split(separator, limit)]
    end
  end
end
[/absent/, /[&;] */n, /(x)/, /(?=b)/, /()/, //].each do |separator|
  ["abc", "xaxb", "é日本", "\0" * 4096].each do |source|
    [-1, 0, 1, 2, 3].each do |limit|
      values = source.split(separator, limit)
      p [separator.source, source.bytesize, limit, values.map { |v| [v.bytesize, v.encoding.name] }]
    end
  end
end
["absent", /absent/, /[&;] */n].each do |separator|
  source = "日本\0".freeze
  part = source.split(separator, 4).first
  p [part == source, part.equal?(source), part.frozen?, part.class, part.encoding]
  part.replace("changed")
  p [source, part]
  mutable = "source\0"
  part = mutable.split(separator, 4).first
  mutable.replace("owner changed")
  GC.start
  p [mutable, part]
  part.replace("part changed")
  p [mutable, part]
end
class SplitRemainderSubclass < String; end
source = SplitRemainderSubclass.new("abc").freeze
p [source.split("=", 2).first.class, source.split(/=/, 2).first.class]
source = "abc".encode(Encoding::ISO_8859_1)
part = source.split("=", 2).first
part.force_encoding(Encoding::ASCII_8BIT)
p [source.encoding, part.encoding, source]
/b/ =~ "abc"
before = $~
"no separators".split(/=/, 2)
p [before.class, $~.nil?]

# StringIO whole-buffer reads go through byteslice; sharing bytes must leave
# the returned String mutable and independent in content and encoding.
require "stringio"
["", "é\0日本".encode(Encoding::UTF_8), "\xFF\0".b].each do |source|
  [proc { |s| s.byteslice(0, s.bytesize) },
   proc { |s| s.byteslice(0, s.bytesize + 100) },
   proc { |s| s.byteslice(0..-1) },
   proc { |s| s.byteslice(0..100) },
   proc { |s| StringIO.new(s).read }].each do |read|
    original = source.dup.freeze
    result = read.call(original)
    p [result == original, result.equal?(original), result.frozen?, result.encoding]
    result.replace("changed")
    p [original.bytes, result]
  end
end

# What a MatchData knows about the match it came from. Ruby 3.4 settled most of
# this surface (byteoffset, match, match_length, deconstruct_keys), and a
# pattern with NAMED groups is the case that catches an implementation out: a
# plain paren beside a named one does not capture at all.

m  = "hello world".match(/(l+)(o)/)
mn = "hello world".match(/(?<a>w)(o)/)
mo = "hello world".match(/(x)?(o)/)

p m.to_a, m.captures, m.size, m.regexp, m.string, m.pre_match, m.post_match
p mn.to_a, mn.captures, mn.size, mn.names, mn.named_captures
p mn[1], mn[2], mn[:a], mn["a"], mn.values_at(0, 1, 2)

# spans: characters, bytes, and the group that did not participate
p m.begin(0), m.end(1), m.offset(1), m.byteoffset(1), m.bytebegin(1), m.byteend(1)
p mo.begin(1), mo.end(1), mo.offset(1), mo.byteoffset(1)
p m.match(0), m.match(1), mo.match(1), m.match_length(1), mo.match_length(1)
mu = "héllo".match(/(é)(l)/)
p mu.offset(1), mu.byteoffset(1), mu.begin(1), mu.bytebegin(1), mu.byteend(1)

# an index out of range is a refusal, and so is one that cannot convert
[-> { m.begin(9) }, -> { m.match(9) }, -> { m.byteoffset(9) }, -> { mn.begin(2) },
 -> { m.offset([]) }, -> { mn[:zz] }, -> { mn.begin(:zz) }].each do |f|
  begin
    f.call
  rescue IndexError, TypeError => e
    puts e.class.to_s + ": " + e.message
  end
end
class ToInt
  def to_int; 1; end
end
p m.begin(ToInt.new), m.byteoffset(1r), m.offset(1r)

# equality is "the same match", not identity, and a copy is equal to its source
p m == "hello world".match(/(l+)(o)/), m == mn, m == 1, m.eql?(m.dup)
p m.hash == "hello world".match(/(l+)(o)/).hash, m.dup.to_a, m.clone.captures
p m.string.equal?(m.string), m.string.frozen?

# deconstruct / deconstruct_keys, as a pattern match uses them
p m.deconstruct
p mn.deconstruct_keys(nil), mn.deconstruct_keys([:a]), mn.deconstruct_keys([])
p(/(?<f>foo)(?<b>bar)(?<c>baz)/.match("foobarbaz").deconstruct_keys([:f, :zz, :b]))
p(/(?<f>foo)(?<b>bar)/.match("foobar").deconstruct_keys([:f, :zz, :b]))
begin
  mn.deconstruct_keys(1)
rescue TypeError => e
  puts e.message
end
begin
  mn.deconstruct_keys(["a"])
rescue TypeError => e
  puts e.message
end
case "hello world"
in /(?<a>w)/ => matched
  p matched
end

# the same name twice: listed once, and the FARTHEST one that matched answers
md = "haystack".match(/(?<hay>hay)(?<dot>.)(?<hay>tack)/)
p md.names, md.to_a, md[:hay], md.named_captures, md.begin("hay"), md.end("hay")
p "foo".match(/(?<x>f)|(?<x>o)/)[:x]

# a Regexp knows its names too, and a match agrees with its pattern
p(/(?<a>x)(?<b>y)/.names, /x/.names, /(?<a>x)/.named_captures, /(?<a>x)(?<a>y)/.named_captures)
p md.names == md.regexp.names

# values_at takes indices, names and whole Ranges, mixed
mv = /(.)(.)(\d+)(\d)/.match("THX1138: The Movie")
p mv.values_at(0, 1, 5), mv.values_at(0..2), mv.values_at(0..5), mv.values_at(1..2, 2..3), mv.values_at(0, 1..2)
begin
  mv.values_at(-6..3)
rescue RangeError => e
  puts e.message
end

# a codepoint escape is a pattern this engine can read
p(/\Aあ(.)(.)?(.)\z/.match("あぃい").to_a)
p("aあb" =~ /\u{3042}/)
p("abc" =~ /\u{61 62}/)
p("aあb" =~ /あ/)

# ...and a MatchData is made by matching, never by the program
[-> { MatchData.new }, -> { MatchData.allocate }].each do |f|
  begin
    f.call
  rescue NoMethodError => e
    puts e.message
  end
end
p m.inspect, mn.inspect, m.to_s
p MatchData.instance_method(:deconstruct) == MatchData.instance_method(:captures)
p MatchData.instance_method(:length) == MatchData.instance_method(:size)
p m.respond_to?(:captures), m.respond_to?(:byteoffset), m.respond_to?(:nope)

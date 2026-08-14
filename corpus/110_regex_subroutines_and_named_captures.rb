# A possessive quantifier is the greedy one that never gives back what it
# took -- which is exactly an atomic group, and this engine already had those.
p [("aaa" =~ /\Aa*+\z/), ("aaa" =~ /\Aa++\z/), ("a" =~ /\Aa?+\z/)]
p ("aaa" =~ /\Aa*+a\z/)          # nil: the a*+ keeps all three
p ("aaa" =~ /\Aa*a\z/)           # 0: the greedy one gives one back
p ("aaab" =~ /a*+b/)
p "x1y22z".scan(/\d++/)

# \k<name> is a backreference by name; \g<name> re-matches that group's
# pattern here (a subroutine call). Ruby's own URI pattern defines its pieces
# with `(?<x>...){0}` and calls them.
p(/(?<s>a)\k<s>/ =~ "aa")
p(/(?<s>ab){0}\g<s>\g<s>/ =~ "abab")
p(/(?<w>[a-z]+)-\g<w>/.match("foo-bar")[0])
p(/(?<q>\d)\k<q>/ =~ "77")
p(/(?<q>\d)\k<q>/ =~ "78")

# Named captures, from MatchData
m = /(?<a>x)(?<b>y)/.match("xy")
p [m[:a], m[:b], m["a"], m[1], m[2]]
p m.named_captures
p m.names
p(/(?<hier-part>z)/.match("z")[:"hier-part"])
begin
  m[:nope]
rescue IndexError => e
  p e.class
end

# ...and more than nine groups, which is all ruby exposes as $1..$9 but not
# all a MatchData holds.
big = /(?<g1>a)(?<g2>b)(?<g3>c)(?<g4>d)(?<g5>e)(?<g6>f)(?<g7>g)(?<g8>h)(?<g9>i)(?<g10>j)(?<g11>k)(?<g12>l)/
mb = big.match("abcdefghijkl")
p [mb[10], mb[11], mb[12], mb[:g12]]
p mb.names.size
p mb.captures.size

# The whole point is ruby's own RFC3986 URI pattern, which needs every feature
# above at once. It lives in the CRuby stdlib, so it cannot be required from a
# self-contained corpus program -- this is the shape of it, inline.
RFC3986 = /\A(?<seg>(?:%\h\h|[!$&-.0-9:;=@A-Z_a-z~\/])){0}
  (?<URI>(?<scheme>[A-Za-z][+\-.0-9A-Za-z]*+):
    (?<hier>\/\/(?<authority>(?:(?<userinfo>(?:%\h\h|[!$&-.0-9:;=A-Z_a-z~])*+)@)?
      (?<host>[!$&-.0-9;=A-Z_a-z~]*+)(?::(?<port>\d*+))?)
      (?<path>(?:\/\g<seg>*+)*+))
    (?:\?(?<query>\g<seg>*+))?(?:\#(?<fragment>\g<seg>*+))?)\z/x
m = RFC3986.match("https://user:pw@example.com:8080/a/b?q=1&r=2")
p [m[:scheme], m[:userinfo], m[:host], m[:port], m[:path], m[:query]]
p RFC3986.match("http://foo/bar").values_at(:scheme, :host, :path)
p RFC3986.match("not a uri").nil?

# the socket errnos exist, and EWOULDBLOCK IS EAGAIN here
p [Errno::EINPROGRESS.ancestors.include?(SystemCallError), Errno::EWOULDBLOCK.name]

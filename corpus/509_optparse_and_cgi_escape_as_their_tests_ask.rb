# What test/optparse (ruby's own optparse.rb running here) and test/cgi
# found (note 511's stage 3). Four holes, none of them optparse's:
# a splat of an Enumerator spread as [the Enumerator] (optparse's separator
# lines, `[*opt.each_line]`); `H === H.new` was false for `class H < Hash`
# (its CompletingHash pattern), and `H.new.method(:conv)` for a module
# the subclass includes had no owner and re-dispatched on a Hash; an IO
# given a singleton method stopped answering its builtins, so
# `$stdout = io` refused it (the help pager). cgi/escape is ruby's own
# lib/cgi/escape.rb now (lib/cgi_escape_ext.rb), the C extension's
# LoadError rescued by the file itself.
require "cgi/escape"
require "stringio"

def f(*a) = a
e = "a\nb".each_line
p [*e], f(*[1, 2].each), [*nil], [*(1..2)], [*{a: 1}], [*Struct.new(:x).new(1)]
p [*Object.new].size

module Conv
  def convert(opt = nil, val = nil, *)
    [:conv, opt, val]
  end
end
class CHash < Hash
  include Conv
end
h = CHash.new
h["aa"] = "AA"
p CHash === h, Hash === h, h.is_a?(CHash), (case h when CHash then :sub when Hash then :hash end)
p h.method(:convert).owner, h.method(:convert).call(1, 2), h.method(:convert).to_proc.call(3)
C = Class.new(Array) { include Conv }
p C === C.new, C.new.method(:convert).call
class SArr < Array
  def own = :own
end
p SArr === SArr.new, SArr.new.method(:own).owner, SArr.new.method(:own).call

s = StringIO.new
def s.tty? = true
p s.respond_to?(:write), s.respond_to?(:tty?), s.singleton_methods
io = $stdout.dup
def io.tty? = true
p io.respond_to?(:write), io.respond_to?(:puts), io.respond_to?(:zzz)
old = $stdout
$stdout = io
puts "through the dup"
$stdout = old
io.close
begin
  $stdout = Object.new
rescue TypeError => e
  p e.class
end
p Encoding.list { |e| }.size == Encoding.list.size, String.name { }

p CGI.escapeHTML(%q{Usage: foo "bar" <baz> & 'q'}), CGI.unescapeHTML("&quot;&lt;&gt;&amp;&#39;&apos;&#65;&#x42;&#x1F363;")
p CGI.escape("'Stop!' said Fred"), CGI.unescape("%27Stop%21%27+said+Fred"), CGI.escapeURIComponent("'Stop!' said Fred"), CGI.unescapeURIComponent("%27Stop%21%27+said%20Fred")
p CGI.escape_html("<"), CGI.h("<"), CGI.unescape_html("&lt;"), CGI.escape_uri_component("a b"), CGI.unescape_uri_component("a%20b")
p CGI.escapeElement('<BR><A HREF="url"></A>', "A", "IMG"), CGI.unescapeElement(CGI.escapeHTML('<BR><A HREF="url"></A>'), ["A", "IMG"])
p CGI.escapeHTML("\xE3\x81\x82".b).encoding, CGI.escapeHTML("a<b".encode("US-ASCII")).encoding, CGI.unescapeHTML("&#12354;").encoding, CGI.unescapeHTML("&#12354;")
p CGI.unescapeHTML("&#255;".encode("ISO-8859-1")).bytes, CGI.unescapeHTML("&#256;".encode("ISO-8859-1")), CGI.unescapeHTML("&#1114112;"), CGI.unescapeHTML("&#55296;").bytes
p CGI::Escape.instance_methods.sort.first(6), CGI.singleton_class.include?(CGI::Escape), CGI.include?(CGI::Escape)
class Esc; include CGI::Escape; end
p Esc.new.escapeHTML("<"), Esc.new.unescape("a+b")

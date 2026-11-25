# cgi/escape is ruby's C extension (ext/cgi/escape) linked into mere-ruby:
# lib/cgi/escape.rb requires 'cgi/escape.so', whose CGI::EscapeExt is C,
# prepended to CGI::Escape and extended onto CGI, and the file aliases its
# methods there. So the methods are C (source_location nil), they answer as
# escape.c does, and $LOADED_FEATURES has the extension and the .rb, once
# each, as ruby lists them.
p require('cgi/escape')
p require('cgi/escape.so')
p require('cgi/escape')
m = CGI.method(:escapeHTML)
p [m.owner, m.source_location]
p CGI::EscapeExt.instance_methods(false).sort
p CGI::Escape.ancestors.take(2)
p CGI.method(:h).owner
p CGI.escapeHTML(%q(<a href='x'>&"</a>))
p CGI.escapeHTML("plain")
p CGI.unescapeHTML("&lt;&#x41;&#66;&amp;&quot;&#39;&gt;&unknown;&#xZZ;")
p CGI.escape("a b&c/é~")
p CGI.unescape("a+b%26c%2F%C3%A9")
p CGI.unescape("%E3%81%82", "ASCII-8BIT").encoding
p CGI.escapeURIComponent("a b+c")
p CGI.unescapeURIComponent("a+b%20c")
p (CGI.escapeHTML(nil) rescue [$!.class, $!.message])
p (CGI.escapeURIComponent(1) rescue [$!.class, $!.message])
o = Object.new
def o.to_str = "<x>"
p CGI.escapeHTML(o)
u = CGI.escapeHTML("<é>".encode("UTF-16LE"))
p [u.encoding, u.encode("UTF-8")]
p CGI.unescapeHTML("&lt;b&gt;".b).encoding
class Esc918; include CGI::Escape; def go = escapeHTML("<1>"); end
p Esc918.new.go
p $LOADED_FEATURES.grep(%r{/cgi/escape\.}).map { |f| File.extname(f) == '.rb' ? :rb : :ext }

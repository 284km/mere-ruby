# erb/escape is ruby's C extension (ext/erb/escape), linked into mere-ruby:
# ERB::Escape.html_escape is C, so source_location is nil, and it answers as
# escape.c does -- the same String back when there is nothing to escape, #to_s
# of a non-String, CGI.escapeHTML for an ASCII-incompatible one.
p require('erb/escape')
p require('erb/escape')
p ERB::Escape.method(:html_escape).source_location
p ERB::Escape.html_escape("<a href='x'>&\"</a>")
s = +"nothing to escape"
p ERB::Escape.html_escape(s).equal?(s)
p ERB::Escape.html_escape(123)
p ERB::Escape.html_escape(:"<sym>")
p ERB::Escape.html_escape("<b>".b).encoding
p ERB::Escape.html_escape("<é>").encoding
require 'cgi/escape'
u = "<é>".encode("UTF-16LE")
r = ERB::Escape.html_escape(u)
p [r.encoding, r.encode("UTF-8")]
p $LOADED_FEATURES.count { |f| f.end_with?("erb/escape.bundle", "erb/escape.so") }
p $LOAD_PATH.resolve_feature_path('erb/escape')&.first
class Esc914; include ERB::Escape; def go = html_escape("<1>"); end
p (Esc914.new.go rescue $!.class)
p ERB::Escape.respond_to?(:html_escape)

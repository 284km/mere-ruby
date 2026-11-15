# Three gems with C extensions, as their users call them. The same script
# runs on both rubies, each with the gems its own `gem install` built
# (tools/capi_gem_check.py), and must print the same.
require 'fast_blank'
p ["", "  \t\n", " a ", "　"].map(&:blank_as?)
require 'redcarpet'
md = Redcarpet::Markdown.new(Redcarpet::Render::HTML.new(with_toc_data: true), tables: true, fenced_code_blocks: true, autolink: true)
puts md.render("# Title\n\nHello *world* and **bold** http://example.com\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\n```ruby\nputs 1\n```\n")
class Custom < Redcarpet::Render::Base
  def paragraph(text) = "<P>#{text.upcase}</P>\n"
  def emphasis(text) = "[#{text}]"
end
puts Redcarpet::Markdown.new(Custom).render("one *two* three\n\nfour")
require 'msgpack'
data = { "a" => [1, 2.5, nil, true, "str", :sym.to_s, 2**40, -3, { "n" => [] }], "bin" => "\xff\x00".b, "big" => 2**63 }
packed = MessagePack.pack(data)
p packed.bytesize, packed.encoding
p MessagePack.unpack(packed) == data
# (bytes and encoding, not the String's inspect: how that is written depends
#  on the locale the reference was started in)
back = MessagePack.unpack(MessagePack.pack([1.5, "日本語", [[]], {}]))
p back[0], back[1].encoding, back[1].bytes, back[2], back[3]
u = MessagePack::Unpacker.new
u.feed_each(MessagePack.pack(1) + MessagePack.pack("two") + MessagePack.pack([3])) { |o| p o }
pk = MessagePack::Packer.new
pk.write_array_header(2).write(1).write("x")
p pk.to_s
begin
  MessagePack.unpack("\xc1")
rescue => e
  p e.class
end

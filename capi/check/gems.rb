# Gems with C extensions, as their users call them. The same script
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

# racc: the parser runtime is the C one when its extension loaded
require 'racc/parser'
p Racc::Parser::Racc_Runtime_Core_Version_C == Racc::Parser::Racc_Runtime_Core_Version, Racc::Parser::Racc_Runtime_Type

# nokogiri, on the system's libxml2
require 'nokogiri'
html = Nokogiri::HTML('<html><body><div id="a" class="x y"><p>Hello <b>world</b></p><a href="/one">1</a><a href="/two">2</a></div></body></html>')
p html.css('a').map { |a| [a['href'], a.text] }
p html.at_css('#a')['class'], html.at_css('p').text, html.xpath('//b').first.name
node = html.at_css('p')
node.content = 'changed & escaped'
node['data-k'] = 'v'
puts html.at_css('div').to_html
xml = Nokogiri::XML('<root xmlns:n="urn:x"><n:item id="1">one</n:item><n:item id="2">two</n:item><plain/></root>')
p xml.root.name, xml.xpath('//n:item', 'n' => 'urn:x').map { |i| [i['id'], i.text] }
p xml.errors.size, xml.root.children.select(&:element?).map(&:name)
built = Nokogiri::XML::Builder.new { |x| x.list { x.entry('a', n: 1); x.entry('b', n: 2) } }
puts built.to_xml
bad = Nokogiri::XML('<a><b></a>')
p bad.errors.map(&:class).uniq, bad.errors.size > 0
begin
  Nokogiri::XML('<a><b></a>') { |config| config.strict }
rescue => e
  p e.class
end
fragment = Nokogiri::HTML::DocumentFragment.parse('<i>x</i><u>y</u>')
p fragment.children.map(&:name), fragment.to_html
p html.css('a').first.ancestors.map(&:name)
handler = Class.new(Nokogiri::XML::SAX::Document) do
  attr_reader :seen
  def initialize = @seen = []
  def start_element(name, attrs = []) = @seen << name
end.new
Nokogiri::XML::SAX::Parser.new(handler).parse('<r><x/><y><z/></y></r>')
p handler.seen

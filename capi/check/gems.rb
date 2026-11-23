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

# bcrypt: the hash of a fixed salt, and a password checked against its own hash
require 'bcrypt'
hashed = BCrypt::Password.create('secret', cost: 4)
p hashed.class, hashed.cost, BCrypt::Password.new(hashed.to_s) == 'secret', BCrypt::Password.new(hashed.to_s) == 'wrong'
p BCrypt::Engine.hash_secret('secret', '$2a$04$abcdefghijklmnopqrstuu')

# nio4r: a selector over real descriptors (libev, through RFILE's struct)
require 'nio'
p NIO::ENGINE
selector = NIO::Selector.new
reader, writer = IO.pipe
monitor = selector.register(reader, :r)
p monitor.interests, monitor.io.equal?(reader), selector.registered?(reader), selector.empty?
p selector.select(0.01)
writer.write('ping')
ready = selector.select(1)
p ready.size, ready.first.readable?, ready.first.io.read_nonblock(4)
monitor.value = :payload
p monitor.value
selector.deregister(reader)
p selector.registered?(reader), monitor.closed?
selector.register(writer, :w)
seen = []
selector.select(1) { |m| seen << [m.writable?, m.io.equal?(writer)] }
p seen
reader.close
begin
  selector.register(reader, :r)
rescue => e
  p e.class
end
selector.close
p selector.closed?
buffer = NIO::ByteBuffer.new(16)
buffer << 'hello'
buffer.flip
p buffer.get, buffer.position, buffer.limit, buffer.capacity

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

# What Rails' own dependencies build: each from the gem home, not from a
# library the interpreter ships (the line says which file the extension is)
native = lambda do |feature|
  hit = $LOADED_FEATURES.grep(/\/#{Regexp.escape(feature)}\.(bundle|so)\z/)
  hit.size == 1 && hit[0].start_with?(ENV.fetch('GEM_HOME'))
end

# erb: its escape is C (erb/escape), and ERB::Util.html_escape is that one
gem 'erb'
require 'erb'
p native.('erb/escape')
p ERB::Util.html_escape(%q{<a href="x">&'"</a>}), ERB::Util.html_escape(nil), ERB::Util.html_escape(12)
s = +'plain'
p ERB::Util.html_escape(s).equal?(s), ERB::Util.html_escape('日本<語>').encoding
p ERB.new("<%= 1 + 2 %> <%= ERB::Util.h('<b>') %>\n<% [1, 2].each do |i| %>[<%= i %>]<% end %>\n", trim_mode: '-').result(binding)

# rbs: its parser is C (rbs_extension) and builds Ruby AST objects
gem 'rbs'
require 'rbs'
p native.('rbs_extension')
_, _, decls = RBS::Parser.parse_signature(<<~RBS)
  module M
    def m: (Integer, ?String) -> Array[Symbol]
  end
  class C < Object
    attr_reader name: String
    def initialize: (name: String) -> void
    def each: () { (Integer) -> void } -> self
  end
RBS
p decls.map { |d| [d.class.name, d.name.to_s, d.members.map { |m| m.class.name.split('::').last }] }
p RBS::Parser.parse_type('Hash[Symbol, Integer | nil]').to_s, RBS::Parser.parse_method_type('(untyped) -> bool').to_s
begin
  RBS::Parser.parse_type('Array[')
rescue => e
  p e.class
end

# websocket-driver: the frame mask is C (websocket_mask)
gem 'websocket-driver'
require 'websocket/driver'
p native.('websocket_mask')
masked = WebSocket::Mask.mask("Hello, \x00\xff".b, [1, 2, 3, 4].pack('C*'))
p masked.bytes, WebSocket::Mask.mask(masked, [1, 2, 3, 4].pack('C*'))
p WebSocket::Mask.mask('abc', nil)

# puma: the HTTP request parser is C (puma_http11)
gem 'puma'
require 'puma'
require 'puma/puma_http11'
p native.('puma/puma_http11')
parser = Puma::HttpParser.new
env = {}
request = "GET /path/x?q=1&r=%20 HTTP/1.1\r\nHost: example.com\r\nX-Custom: a b\r\nContent-Length: 3\r\n\r\nabc"
done = parser.execute(env, request, 0)
p done, parser.finished?, parser.nread, parser.error?
p env.slice('REQUEST_METHOD', 'REQUEST_PATH', 'QUERY_STRING', 'SERVER_PROTOCOL', 'HTTP_HOST', 'HTTP_X_CUSTOM', 'CONTENT_LENGTH').sort
p parser.body, parser.body.encoding
bad = Puma::HttpParser.new
begin
  bad.execute({}, "GET / HTTP/1.1\r\nBad Header\r\n\r\n", 0)
rescue => e
  p e.class
end

# sqlite3: the database is C (sqlite3_native) on the system's SQLite, with
# callbacks into Ruby
gem 'sqlite3'
require 'sqlite3'
p native.('sqlite3/sqlite3_native')
db = SQLite3::Database.new(':memory:')
db.execute('CREATE TABLE t (id INTEGER PRIMARY KEY, name TEXT, score REAL, data BLOB)')
db.execute('INSERT INTO t (name, score, data) VALUES (?, ?, ?)', ['ann', 1.5, SQLite3::Blob.new("\x00\x01\xff")])
stmt = db.prepare('INSERT INTO t (name, score) VALUES (:name, :score)')
%w[bob cid].each_with_index { |n, i| stmt.execute(name: n, score: i * 10) }
stmt.close
p db.last_insert_row_id, db.changes, db.total_changes
p db.execute('SELECT id, name, score FROM t ORDER BY id')
row = db.get_first_row('SELECT data FROM t WHERE id = 1')
p row[0].bytes, row[0].encoding
db.results_as_hash = true
p db.execute('SELECT name FROM t WHERE score > ?', 5).map { |h| h['name'] }
db.results_as_hash = false
db.create_function('twice', 1) { |f, x| f.result = x.to_i * 2 }
p db.get_first_value('SELECT twice(21)')
db.transaction do
  db.execute("UPDATE t SET name = 'zed' WHERE id = 2")
  raise SQLite3::Exception, 'roll back' rescue nil
end
p db.get_first_value('SELECT name FROM t WHERE id = 2')
begin
  db.transaction do
    db.execute("UPDATE t SET name = 'gone' WHERE id = 3")
    raise ArgumentError, 'abort'
  end
rescue ArgumentError
end
p db.get_first_value('SELECT name FROM t WHERE id = 3')
begin
  db.execute('SELECT * FROM missing')
rescue SQLite3::SQLException => e
  p e.class, e.message
end
p db.prepare('SELECT ?1 + ?2').execute(1, 2).to_a
db.close
p db.closed?

# The default gems Rails' lock pins newer than the interpreter ships: an
# activated gem's own extension is the one loaded (issue #127, PR #128)

# json: the C parser and generator
gem 'json'
require 'json'
p native.('json/ext/parser'), native.('json/ext/generator'), JSON::VERSION
p JSON::Parser.name, JSON.generate({ "b" => [1, 2.5, nil, true], "a" => "é\u0001" })
p JSON.parse('{"x": [1, {"y": "z"}], "n": 1e3, "big": 12345678901234567890}')
p JSON.parse('{"a": 1}', symbolize_names: true), JSON.pretty_generate([1, { "k" => [] }])
p JSON.generate({ "b" => 1, "a" => 2 }, sort_keys: true) rescue p $!.class
begin
  JSON.parse('{"a": }')
rescue JSON::ParserError => e
  p e.class
end

# date: date_core
gem 'date'
require 'date'
p native.('date_core'), Date::VERSION
d = Date.new(2024, 2, 29)
p d.to_s, d.leap?, d.jd, (d >> 12).to_s, d.strftime('%a %j %U'), d.cwday
p Date.parse('2026-11-22T10:00:00').to_s, Date._parse('Mar 3 2001').sort
p DateTime.new(2001, 2, 3, 4, 5, 6, '+07:00').iso8601, Date.valid_date?(2023, 2, 29)
begin
  Date.new(2023, 2, 30)
rescue Date::Error => e
  p e.class
end

# bigdecimal
gem 'bigdecimal'
require 'bigdecimal'
require 'bigdecimal/util'
p native.('bigdecimal'), BigDecimal::VERSION
a = BigDecimal('1.1'); b = BigDecimal('2.2')
p (a + b).to_s, (a * b).to_s('F'), (BigDecimal('1') / 3).round(20).to_s, BigDecimal('2').sqrt(20).to_s
p BigDecimal('123.456').round(1, BigDecimal::ROUND_HALF_EVEN).to_s, BigDecimal('NaN').nan?, '3.14'.to_d.class
p BigDecimal('1e-20').exponent, BigDecimal('-0').sign

# io-console: on a pipe, which is no terminal
gem 'io-console'
require 'io/console'
p native.('io/console'), IO.respond_to?(:console)
# (oflush reaches rb_io_get_write_io: on a duplex pipe, which is no terminal)
duplex = IO.popen(['cat'], 'r+')
p((duplex.oflush rescue $!.class))
# (...and after close_read, on the write descriptor: still no terminal, and
#  beep writes nowhere else -- not on a file that got the read one's number)
duplex.close_read
victim = File.open(File::NULL)
p((duplex.oflush rescue $!.class), (duplex.beep.equal?(duplex) rescue $!.class))
victim.close
duplex.close
r, w = IO.pipe
begin
  r.winsize
rescue => e
  p e.class
end
p r.respond_to?(:raw), r.respond_to?(:getch)
r.close; w.close

# prism: the parser as a gem
gem 'prism'
require 'prism'
p native.('prism/prism'), Prism::VERSION
res = Prism.parse("def m(a, b = 1) = a + b\nm(1)")
p res.success?, res.value.class, res.value.statements.body.map { |n| n.class.name.split('::').last }
p Prism.parse('1 +').errors.map { |e| e.class.name.split('::').last }.uniq, Prism.lex('a = 1').value.map { |t, _| t.type }.first(3)

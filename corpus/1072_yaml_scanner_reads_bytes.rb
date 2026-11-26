# The embedded YAML parser reads the source by BYTES: the syntax of YAML is
# ASCII, and what a token holds is cut from the source by byte position. So a
# multibyte character is never split or re-encoded -- in a key, a value, a
# comment, a quoted or block scalar, an anchor or a tag -- and a mark (line,
# column) still counts characters.
require "yaml"

def show(label, text, **opts)
  v = YAML.safe_load(text, aliases: true, permitted_classes: [Symbol], **opts)
  p [label, v]
  walk = ->(x) {
    case x
    when String then p [x, x.encoding.to_s, x.valid_encoding?, x.frozen?]
    when Array then x.each(&walk)
    when Hash then x.each { |k, w| walk.(k); walk.(w) }
    end
  }
  walk.(v)
rescue Psych::SyntaxError => e
  p [label, e.class, e.line, e.column, e.problem, e.context]
end

show "plain", "名前: 山田 太郎\n絵文字: 🍣🍺\n結合: e\u0301t\u00e9\n"
show "comment", "# コメント 🍣\nkey: 値 # 後ろのコメント 🍺\n"
show "quoted", "a: '日本 ''語'''\nb: \"改\\n行 \\u3042 🍣\"\nc: \"\\x41\\u00e9\"\n"
show "block", "lit: |\n  一行目 🍣\n  二行目\nfold: >-\n  折り\n  たたみ\n"
show "flow", "{鍵: [値, '値2', 🍣], 二: {三: 四}}\n"
show "anchor", "a: &錨 アンカー\nb: *錨\nc: &x [1, 2]\nd: *x\n"
show "tag", "a: !!str 123\nb: !!int '42'\n"
show "seq", "- あ\n- い: う\n  え: お\n- [か, き]\n"
show "multiline plain", "a: 一行目\n  続き 🍣\n\n  段落\n"

# marks: the line and column of an error, after multibyte characters
show "err after kana", "あいう: [1, 2\nえお: 3\n"
show "err tab", "a:\n\tb: 1\n"
show "err quote", "a: \"開いたまま\n"
show "err anchor", "a: & \n"
show "err anchor name", "a: &錨 v\n"
show "err alias name", "a: *錨\n"
show "err reserved", "- &a%b c\n"

# encodings: UTF-16 with and without a BOM, a UTF-8 BOM
u16le = "名前: 🍣\nb: [1, 二]\n".encode("UTF-16LE")
show "utf16le", u16le
show "utf16le bom", "\uFEFFa: あ\n".encode("UTF-16LE")
show "utf16be bom", "\uFEFFa: あ\n".encode("UTF-16BE")
show "utf8 bom", "\uFEFF鍵: 値\n"
show "utf8 bom binary", "\uFEFF鍵: 値\n".b

# line ends and blanks: CRLF, tabs inside a line, trailing blanks
show "crlf", "a: 1\r\nb: 二\r\nc:\r\n  - x\r\n  - y \r\n"
show "tabs", "a:\t値\nb: [1,\t2]\nc: \"\tq\t\"\n"
show "trailing", "a: 値   \nb: 'q'   \nc: x \t \n"
show "crlf block", "a: |\r\n  行\r\n  二\r\n"

# events with their marks, through a handler
class Marks < Psych::Handler
  def initialize = (@out = [])
  attr_reader :out
  def event_location(sl, sc, el, ec) = (@loc = [sl, sc, el, ec])
  def scalar(value, *) = @out << [:scalar, value, @loc]
  def start_mapping(*) = @out << [:map, @loc]
  def start_sequence(*) = @out << [:seq, @loc]
end
h = Marks.new
Psych::Parser.new(h).parse("鍵🍣: 値\n二: [あ, い]\n# 注\n三: 'う'\n")
h.out.each { |e| p e }

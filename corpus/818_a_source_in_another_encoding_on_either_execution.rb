# coding: big5
# frozen_string_literal: true
#
# A source in an encoding that is not UTF-8 runs on the ISeq VM as it runs
# on the evaluator: the native compiler takes it, and its literals carry the
# source's encoding. This file is Big5 (the characters below are Big5's
# bytes; one of them ends in 0x40, an ASCII "@"), and it requires a
# Windows-31J file (one of whose characters ends in 0x41, an "A") and an
# ASCII-8BIT one.
# (Not here: a Windows-31J character that ends in 0x5C, a backslash. The
#  evaluator's lexer reads that byte as an escape, in a string, a symbol, a
#  regexp, a heredoc and a word list, and the main script is read by it on
#  either execution.)
#
# A frozen literal is ruby's fstring whatever its encoding: one object for
# every literal of that text in that encoding, at any place in the file --
# and `"lit".freeze` and `-"lit"` are that object too.
def one = "一"
def two = "一"
p __ENCODING__
p one.encoding, one.equal?(two), one.equal?(one), one.frozen?, one.bytes
p "lit".equal?("lit"), "lit".freeze.equal?("lit".freeze), (-"lit").equal?(-"lit"), "lit".freeze.equal?(-"lit")
p "lit".freeze.encoding, (-"lit").encoding, "lit".freeze.frozen?
p "中文".freeze.equal?("中文".freeze), "中文".freeze.bytes, (-"中文").encoding
lits = Array.new(2) { "文" }
p lits[0].equal?(lits[1]), lits[0].bytes

# a Hash's literal key, a Symbol, a Regexp, a character, the words
# (not here: a Big5 character as a character literal `?x` or as a name. The
#  lexer does not know where a Big5 or a GBK character ends -- on either
#  execution -- and ruby does.)
h = {"鍵" => 1}
p h["鍵"], h.keys[0].encoding, h.keys[0].frozen?
p h.keys[0].equal?({"鍵" => 2}.keys[0]), h.keys[0].equal?("鍵"), ["鍵"][0].equal?(h.keys[0])
p :"名".encoding, :ascii.encoding, :"名".to_s.bytes, :"名".equal?(:"名")
p(/一+/.encoding, /a/.encoding, "一一x" =~ /一+x/, /一/.source.bytes)
p ?a.encoding, %w[一 a].map(&:encoding), %i[一 a].map(&:encoding), %w[一 a][0].bytes

# what is built at run time
x = 1
p "a#{one}b".encoding, "a#{one}b".frozen?, "a#{x}b".encoding, "a#{one}b".bytes
p <<~T.encoding, <<~T.bytes
  一#{x}
T
  一
T
p "ab".encoding, "ab".valid_encoding?, "\u4e00".encoding, "\xA4\x40".encoding, "\xA4\x40" == "一"
p eval("__ENCODING__"), eval('"一"').encoding

# String#freeze redefined is what "lit".freeze calls
class String
  alias c818_freeze freeze
  def freeze = :redefined
end
r = "lit".freeze
class String
  alias freeze c818_freeze
  remove_method :c818_freeze
end
p r

# files in other encodings, required
require "tmpdir"
dir = Dir.mktmpdir("c818")
sjis = "# coding: cp932\n# frozen_string_literal: true\nmodule C818Sjis\n  S = \"\u65e5\u30a2\"\n  def self.same = \"\u65e5\".equal?(\"\u65e5\")\n  def self.enc = [__ENCODING__, S.encoding, :\"\u65e5\".encoding, /\u65e5/.encoding, S.bytes]\n  def self.where = [File.basename(__FILE__), __LINE__, method(:enc).source_location[1]]\nend\n"
File.binwrite(File.join(dir, "c818_sjis.rb"), sjis.encode("Windows-31J"))
bin = "# encoding: ASCII-8BIT\nmodule C818Bin\n  B = \"\\xff\\x00z\"\n  def self.enc = [__ENCODING__, B.encoding, B.bytes, \"abc\".encoding, :abc.encoding, /a/.encoding]\nend\n"
File.binwrite(File.join(dir, "c818_bin.rb"), bin)
require File.join(dir, "c818_sjis")
require File.join(dir, "c818_bin")
p C818Sjis.enc, C818Sjis.same, C818Sjis.where
p C818Bin.enc

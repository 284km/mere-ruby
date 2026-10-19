# Encodings in patterns and literals as test_m17n and test_string ask:
# pieces read in their own encoding, raw bytes in literals, undump

def e(s) = s.dup.force_encoding("EUC-JP")
def sj(x) = x.dup.force_encoding("Windows-31J")
def u(s) = s.dup.force_encoding("UTF-8")
def bin(s) = s.dup.force_encoding("ASCII-8BIT")

def try_it
  r = yield
  p [:ok, r.is_a?(Regexp) ? r.source.bytes : r]
rescue SyntaxError => ex
  p [:SyntaxError, ex.message.lines.map(&:chomp).grep(/multibyte|differs|mixed|short/).first.to_s.sub(/\A.*?(?=(invalid|too|regexp enc|UTF-8 mixed))/, "")]
rescue => ex
  p [ex.class, ex.message]
end

# a piece of a dynamic pattern is read in its own encoding
try_it { s1, s2 = e('\xc2'), e('\xa1'); /#{s1}#{s2}/ }
try_it { s1, s2 = sj('\x81'), sj('\xa1'); /#{s1}#{s2}/ }
try_it { s1, s2 = u('\xc2'), u('\xa1'); /#{s1}#{s2}/ }
try_it { s1, s2 = bin('\xc2'), bin('\xa1'); /#{s1}#{s2}/ }
try_it { s1 = u('\xc2\xa1'); /#{s1}/ }
try_it { eval('/\x81#{ }/e') }
try_it { eval('/\x81#{ }/s') }
try_it { eval('/\xc2#{ }\xa1/u') }

# raw bytes in a pattern literal
try_it { eval("/\xfe/e") }
try_it { eval("/\xc2/u") }
try_it { eval("/\xc2 /") }
try_it { eval(bin("/\xfe/e")) }
try_it { eval(bin("/\xfe/")) }
try_it { eval("/\xc2\xa1/") }

# a \u escape beside the source's own non-ASCII bytes
try_it { eval(e(%{"\xc2\xa1\\u{6666}"})) }
try_it { eval(sj(%{"\\u{6666}\xc2\xa1"})) }
try_it { eval(bin(%{"\xc2\xa1\\u{6666}"})) }
try_it { eval(u(%{"\xc2\xa1\\u{6666}"})) }

# undump refusals, in ruby's words
['"".force_encoding()', '"".force_encoding("', '"\u3042".force_encoding("UTF-16LE")',
 '"\x00\x00".force_encoding("UTF-16LE")"', '"""', '"\udfff"', '"a"'].each do |d|
  try_it { d.undump }
end

# identifiers and labels in a Shift_JIS source
try_it { eval(sj("x\x87] = 5; x\x87] + 1")) }
try_it { h = eval(sj("{\x87]: 1}")); [h.keys[0].to_s.bytes, h.keys[0].encoding.to_s] }

# a frozen literal in a US-ASCII source is interned in that encoding
try_it { eval("# coding: us-ascii\nv = +'ABC'; h = { v => 1 }; [h.keys[0].equal?('ABC'.freeze), 'ABC'.freeze.encoding.to_s]") }

# ?X in a Windows-31J source is one character
try_it { eval(sj("# coding: windows-31j\n?\x82\xa0")).bytes }

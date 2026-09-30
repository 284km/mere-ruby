# `require "json"` is answered by the interpreter: json's own ruby files, and
# a parser and a generator in place of its two C extensions. Every answer here
# is compared byte for byte with json 2.18 under the reference.
require 'json'

def t(label)
  r = yield
  puts "#{label}: #{r.inspect}"
rescue Exception => e
  puts "#{label}: #{e.class}: #{e.message}"
end

t("version") { JSON::VERSION }
t("parse") { JSON.parse('{"a": [1, 2.5, "x", true, false, null], "b": {"c": -3e2}}') }
t("symbolize") { JSON.parse('{"a": {"b": 1}}', symbolize_names: true) }
t("freeze") { h = JSON.parse('{"a": ["x"]}', freeze: true); [h.frozen?, h["a"].frozen?, h["a"][0].frozen?] }
t("keys are frozen") { h = JSON.parse('{"a": "v"}'); [h.keys[0].frozen?, h["a"].frozen?] }
t("escapes") { JSON.parse('["\\u00e9\\u3042\\ud83d\\ude00", "\\n\\t\\"\\\\\\/"]') }
t("integers") { JSON.parse('[123456789012345678901234567890, -12345678901234567, 0, -0]') }
t("floats") { JSON.parse('[1.5, -0.0, 1e10, 1E-5, 0.1, 12345.678e-3]') }
t("allow_nan") { JSON.parse('[NaN, Infinity, -Infinity]', allow_nan: true).map(&:to_s) }
t("trailing comma") { [JSON.parse('[1,2,]', allow_trailing_comma: true), JSON.parse('{"a":1,}', allow_trailing_comma: true)] }
t("comments") { JSON.parse("[1, /* two */ 2, // three\n 3]") }
t("duplicate key") { JSON.parse('{"a":1,"a":2}') }
t("duplicate key refused") { JSON.parse('{"a":1,"a":2}', allow_duplicate_key: false) }
t("max_nesting") { JSON.parse('[[[1]]]', max_nesting: 2) }
t("load") { [JSON.load('[1, null]'), JSON.load(nil), JSON.load('')] }
t("on_load order") { r = []; JSON.load('[1, {"a": 2}]', proc { |x| r << x.class }); r }
t("errors") do
  ["[\"a\nb\"]", "[1,]", "{\"a\":1,}", "[1 2]", "nul", "[\"\\u12\"]", "{\"é\": x}", "[1] x", "", "  ",
   "[\"abc", "[-]", "01", "[1.]", "[\"\\ud800\"]", "{1:2}", "{\"a\" 1}", "[\"\\q\"]", "/* x",
   "[NaN]", "[1,\n  2,\n  xx]", "\xff"].map do |s|
    JSON.parse(s)
  rescue JSON::ParserError => e
    [e.message, e.line, e.column]
  end
end
t("generate") { JSON.generate({"a" => [1, 2.5, "x", nil, true, false], :b => {c: -3}}) }
t("escaping") { JSON.generate(["\"\\/\b\f\n\r\t\u0001\u001f", "é日本"]) }
t("ascii_only") { JSON.generate(["é日本😀", "a/b"], ascii_only: true) }
t("script_safe") { JSON.generate(["a/b\u2028\u2029é"], script_safe: true) }
t("float format") { [1e20, 1e15, 1e14, 1.5e-7, 1e-5, 1.0/3, -0.0, 2.5e100, 5e-324, 1e16, 100.0, 1.0e-7].to_json }
t("NaN refused") { JSON.generate([Float::NAN]) }
t("NaN allowed") { JSON.generate([Float::NAN, -Float::INFINITY], allow_nan: true) }
t("pretty") { JSON.pretty_generate({"a" => [1, {"b" => []}, {}], "c" => "d"}) }
t("dump") { JSON.dump({a: 1, b: [nil]}) }
t("to_json") { [1.to_json, 1.5.to_json, "x".to_json, nil.to_json, :sym.to_json, {a: 1}.to_json, (2**70).to_json] }
t("an object's to_s") { o = Object.new; def o.to_s = "OBJ"; JSON.generate([o]) }
t("an object's to_json") { c = Class.new { def to_json(*) = '{"custom":1}' }; JSON.generate([c.new]) }
t("strict") { JSON.generate([Object.new], strict: true) }
t("circular") { a = []; a << a; JSON.generate(a) }
t("malformed utf-8") { JSON.generate(["\xff"]) }
t("non-string keys") { JSON.generate({1 => 2, nil => 3, 1.5 => 4}) }
t("state") { s = JSON::State.new(indent: "  "); [s.indent, s.max_nesting, s.to_h.keys] }
t("frozen state") { begin; JSON::State.new.freeze.indent = "x"; rescue FrozenError => e; [e.class, e.receiver.class]; end }
t("fragment") { JSON.generate({n: JSON::Fragment.new(" 42")}, strict: true) }
t("coder") { c = JSON::Coder.new { |o| o.to_s }; [c.dump([1, Object]), c.load('[1]')] }
t("round trip") { h = {"k" => ["v", 1, 2.0, {"n" => nil}]}; JSON.parse(JSON.generate(h)) == h }
t("into an IO") { require 'stringio'; io = StringIO.new; JSON.dump([1], io); io.string }

# three shapes the json library and its tests are written in, and that
# mere-ruby did not read or run:
F = Struct.new(:json) do          # JSON::Fragment: an #initialize in the block, calling super
  def initialize(json)
    super(json.to_s)
  end
end
p F.new(1).json
p %{["\\u"]}, %{a\\}               # an escaped backslash in a %{} string
def pair(a, b = nil) = [a, b]
p(pair 1, l =
  2)                               # an assignment argument whose value is on the next line
class Range; def to_json(*) = "R"; end
p((1..2).respond_to?(:to_json), JSON.generate([1..2]))   # respond_to? sees Range's own methods

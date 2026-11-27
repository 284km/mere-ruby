require "ripper"
require "prism"
class EscapeLexer1128 < Ripper::Lexer
  attr_reader :messages
  def initialize(*args)
    @messages = []
    super
  end
  def on_parse_error(message)
    @messages << [:parse, message, [lineno, column], token, state]
    super
  end
  def compile_error(message)
    @messages << [:compile, message, [lineno, column], token, state]
    super
  end
end
[
  ["hex", "\"\\xU\"", 1],
  ["prefix", "\"hello\\x world", 1],
  ["multiline", "\"\nhello\\x world", 1],
  ["control", "\"\n\\Cxx\"", 1],
  ["meta", "\"\n\\Mxx\"", 1],
  ["repeat", "\"\n\\c\\cx\"", 1],
  ["unicode", "\"\n\\ux\"", 1],
  ["hex_again", "\"\n\\xx\"", 1],
  ["ctrl_mb", "\"\\C-あ\"", 1],
  ["meta_mb", "\"\\M-あ\"", 1],
  ["char_mb", "?\\C-あ", 1],
  ["offset", "\"あ\\xU\"", 41],
  ["regexp", "/\\xU/", 1],
  ["valid", "\"\\x41\"", 1],
  ["valid_escaped", "\"\\\\xU\"", 1],
  ["twice", "\"a\\x b\\x c\"", 1],
  ["char_codepoints", "?\\u{41 42}", 1],
  ["char_codepoints_many", "?\\u{0041 0042 0043}", 1],
  ["char_codepoints_space", "?\\u{41  42 }", 1],
  ["char_codepoints_offset", "'あ'; ?\\u{41 42}", 41],
  ["char_mb_arg", "p ?\\C-あ", 1],
  ["char_mb_follow", "p ?\\C-あ + 1", 1],
  ["char_unicode_arg", "p ?\\u{41 42}", 1],
  ["char_unicode_paren", "f(?\\u{41 42})", 1],
  ["char_unicode_array", "[?\\u{41 42}]", 1],
  ["char_unicode_kwarg", "f(a: ?\\u{41 42})", 1],
  ["char_unicode_follow", "p ?\\u{41 42} + 1", 41],
  ["char_meta_arg", "p ?\\M-\\C-あ", 1],
].each do |name, source, first|
  lexer = EscapeLexer1128.new(source, "escape.rb", first)
  tokens = lexer.lex.map { |pos, event, text, state| [pos, event, text, state.to_int] }
  p [name, tokens, lexer.messages]
  errors = Prism.lex(source, filepath: "escape.rb", line: first, version: "current").errors
  p [name, errors.map { |error| [error.type, error.location.start_offset, error.location.length, error.message] }]
end

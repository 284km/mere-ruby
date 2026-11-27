require 'ripper'
require 'prism'

sources = [
  "a( foo, bar: baz }",
  "}",
  "foo }",
  "1 }",
  "foo + }",
  "a(1 }",
  "a[b }",
  "foo\n}",
  "{a: 1}",
  "foo { bar }",
  "\"\#{foo}\"",
  "lambda { |x| x }",
  "{} }",
  "foo } bar",
  "{{} }",
  "a( {b:1} }",
  "a( foo, bar: baz }\n1",
]

sources.each_with_index do |source, index|
  [1, 41].each do |line|
    rows = Ripper.lex(source, "brace.rb", line).map { |pos, event, text, state| [pos, event, text, state.to_i] }
    # CRuby Lexer#parse restarts after an error. The following space/newline
    # states use that separate existing path; compare the real closer here.
    if index == 13 || index == sources.length - 1
      p [:closing, index, line, rows.find { |row| row[1] == :on_embexpr_end }]
    else
      p [:lex, index, line, rows]
    end
    result = Prism.lex(source, filepath: "brace.rb", line: line)
    p [:prism, index, line, result.value.map { |token, state|
      [token.type, token.location.start_offset, token.location.length, token.value, state]
    }, result.errors.map { |error| [error.type, error.location.start_offset, error.location.length] }]
  end
end

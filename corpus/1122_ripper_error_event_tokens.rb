require 'ripper'
{
  duplicate: 'def req(a, a) end',
  assignment: 'begin; nil = 1; end',
  alias: 'begin; alias $x $1; end',
  class_name: 'class bad; end',
  instance_parameter: 'def req(@a) end',
  label_parameter: 'def req(a?:) end'
}.each do |name, source|
  lexer = Ripper::Lexer.new(source, 'events.rb', 7)
  lexer.scan
  error = lexer.errors.first
  p [name, error.pos, error.event, error.tok, error.state.to_int, error.message]
end
lexer = Ripper::Lexer.new("<<A.upcase\n", 'events.rb', 7)
p lexer.scan.map { |e| [e.pos, e.event, e.tok, e.state.to_int, e.message] }
lexer = Ripper::Lexer.new("\ea")
seen = []
lexer.define_singleton_method(:compile_error) { |message| seen << [message, token] }
p lexer.lex.map { |pos, event, text, state| [pos, event, text, state.to_int] }
p seen
p lexer.token

["%w(\n\nw\n w w )", "%w(  \nw\n \t w)", "%W(\t\n\nあ\n b)"].each do |source|
  lexer = Ripper::Lexer.new(source, 'words.rb', 7)
  p lexer.lex.map { |pos, event, text, state| [pos, event, text, state.to_int] }
end

lexer = Ripper::Lexer.new('class bad; end')
seen = []
lexer.define_singleton_method(:on_class_name_error) do |message, element|
  seen << [message, element.pos, element.event, element.tok, element.state.to_int]
end
lexer.lex
p [seen, lexer.errors, lexer.error?]

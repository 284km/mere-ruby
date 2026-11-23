# Ripper reads a source that is neither a String nor an IO by its #to_str
# (StringValue, as the C core does): rspec's failure snippets hand
# Ripper.sexp an RSpec::Support::EncodedString, which was a TypeError, and
# Ripper.lex lexed such an object as its #to_s
require "ripper"
class Src
  def initialize(s) = @s = s
  def to_str = @s
end
class Bad; def to_str = 1; end
p Ripper.sexp(Src.new("a = 1"))
p Ripper.lex(Src.new("1+2"))
p Ripper.tokenize(Src.new("x.y"))
[Bad.new, 1, nil].each do |v|
  begin
    Ripper.sexp(v)
  rescue TypeError => e
    p e.message
  end
end

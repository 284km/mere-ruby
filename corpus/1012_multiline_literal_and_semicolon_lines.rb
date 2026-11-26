class SemicolonLines1012
  class_eval "def position; probe %(\n text\n ); after_call(:one, :two); end", 'generated1012.rb', 42
  def probe(text)
    p caller_locations(1, 1).first.lineno
  end
  def after_call(*args)
    p caller_locations(1, 1).first.lineno
  end
end
SemicolonLines1012.new.position
source = "first = \"a\nb\"; second = __LINE__; [first, second, __LINE__]"
p eval(source, nil, 'generated1012.rb', 10)

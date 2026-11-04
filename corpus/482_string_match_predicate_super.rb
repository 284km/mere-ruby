class MatchCounter < String
  attr_reader :calls
  def match?(*args)
    @calls = (@calls || 0) + 1
    super
  end
end

word = MatchCounter.new('a鳥bc鳥')
/keep/ =~ 'keep'
before = $~
p [word.match?(/鳥/), word.match?(/鳥/, 2), word.match?(/鳥/, 5)]
p [word.match?('鳥', -1), word.match?(/a/, -5), word.match?(/a/, -6)]
p [$~.equal?(before), word.calls]
position = Object.new
def position.to_int = 4
p word.match?(/鳥/, position)
begin
  word.match?(/鳥/, 'invalid')
rescue TypeError => error
  puts error.class
end

module MatchDecorator
  def match?(*args)
    super
  end
end
MatchCounter.prepend(MatchDecorator)
p [word.match?(/鳥/), word.class, word.calls]
plain = 'abc'
def plain.match?(*args) = super
p [plain.match?(/b/), plain.match?(/b/, 2)]
class MatchPattern < Regexp; end
p word.match?(MatchPattern.new('鳥'))

[[], [/a/, 0, 1]].each do |args|
  begin
    word.match?(*args)
    raise 'invalid match? arity accepted'
  rescue ArgumentError => error
    puts error.message
  end
end

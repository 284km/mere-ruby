# A heredoc's body is the lines after the line its `<<ID` is on, and the rest
# of that line is ordinary code: it may hold a second heredoc, whose body
# follows the first one's terminator, and an interpolation's code may hold one
# too -- the opening line of hundreds of CRuby tests is
# `"#{<<~"begin;"}\n#{<<~'end;'}"`.
def f(*a) = a
p f(<<~A, <<-B, <<C)
  one
A
  two
  B
three
C
x = "#{<<~"begin;"}\n#{<<~'end;'}"
begin;
  p 1 if true
  "#{2}"
end;
p x
p "a#{<<~A}b#{<<~B}c"
  in a
A
  in b
B
p [<<~A, "#{<<~B.upcase}x"]
  one
A
  two
B
# the ids may hold braces, which the interpolation's own end must not see
p "#{<<~"{#"}\n#{<<~'};'}"
{#
  body
};
# a literal that runs on past the heredoc's line goes on after the body
p "#{<<~A}
  inside
A
rest"
# a heredoc in a method chain with a block, and the line's comment
y = <<~A.lines.map { |l| l.upcase } # comment
  four
  five
A
p y
p eval("[<<~A, <<~B]\n  e1\nA\n  e2\nB\n")
p({k: <<~A, j: <<~B})
  v1
A
  v2
B

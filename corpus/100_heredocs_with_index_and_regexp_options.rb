# A heredoc is a double-quoted string: its escapes are processed. `with_index`
# keeps the meaning of the method the enumerator came from. And a Regexp
# reports its options as the bits the constants name.

# --- heredoc escapes --------------------------------------------------------
a = <<~R
  end \\
R
p a.bytes
b = <<~R
  tab:\there
R
p b
c = <<~R
  say "hi" and 'bye'
R
p c
n = 5
d = <<~R
  val #{n} and \\
  more
R
p d
e = <<-R
    indented \\
  R
p e
f = <<~'R'
  raw \\ and \t
R
p f
g = <<~R
  a#{1 + 1}b\nc
R
p g.bytes
def gen(branches, else_code)
  <<~RUBY
    case
    #{branches.join('    ')}
    else #{else_code}
    end \\
  RUBY
end
p gen(["when a then b"], "false")

# --- with_index keeps the source method's meaning ---------------------------
xs = [:a, :b, :c]
p xs.map.with_index { |x, i| "#{x}-#{i}" }
p xs.map.with_index(1) { |x, i| [x, i] }
p xs.select.with_index { |x, i| i.odd? }
p xs.reject.with_index { |x, i| i.odd? }
p xs.each.with_index { |x, i| }
p xs.flat_map.with_index { |x, i| [x, i] }
p xs.each.with_index(10).to_a
p xs.map.with_index.to_a
p xs.each_with_index.map { |x, i| "#{x}#{i}" }
p [[1, 2], [3, 4]].map.with_index { |(a2, b2), i| a2 + b2 + i }

# --- a regex may follow any condition keyword, and reports its options ------
def which(x, delta)
  if delta > 0 && x != "\n"
    :insert
  elsif /\A[ \t]+\z/.match?(x)
    :remove
  end
end
p [which("  ", 1), which("  ", 0), which("x", 0)]
i = 0
i += 1 while /\A[0-4]\z/.match?(i.to_s)
p i
p [Regexp::IGNORECASE, Regexp::EXTENDED, Regexp::MULTILINE, Regexp::FIXEDENCODING, Regexp::NOENCODING]
p [/x/i.options, /x/m.options, /x/.options, /x/mix.options]
p 10 / 2

# A backslash at the end of a line continues it: a `?` that starts the next
# line is the ternary's, not a stray character literal (rbs's
# value_object_generator.rb writes `x.nil? \` and then `? a : b`)
a = nil
r = a.nil? \
    ? :nil
    : :value
p r
b = 5
c = b \
  ? b * 2 : 0
p c
p(1.zero? \
  ? :z : :nz)
# a `?x` character literal and `%w` still start a value after a continued line
d = [?x, \
  ?y]
p d
e = \
  %w[p q]
p e

# A backslash inside a comment never consumes that comment's newline.
# self \
/abc/.match("abc")
p :comment_regexp
# value ) \
?/
p :comment_character
# Quoted/comment-like bytes before a real code continuation remain code.
p "# )".empty? \
  ? :quoted_truthy : :quoted_false
p /#/.match?("#") \
  ? :regexp_truthy : :regexp_false
# Interpolation has its own continuation positions and restores its parent.
p "#{nil.nil? \
  ? :inside : :wrong}"
p nil.nil? \
  ? "#{1}" : :wrong
# eval's next lexer invocation starts without stale continuation offsets.
2.times { p eval("# self \\\n/abc/.match('abc'); :eval_ok") }

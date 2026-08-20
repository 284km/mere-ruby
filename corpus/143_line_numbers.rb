# `__LINE__` is the line it is written on. The lexer marks every newline with its
# byte offset now, and one pass turns those into line numbers before the parse --
# so the number survives the parser backtracking, which is what made the old
# count an upper bound (a re-scanned block body was counted twice).
p __LINE__
# a comment does not move it
p __LINE__

def in_a_method
  __LINE__
end
p in_a_method
p [1, 2].map { __LINE__ }.first

# a heredoc's body is spliced into the token stream as one token, so the line has
# to come from the source rather than from counting newline tokens
body = <<~HERE
  one
  two
HERE
p __LINE__
p body.length

# a backslash continues the logical line, and the tokens after it are still on
# the line the continuation started
joined = "a" \
         "b"
p [__LINE__, joined]

# an argument list spread over lines reports the line the expression is on
p(
  __LINE__
)

class WithConstant
  DEFINED_ON = __LINE__
end
p WithConstant::DEFINED_ON

# twice on one line is the same line
p [__LINE__, __LINE__]

# ... and a semicolon is not a newline
p __LINE__; p __LINE__

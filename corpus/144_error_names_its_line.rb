# An error names the line it happened on. Nothing in this interpreter knew what
# line anything was on until the lexer started marking them, so every report was
# "file: message" -- the file being the only thing it could say.
#
# The line is compared here through `rescue`, not through the uncaught-error
# report: ruby's report also names the method (`file:2:in 'f'`), which needs a
# call stack, and that is a later slice. What this program pins is that the
# interpreter KNOWS the line while it is running the statement.
def raises_here
  raise ArgumentError, "from line #{__LINE__}"
end
begin
  raises_here
rescue => e
  p e.message
end

# ... including inside a block, and after constructs that move the line
[1].each do
  begin
    raise "in a block on #{__LINE__}"
  rescue => e
    p e.message
  end
end

text = <<~HERE
  a heredoc body
  does not move the line count
HERE
begin
  raise "after a heredoc on #{__LINE__}"
rescue => e
  p [e.message, text.length]
end

# a statement spread over lines reports where the expression is
begin
  raise(
    "spread over lines, ending on #{__LINE__}"
  )
rescue => e
  p e.message
end

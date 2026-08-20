# `caller` is the third slice of the line-number work: the interpreter already
# recorded a method name per call depth (the recursion guard's stack dump used
# it), so all that was missing was the LINE each call was made on. An entry pairs
# the line of the call with the name of the frame that MADE it -- which is one
# depth further out, so the two come from different indices.
def inner
  caller
end
def outer
  inner
end
p outer
p caller.length          # the top level has no caller
p caller(0).length       # ... but it is a frame itself

def deep3; caller.length; end
def deep2; deep3; end
def deep1; deep2; end
p deep1

def zero_frame; caller(0).first; end
p zero_frame

# a frame restores the caller's line as it unwinds, so a line read after a call
# is the line of the CALL, not the last line the callee ran
def leaves_a_line
  42
end
here = __LINE__
leaves_a_line
p __LINE__ - here

# ... and each frame names its own method
def naming
  [__method__, caller(0).first.include?("in `naming'")]
end
p naming

# (a block's own frame is labelled with the enclosing method here, where ruby
# writes "block in with_block" -- KNOWN_GAPS.md. What is compared is that the
# frame is there and names the file and a line.)
def with_block
  [1].map { caller(0).first.split(":").length >= 3 }.first
end
p with_block

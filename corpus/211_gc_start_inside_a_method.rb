# GC.start collected from any depth and rooted only the env it was called in.
# A method's frame is not a root, so the CALLER's live locals were swept: the
# first line below printed "" and the second died with "failed". Each shape
# here holds a value that only a caller's frame, or a half-built argument
# list, can see at the moment GC.start runs.

def g
  GC.start
  1
end

def f
  a = "hello" * 3
  b = [1, 2, "three"]
  h = {k: "v"}
  g
  [a, b, h]
end
p f

def k(x) = x
p k([("abc" * 2), g, "tail"])

# deeper: the value lives three frames up, and a block frame sits between
def outer
  s = "outer-" * 2
  [1].each { |i| middle(i) }
  s
end
def middle(i) = inner(i)
def inner(i) = GC.start
p outer

# GC.count still moves for a GC.start inside a block (core/gc's count spec)
before = GC.count
[1].each { GC.start }
p GC.count > before

# GC.disable answers the previous state and an explicit GC.start still runs
p GC.disable
p GC.disable
c0 = GC.count
GC.start
p GC.count > c0
p GC.enable
p GC.enable

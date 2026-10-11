# `&:sym` asks a redefined Symbol#to_proc, and `pr.call` / `pr.()` ask a
# redefined Proc#call -- `pr[x]`, `pr.yield` and a block-pass do not (note
# 305). Both were made at parse time or answered by the builtin, so the
# program's method was never called; and the alias the new #call reaches the
# old one through was a NoMethodError.
class Symbol
  alias orig_to_proc to_proc
  def to_proc
    $to_proc = ($to_proc || 0) + 1
    orig_to_proc
  end
end
p [1, 2].map(&:to_s), $to_proc
p %w[a b].each_with_object([]).map(&:upcase) rescue p $!.class
p $to_proc

class Proc
  alias orig_call call
  def call(*a)
    $calls = ($calls || 0) + 1
    orig_call(*a)
  end
  def twice(x) = orig_call(x) + call(x)
end
pr = proc { |x| x * 2 }
p pr.call(3), $calls
p pr.(4), $calls
p pr.send(:call, 5), $calls
p pr[6], pr.yield(7), $calls
p [1, 2].map(&pr), $calls
p pr.orig_call(8), $calls
p pr.twice(1), $calls

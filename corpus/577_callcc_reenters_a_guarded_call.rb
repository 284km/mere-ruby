# Round 14 of note 541: a continuation taken inside an Array method that
# refuses re-entry (permutation, product, combination, the repeated ones,
# sort!, flatten's #to_ary), called after that method returned, goes back
# into the method's frame; the method raises "... reentered" there, the
# frame's own rescue gets it, and the frame carries on -- with its locals as
# they are now, so a counter counts the re-entries down. (What the block had
# left to run after the callcc is not run again here, as ruby would: the
# block below does nothing after it.) An escape still escapes.
$VERBOSE = nil
require "continuation"

def reenter(m, *a)
  n = 50
  cont = nil
  begin
    [1, 2, 3].send(m, *a) do
      callcc { |k| cont = k } unless cont
    end
  rescue => e
  end
  n -= 1
  cont.call if 0 < n
  [m, n, e.class, e.message]
end
p reenter(:permutation)
p reenter(:product)
p reenter(:combination, 2)
p reenter(:repeated_permutation, 2)
p reenter(:repeated_combination, 2)

def resort
  n = 20
  cont = nil
  ary = (1..30).to_a
  sizes = []
  begin
    ary.sort! do |a, b|
      sizes << ary.size
      callcc { |k| cont = k } unless cont
      b <=> a
    end
  rescue => e
  end
  n -= 1
  cont.call if 0 < n
  [n, ary.first(3), sizes.uniq, e.class, e.message]
end
p resort

def reflatten
  o = Object.new
  def o.to_ary = callcc { |k| @cont = k; [1, 2] }
  r = nil
  begin
    r = [10, o, 20, o].flatten
  rescue => e
  else
    o.instance_eval { @cont }.call
  end
  [r, e.class, e.message]
end
p reflatten

# an escape is still an escape, and its value comes back from callcc
p callcc { |k| k.call(5); 1 }
p callcc { |k| k.call(1, 2) }
p [1, 2, 3].each { |x| callcc { |k| k.call if x == 2 } }

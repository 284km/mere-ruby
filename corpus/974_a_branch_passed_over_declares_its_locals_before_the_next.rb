# A local is a local from where its first assignment is WRITTEN, whether or
# not that line runs. So in
#
#   if loaded
#     size = records.size
#   else
#     with_connection { |c| size, timestamp = c.select_rows(arel).first }
#   end
#   "#{size}-#{timestamp}"
#
# the block writes the method's `size`: the `if` branch comes first in the
# text. The branch that was passed over declared its names only after the
# whole `if` had run, so the block made variables of its own and the method
# read nil. That is ActiveRecord's compute_cache_version, and every
# collection cache key ended in "-" with nothing after it.
def w; yield 1; end

def after_if(f)
  if f
    x = 1
  else
    [1].each { x = 5 }
  end
  x
end
p after_if(true), after_if(false)

def masgn(f)
  if f
    size = 3
    ts = 1
  else
    w do |c|
      size, ts = [[5, 7]].first
    end
  end
  ts ? "#{size}-#{ts}" : "#{size}"
end
p masgn(true), masgn(false)

# a nested `if` in the branch passed over declares its names too
def nested(f)
  if f
    x = 1
    if x > 0
      y = 2
    end
  else
    w { x, y = [5, 6] }
  end
  [x, y]
end
p nested(true), nested(false)

# every branch before the one that runs: elsif, and unless/else
def chain(n)
  if n == 0
    a = :zero
  elsif n == 1
    b = :one
  else
    w { a = :set_a; b = :set_b }
  end
  [a, b]
end
p chain(0), chain(1), chain(2)

def un(f)
  unless f
    x = :unless
  else
    w { x = :else }
  end
  x
end
p un(false), un(true)

# case/when, with and without a subject
def by_case(n)
  case n
  when 0 then a = :zero
  when 1 then b = :one
  else w { a = :set_a; b = :set_b }
  end
  [a, b]
end
p by_case(0), by_case(1), by_case(2)

def by_case_bare(n)
  case
  when n == 0 then a = :zero
  else w { a = :set_a }
  end
  a
end
p by_case_bare(0), by_case_bare(1)

# a name first written in a LATER branch is not yet a local in an earlier
# one: the block's is its own
def later(f)
  if f
    w { z = 1 }
  else
    z = 2
  end
  z
end
p later(true), later(false)

# the last branch passed over, with nothing after it: declared at the end
def last_one
  if false
    q = 1
  end
  w { q = 9 }
  q
end
p last_one

# An exception has to keep its class and message all the way out. Two places lost
# them, and both were found by asking where -- MERE_RUBY_LOST_EXC=1 prints the
# spot where an exception arrives with neither.
#
# 1. `rescue *[]` -- an EMPTY splat -- rescues NOTHING in ruby, where a bare
#    `rescue` rescues StandardError. Both reached the matcher as an empty list, so
#    the clause caught everything and swallowed the exception. bundler writes
#    `rescue *[const_get_safely(:ENOTSUP, Errno)].compact`, which is empty
#    whenever that constant is absent.
def with_empty_splat
  yield
rescue *[].compact
  :swallowed
end
begin
  with_empty_splat { raise ArgumentError, "not swallowed" }
rescue => e
  p [e.class, e.message]
end

def with_one_class
  yield
rescue *[KeyError]
  :caught
end
p with_one_class { raise KeyError, "match" }
begin
  with_one_class { raise ArgumentError, "no match" }
rescue => e
  p [e.class, e.message]
end

# 2. An `ensure` body runs while an exception is still in flight, and the pending
#    exception lives in one slot. A rescue inside the ensure body -- or inside
#    anything it calls -- consumed that slot, and the pending exception came out
#    as a bare StandardError with an interpreter message.
def rescues_its_own
  begin
    raise KeyError, "inner"
  rescue KeyError
    :handled
  end
end
begin
  begin
    raise ArgumentError, "survives the ensure"
  ensure
    rescues_its_own
  end
rescue => e
  p [e.class, e.message]
end

begin
  [1].each do
    begin
      raise TypeError, "from a block, past an ensure"
    ensure
      rescues_its_own
    end
  end
rescue => e
  p [e.class, e.message]
end

# ... and the ensure still runs, and its own raise still wins when it has one
order = []
begin
  begin
    raise ArgumentError, "replaced"
  ensure
    order << :ensure_ran
  end
rescue => e
  order << e.class
end
p order

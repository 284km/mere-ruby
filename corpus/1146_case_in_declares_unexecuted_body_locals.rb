def choose1146(value)
  case value
  in [first]
    chosen = first
  else
    unchosen = :else
  end
  p [defined?(first), first, defined?(chosen), chosen,
     defined?(unchosen), unchosen]
end
choose1146([4])
choose1146(5)

def branches1146(value)
  case value
  in 0
    prior = :first
  in 1
    1.times { prior = :second }
    middle = :middle
  else
    tail = :tail
  end
  p [prior, middle, tail]
end
branches1146(0)
branches1146(1)
branches1146(2)

def guard1146(value)
  case value
  in Integer if (checked = value.negative?)
    skipped = :never
  in Integer
    1.times { skipped = :later }
    matched = value
  end
  p [checked, skipped, matched]
end
guard1146(7)

def unmatched1146
  case 1
  in 0
    absent = :never
  end
rescue NoMatchingPatternError
  p [defined?(absent), absent]
end
unmatched1146

def nested1146(value)
  case value
  in 0
    if false
      nested = :never
    end
    begin
      1
    rescue
      rescued = :never
    end
  else
    other = :other
  end
  p [nested, rescued, other]
end
nested1146(0)
nested1146(1)

def returned1146
  case 1
  in 1
    return binding
    after_return = :never
  else
    other_return = :never
  end
end
captured = returned1146
p [captured.local_variable_get(:after_return),
   captured.local_variable_get(:other_return)]

def ordering1146(value)
  case value
  in 0
    early = :early
  in 1
    1.times { late = :block_only }
    present = :present
  else
    late = :late
  end
  p [early, present, late]
end
ordering1146(0)
ordering1146(1)
ordering1146(2)

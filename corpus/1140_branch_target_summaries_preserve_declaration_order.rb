def branch_summary1140(mode)
  if mode == 0
    first = :first
    begin
      nested = :nested
    rescue StandardError
      rescued = :rescued
    end
    while false
      loop_local = :loop
    end
  elsif mode == 1
    [1].each { first = :updated; nested = :updated }
    second = :second
  else
    [1].each do
      first, nested, rescued, loop_local, second = (1..5).to_a
    end
  end
  [first, nested, rescued, loop_local, second]
end
3.times { |mode| p branch_summary1140(mode) }

def branch_later1140(take)
  if take
    [1].each { later = :block_only }
  else
    later = :later
  end
  later
end
p branch_later1140(true), branch_later1140(false)

def branch_pattern1140(value)
  if false
    skipped = :skipped
  elsif value in {answer:}
    [1].each { skipped = answer }
  else
    [1].each { skipped = :missing }
  end
  [skipped, answer]
end
p branch_pattern1140({answer: 42}), branch_pattern1140({})

def branch_boundary1140
  if false
    Class.new do
      hidden = :class_local
    end
    lambda { block_local = :block_local }
    visible = :visible
  end
  [defined?(hidden), defined?(block_local), visible]
end
p branch_boundary1140

10.times do
  result = eval('if false; before = 1; elsif true; [0].each { before = 2 }; else; after = 3; end; [before, after]')
  raise 'eval branch locals changed' unless result == [2, nil]
end
p :repeated_eval_ok
GC.start
p branch_summary1140(2)

def case_summary1140(value)
  case value
  when 1
    p defined?(later)
    selected = :first
  when 2
    later = :second
  else
    fallback = :else
  end
  p [defined?(selected), selected, defined?(later), later,
     defined?(fallback), fallback]
end
case_summary1140(1)
case_summary1140(2)
case_summary1140(3)

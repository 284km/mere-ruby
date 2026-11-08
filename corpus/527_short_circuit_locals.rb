def never_run
  raise 'short-circuited expression executed'
end

# Both expression and statement operators declare skipped assignment targets.
1.times do
  marker = Object.new
  result = marker || (high_or = never_run)
  p [result.equal?(marker), high_or, defined?(high_or)]
  result = false && (high_and = never_run)
  p [result, high_and, binding.local_variable_defined?(:high_and)]
  true or low_or = never_run
  false and low_and = never_run
  p [low_or, low_and]
  true or chain_outer = chain_inner = never_run
  p [chain_outer, chain_inner]
  false && [array_local = never_run, {key: hash_local = never_run}]
  p [array_local, hash_local]

  # This condition is the shape used by mkmf's have_framework.
  if marker || (objc = never_run)
    p objc
  end
end
p [defined?(high_or), defined?(low_and), defined?(objc)]

# Existing outer cells are preserved, even if they contain false or nil.
outer = :kept
falsy = false
empty = nil
1.times do
  true || (outer = never_run)
  false && (falsy = never_run)
  true or empty = never_run
end
p [outer, falsy, empty]

# New locals belong to each invocation and remain accessible to closures.
[false, true].each do |skip|
  skip || (per_call = :assigned)
  p per_call
end
reader, writer = 1.times.map do
  true || (captured = never_run)
  [proc { captured }, proc { captured = :updated }]
end.first
GC.start
p reader.call
writer.call
p reader.call

# The left side still runs before the skipped target becomes visible.
def prior_name = :method
1.times do
  result = prior_name || (prior_name = never_run)
  p [result, prior_name]
end

# Executed right operands retain their values and run exactly once.
events = []
1.times do
  a = false || (written = events.push(:or))
  b = true && (also_written = events.push(:and))
  false or low_written = events.push(:low_or)
  true and low_also_written = events.push(:low_and)
  p [a.equal?(events), b.equal?(events), written.equal?(events),
     also_written.equal?(events), low_written.equal?(events), low_also_written.equal?(events)]
end
p events

# Nested block bodies and nonlocal assignments must not create local cells.
1.times do
  true || [1].map { |nested_arg| nested_local = never_run }
  true || -> { lambda_local = never_run }
  true || (@skipped_ivar = never_run)
  true || ($skipped_global = never_run)
  p [defined?(nested_arg), defined?(nested_local), defined?(lambda_local)]
  p [instance_variable_defined?(:@skipped_ivar), defined?($skipped_global)]
end

# Named captures are declarations too, without performing the match.
1.times do
  /keep/ =~ 'keep'
  previous = $~
  true || /(?<skipped_capture>x)/ =~ 'x'
  p [skipped_capture, $~.equal?(previous)]
end

# Declarations inside skipped wrappers still belong to this scope.
1.times do
  true || ((range_begin = never_run)..(range_end = never_run))
  false && [*(splat_local = never_run)]
  true || never_run(**(kwargs_local = never_run), &(block_local = never_run))
  true || Object.new.never_run(&(method_block = never_run))
  true || nil&.never_run(&(safe_block = never_run))
  true || defined?(defined_local = never_run)
  true || (attr_recv = never_run).value += (attr_rhs = never_run)
  true || ((idx_recv = never_run)[idx_arg = never_run] ||= (idx_rhs = never_run))
  true || ((pattern_input = never_run) in pattern_local)
  true || ((safe_recv = never_run)&.call(safe_arg = never_run) { block_body_local = never_run })
  true || (multi_a, multi_b = multi_rhs = never_run)
  true || begin
    if condition_local = never_run
      condition_body = never_run
    end
  end
  p [range_begin, range_end, splat_local, kwargs_local, block_local, defined_local]
  p [attr_recv, attr_rhs, idx_recv, idx_arg, idx_rhs, pattern_input, pattern_local]
  p [safe_recv, safe_arg, defined?(block_body_local), multi_a, multi_b, multi_rhs]
  p [condition_local, condition_body, method_block, safe_block]
end

# defined? preserves declarations without executing the assignment itself.
answer = defined?(unevaluated = never_run)
p [answer, answer.frozen?, unevaluated]
answer = defined?((defined_a, defined_b = never_run))
p [answer, defined_a, defined_b]
existing = :unchanged
p [defined?(existing = never_run), existing]

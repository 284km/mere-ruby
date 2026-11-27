mode = ARGV.fetch(0)
iterations = Integer(ARGV.fetch(1))
seed = Integer(ARGV.fetch(2, '--seed=1').delete_prefix('--seed='))
srand(seed)
GC.start
index = 0
case mode
when 'integer'
  value = 0
  while index < iterations
    value += 1
    index += 1
  end
when 'float'
  value = 0.0
  while index < iterations
    value += 1.0
    index += 1
  end
when 'string'
  source = 'x'
  value = nil
  while index < iterations
    value = source.upcase
    index += 1
  end
when 'encoding'
  source = 'x'
  value = nil
  while index < iterations
    value = source.encoding
    index += 1
  end
  value = value.name
when 'array'
  source = [1, 2]
  value = nil
  while index < iterations
    value = source.length
    index += 1
  end
else
  raise ArgumentError, "unknown mode: #{mode}"
end
p [mode, iterations, seed, value]

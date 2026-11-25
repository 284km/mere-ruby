# Deterministic workloads; measure varying COUNTS with GC_TIGHT and --seed=1.
count = Integer(ARGV.fetch(0))
kind = ARGV.fetch(1, 'plain')
case kind
when 'plain'
  count.times { '%s' % 'x' }
when 'nested'
  value = Object.new
  value.define_singleton_method(:to_s) { '%s' % 'x' }
  count.times { '%s' % value }
when 'rescued'
  count.times do
    begin
      format('%')
    rescue ArgumentError
    end
  end
when 'long'
  template = 'a' * 600 + '%s' + 'b' * 600
  count.times { template % 'x' }
else
  raise ArgumentError, 'unknown benchmark case'
end
p [kind, count]

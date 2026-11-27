seed = ARGV.find { |argument| argument.start_with?('--seed=') }
srand(Integer(seed ? seed.split('=', 2).last : '1'))
count = Integer(ARGV.fetch(0, '10000'))
count.times { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
p [count, Process.clock_gettime(Process::CLOCK_MONOTONIC).class,
   Process.instance_variables.grep(/clock/)]

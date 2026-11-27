mode = ARGV[0] || 'owned'
count = Integer(ARGV[1] || '10000')
seed_arg = ARGV.find { |argument| argument.start_with?('--seed=') }
seed = seed_arg ? Integer(seed_arg.split('=', 2).last) : 1
srand(seed)

class SelfAliasCost
  def value = 1
end
SelfAliasCost.class_eval do
  case mode
  when 'owned'
    count.times { alias value value }
  when 'churn'
    count.times do |index|
      name = :"foo_#{index % 1000}"
      define_method(name) {}
      alias :"foo_#{index % 1000}" :"foo_#{index % 1000}"
      remove_method(name)
      GC.start if index % 1000 == 999
    end
  when 'plain'
    count.times do |index|
      name = :"foo_#{index % 1000}"
      define_method(name) {}
      remove_method(name)
      GC.start if index % 1000 == 999
    end
  else
    raise ArgumentError, mode
  end
end
p [mode, count]

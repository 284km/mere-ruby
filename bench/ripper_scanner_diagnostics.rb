require 'ripper'
seed = ARGV.find { |argument| argument.start_with?('--seed=') }
srand(Integer(seed ? seed.split('=').last : '1'))
kind = ARGV.fetch(0)
count = Integer(ARGV.fetch(1))
source = {'empty' => '', 'ordinary' => 'a = 1; a + 2', 'unicode' => '?\\u{41 42}'}.fetch(kind)
total = 0
count.times { total += Ripper.lex(source).size }
p [kind, count, total]

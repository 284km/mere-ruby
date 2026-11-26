require 'ripper'
seed_option = ARGV.find { |arg| arg.start_with?('--seed=') }
srand(Integer(seed_option ? seed_option.split('=').last : '1'))
kind = ARGV.fetch(0)
count = Integer(ARGV.fetch(1))
source = {
  'empty' => '',
  'ordinary' => 'a = 1; a + 2',
  'heredoc' => "a=<<A+1\nbody\nA\n",
  'braces' => 'a = {b: 1}; a[:b] + 2',
  'stray' => 'a( foo, bar: baz }',
  'unfinished' => "<<A+1\n\#{\n"
}.fetch(kind)
total = 0
count.times { total += Ripper.lex(source).size }
p [kind, count, total]

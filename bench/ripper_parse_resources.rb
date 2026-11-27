# Fixed-seed parse controls; use the identical source for main and candidate.
require 'ripper'
srand(1)
kind, count = ARGV[0], Integer(ARGV[1])
source = {
  'empty' => '',
  'sexp' => '',
  'regexp' => '/(a|b)c/i',
  'regexp_invalid' => '/[\\xC0-\\xF0]/u'
}.fetch(kind)
if kind == 'sexp'
  count.times { Ripper.sexp(source) }
else
  count.times { Ripper.parse(source) }
end
p [kind, count]

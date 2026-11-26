require 'ripper'
[
  'a::C {}', 'a.C {}', 'a.foo {}', 'a::foo {}', 'a::C', 'a.C',
  'a::C() {}', 'a::C 1', 'a::C { 2 }', 'self::C {}', 'a::Ä {}'
].each { |source| p [source, Ripper.sexp(source)] }

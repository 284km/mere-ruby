# The void-context warning ruby gives with -w ("possibly useless use of X in
# void context"): which statements, which list's last one is its value (not
# an ensure clause's, not the program's), an eval's caller's locals counted as
# variables; and a hash pattern's key that binds a local must name one

require "stringio"

def warnings_of(src)
  x = 1
  old, $stderr = $stderr, StringIO.new
  verbose, $VERBOSE = $VERBOSE, true
  begin
    eval(src, binding, "w.rb")
  rescue NameError
  ensure
    out = $stderr.string
    $stderr, $VERBOSE = old, verbose
  end
  out.lines.map { |l| l.sub(/\Aw\.rb:/, "").chomp }
end

[
  "1; 2",
  "x; nil",
  "y = 2; y; nil",
  "foo = 3\nfoo\n4",
  "1 + 1; nil",
  "1.+(1); nil",
  "x == 1; x != 1; x <=> 1; x ** 2; -x; nil",
  "!x; x === 1; x << 1; x =~ /a/; x && 1; nil",
  "Object; ::Object; Comparable::Object; nil",
  "x..x; x...x; nil",
  "self; nil; true; false; nil",
  "defined?(x); nil",
  "@a; $b; nil",
  "__FILE__; __LINE__; nil",
  ":a; :\"b\"; /c/; 1r; 2i; -1; \"s\"; \"\#{x}\"; nil",
  "begin; ensure; x; 5; end",
  "def m; 6; 7; ensure; 8; end",
  "if x\n  9\n  10\nend",
  "proc { _1; 11 }; proc { it; 12 }; nil",
  "y = (13; 14); nil",
  "z rescue nil; nil",
].each { |src| p [src, warnings_of(src)] }

p(warnings_of("2 + 2") == [])
p eval("defined?(x); 15")

def refused(src)
  eval(src)
  :parsed
rescue SyntaxError => e
  [/key must be valid as local variables/, /symbol literal with interpolation is not allowed/].select { |r| e.message =~ r }.map(&:source)
end

p refused("case 0\nin a?:\nend")
p refused("case 0\nin \"a-b\":\nend")
p refused("case 0\nin \"Ab\":\nend")
p refused("case 0\nin \"\#{a}\": 1\nend")
p refused("case 0\nin \"\#{a}\":\nend")
case {a?: true, "a-b": 1, _x: 2}
in {a?: true, "a-b": 1, "_x":}
  p _x
end

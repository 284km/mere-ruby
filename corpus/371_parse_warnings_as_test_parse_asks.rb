# The parse-time warnings test_parse and test_rubyoptions ask for: "assigned
# but unused variable", "found '= literal' in conditional" and the literal
# ends of a flip-flop -- captured from $stderr so the corpus compares them

require 'stringio'

def warnings_of(src)
  saved, $stderr = $stderr, StringIO.new
  verbose, $VERBOSE = $VERBOSE, true
  begin
    eval(src)
  rescue SyntaxError => e
    $stderr.puts "SyntaxError"
  end
  $stderr.string.lines.map { |l| l.sub(/\A\(eval at [^)]*\):/, "") .chomp }
ensure
  $VERBOSE = verbose
  $stderr = saved
end

o = Object.new
[
  "def m1; a = 1; nil; end",
  "def m2; a = 1; a(); end",
  "def m3; tap { a = 1; a() }; end",
  "def m4; a = a = 1; nil; end",
  "def m5; a, = 1, 2; end",
  "def m6(a); nil; end",
  "def m7((a)); nil; end",
  "def m8; _a = 1; end",
  "def m9; a = 1; :a; end",
  "def m10; a ||= 1; end",
  "def m11; a = 1; a += 1; end",
  "def m12; a = 1; -> { a }; end",
  "def m13; x = 1; \"\#{x}\"; end",
  "def m14; for i in [1]; end; end",
  "def m15; for i in [1]; end; i; end",
  "def m16; begin; rescue => e; end; end",
  "def m17; f(src = 1); end",
  "def m18; x = 1 or raise; end",
  "def m19; m = Module.new; include m; end",
  "def m20; a = 1; def a.foo; end; end",
  "def m21; e = [ArgumentError]; begin; rescue *e; end; end",
  "def m22; 1.times do |b| end; end",
  "def m23; it = 2; end",
  "def m24\n  x = nil\n  x = 1 until x\nend",
  "1.times { a = 1 }",
  "a = 1",
  "if x = 1 then end",
  "(x, y = 1, 2) ? 1 : 2",
  "def m25; if (z = 1) then end; end",
  "(\"a\"..\"b\") ? 1 : 2",
  "(:a..:b) ? 1 : 2",
].each { |s| p [s, warnings_of(s)] }

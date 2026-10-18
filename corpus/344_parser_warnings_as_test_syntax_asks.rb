# Parser warnings and messages as test_syntax asks (note 368): -w's warning
# for an operator after a local or a literal that could be an argument's
# prefix (`puts 1 **0`), and `1 &0` read as the binary `&`; "statement not
# reached"; no "literal in condition" under `!`, and "literal in flip-flop";
# a CR in the middle of a line; `...` at the end of a line; prism's wording
# for `def :foo`, an empty group name and two unterminated heredocs; a
# constant's ||= / &&= assigning only when they must, in a statement and in
# an expression, `::C` included; `false + 1` is a NoMethodError.
require 'stringio'
$n = 0
def w(code, verbose = true, line = 1)
  old, $stderr = $stderr, StringIO.new
  ov, $VERBOSE = $VERBOSE, verbose
  r = begin
    eval(code, nil, "w.rb", line); :ok
  rescue SyntaxError => e
    e.message.include?("unexpected symbol literal") ? :symbol_literal :
    e.message.include?("unexpected string literal") ? :string_literal :
    e.message.include?("group name is empty") ? :empty_group :
    e.message.scan(/can't find string "(\w+)"/).flatten
  rescue => e
    e.message
  end
  out = $stderr.string
  $stderr = old; $VERBOSE = ov
  # (prism's recovery from `def :foo` adds a void-context warning of its own)
  p [code, out.lines.reject { |l| l.include?("possibly useless") }.map { |l| l.sub(/^w\.rb:/, "").strip }, r]
end
%w[** * << & + - / %].each do |op|
  ["puts 1 #{op}0", "puts :a #{op}0", "m = 1; puts m #{op}0"].each { |s| w("def __t#{$n += 1}; #{s}; end") }
end
w("x = 1; p(x *2)")
w("def __a = (p 1 &3)")
w("loop do\nbreak\nfoo\nend")
w("loop do\nbreak\nfoo\nend", true, 0)
w("def __u; return; foo; end")
w("def __v(x); return if x; 1; end")
w("1 if \"\""); w("1 if //"); w("1 if 1"); w("1 if :foo"); w('1 if :"#{"foo".upcase}"')
w('1 if !""'); w("1 if !//"); w("1 if !1"); w("1 if !:foo")
w('1 if ""..false'); w("1 if :foo..false"); w('1 if ""...false'); w('1 if :"#{"foo".upcase}"...false')
w("'\r'\r"); w("'\r'\r\n"); w("x\r= 1", true, 5)
w("1...\n2"); w("1..\n2"); w("(1...)"); w("[1...\n2]")
w("def :foo"); w("def 'foo'")
w("/(?<>)/=~s")
w("puts <<A\n"); w("puts <<A + <<B\n")
p((false + 1 rescue $!.message), (true * 2 rescue $!.message), true ^ true)
[[nil, "||"], ["false", "||"], ["true", "||"], ["false", "&&"], ["true", "&&"], ["11", "+"]].each do |preset, op|
  src = "#{"Bar = " + preset if preset}\nclass Foo\n  p ::Bar #{op}= 42\nend\nmodule M\n#{"  Baz = " + preset if preset}\nend\nM::Baz #{op}= 42\np M::Baz\np(M::Baz #{op}= 7)\n"
  o = IO.popen([RbConfig.ruby, "-e", src, err: [:child, :out]], &:read)
  p [preset, op, o.lines.map(&:chomp)]
end
o = IO.popen([RbConfig.ruby, "-e", "class Foo; end; Foo::Bar", err: [:child, :out]], &:read)
p o.lines.map(&:chomp)

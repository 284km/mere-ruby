# What a refusal says about the token after a statement, a write target with
# a pseudo-variable, ? before a blank, CRLF source, a heredoc whose name
# starts with a blank, undef of an operator list, a BOM in eval, a coding
# comment with a blank before its =, and an alias of a global made twice

{"1E1E1" => "unexpected constant", "'0123' abcdef" => "unexpected local variable or method",
 "\"x\"xxxx" => "unexpected local variable or method", "x, true" => "Can't assign to true",
 "?\v" => "unexpected '?'", "?\\u{41 42}" => "Multiple codepoints", "?\\u123" => "invalid Unicode escape"}.each do |src, want|
  r = begin
    RubyVM::InstructionSequence.compile(src)
    :ok
  rescue SyntaxError => e
    e.message.include?(want)
  end
  p [src, r]
end

p eval("\"a\r\nb\""), eval("<<A\r\n1\r\n2\r\nA"), eval("%w(a\r\nb)"), eval("<<-A\r\n1\rx\r\nA")
p eval("<<' FOO'\n[Bug #19539]\n FOO\n")

o = Object.new
def o.>(x) = x
def o./(x) = x
o.instance_eval "undef >, /"
p o.respond_to?(:>), o.respond_to?(:/)

x = nil
eval "\xef\xbb\xbf x = __ENCODING__"
p x
begin
  eval "# coding = no_such_encoding_here\nx = 1\n"
rescue ArgumentError => e
  p e.class
end
p((eval("# coding=no_such_encoding_here\n:ok")))

"abc" =~ /b/
alias $pl398 $&
alias $& $pl398
"xyz" =~ /y/
p $&, $pl398

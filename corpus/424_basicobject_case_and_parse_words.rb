# A BasicObject that answers through method_missing is asked === by a
# `when`, and three refusals in ruby's words (note 452).

flag = false
case 1
when Class.new(BasicObject) { def method_missing(*) true end }.new
  flag = true
end
p flag
p((begin; case 1; when Class.new(BasicObject) {}.new; end; rescue NoMethodError => e; e.class; end))

[["def f r:def d; def f 0end", /unexpected/], ["/\\u", /too short escape sequence/]].each do |src, want|
  begin
    eval(src, nil, "t.rb")
    puts "no error"
  rescue SyntaxError => e
    p want.match?(e.message)
  end
end

code = "# -*- coding: utf-8 -*-\n" "def n \"\u{2208}\"; end"
begin
  RubyVM::InstructionSequence.compile(code, "f", "f", 1)
rescue SyntaxError => e
  p e.message.include?("def n \"\u{2208}\"; end")
end

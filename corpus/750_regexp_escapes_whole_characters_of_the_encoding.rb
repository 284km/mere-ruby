# A regexp whose escapes make bytes of a multibyte encoding must make whole
# characters of it -- in Regexp.new, in a literal the parser reads, and in
# RubyVM::AbstractSyntaxTree.parse, which compiles a plain literal (REGX) as
# parse.y does but not a split or interpolated one (DREGX). The refusal names
# the pattern as the lexer left it (`\M-b` is written \xE2) and the line the
# literal is on.
[['a\xff', nil], ['a\xE2', nil], ['\xc3\xa9', nil], ['a\xff', Regexp::NOENCODING],
 ['\xc3', nil], ['a\M-b', nil], ['a\c\xff', nil], ['\303\251', nil], ['\303', nil]].each do |src, opt|
  r = begin
    (opt ? Regexp.new(src, opt) : Regexp.new(src)).source
  rescue RegexpError => e
    "RegexpError: #{e.message}"
  end
  puts "Regexp.new(#{src.inspect}#{opt ? ", #{opt}" : ""}) => #{r}"
end

['/a\M-b/', '/a\xff/', '/a\M-b/n', '/\xff/n', '/a#{1}\xff/', '/a\M-#@~/', '/a#@~\xff/',
 'x = /\xc3/', '/\xc3\xa9/', "1\n/a\\M-b/", '%r{a/\xff}'].each do |s|
  ast = begin
    RubyVM::AbstractSyntaxTree.parse(s)
    "ok"
  rescue SyntaxError => e
    "SyntaxError: #{e.message}"
  end
  ev = begin
    eval(s, nil, "lit.rb", 1)
    "ok"
  rescue SyntaxError => e
    "SyntaxError: #{e.message}"
  end
  puts "#{s.inspect}", "  AST:  #{ast}", "  eval: #{ev}"
end

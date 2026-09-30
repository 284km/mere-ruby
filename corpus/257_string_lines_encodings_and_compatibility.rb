# String#lines / #each_line follow CRuby's rb_str_enumerate_lines: the block
# form of #lines yields and answers the receiver, paragraph mode keeps exactly
# two newlines, chomp: removes only the separator it was given, and a
# separator that is not a String is refused.
a = []
s = "one\ntwo\r\nthree"
p(s.lines { |x| a << x }.equal?(s), a)
p "hello\nworld\n\n\nand\nuniverse\n\n\n\n\ndog".lines("")
p "hello\r\nworld\n\n\nand\nuniverse\n\n\n\r\n\r\ndog".each_line("").to_a
p "hello\nworld\n\n\nand\nuniverse\n\n\n\n\n".lines("", chomp: true)
p "\n\n\nx".lines(""), "a\nb\n".lines("", chomp: true)
p "hello \r\nworld\r\n".each_line(chomp: true).to_a
p "hello\r\n world\r\n".lines(" ", chomp: true)
p "".lines(nil), "".lines(false), "x".lines(nil)
[false, :o, 1].each do |sep|
  begin
    "hello world".each_line(sep) {}
  rescue TypeError => e
    p e.message
  end
end
p "hello world".each_line(" ").size
p "a\nb".encode("UTF-16LE").lines.map { |l| l.encode("UTF-8") }
p "a\nb".encode("UTF-16").lines.size
begin
  "a\nb".dup.force_encoding("UTF-7").lines
rescue Encoding::ConverterNotFoundError => e
  p e.class
end
begin
  "a\nb".encode("UTF-16LE").lines("\n")
rescue Encoding::CompatibilityError => e
  p e.message
end
old = $/
$VERBOSE = nil
$/ = "l"
p "hello world".lines
$/ = old

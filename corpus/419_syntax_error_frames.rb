# A SyntaxError says where, as prism frames it: the line, and `^~~` under
# the bytes that are wrong (note 445).

# (one error each: where prism finds several -- `unless`, `class xxx end`
#  -- it lists them all, and mere-ruby frames the one it found)
[
  "0b", "0x", "a = $#", "a = $-", "\"\\x\"", "0000xyz", "1 foo", "a = 1 b",
  "module foo; end", "1.", "1e",
].each do |src|
  begin
    eval(src, nil, "t.rb")
    puts "no error: #{src.inspect}"
  rescue SyntaxError => e
    puts e.message
  end
end

# a suffix comes off only where a character of the path begins
s = "foo\x93_a".force_encoding("cp932")
p File.basename(s, "_a").bytes
p File.basename(s, "a").bytes
p File.basename(s, "_a").encoding

# a UTF-16 part is refused inside an Array, and when a #to_path puts it there
names = %w"a b".map { |x| x.encode(Encoding::UTF_16LE) }
p((File.join(names) rescue $!.class))
o = Object.new
arr = [o, "b"]
o.define_singleton_method(:to_path) { arr[1] = names[1]; "a" }
p((File.join(arr) rescue $!.class))

# and an unpack format in an encoding ASCII does not fit
p(("foo".unpack("C".encode("UTF-32BE")) rescue $!.class))
p(("foo".unpack1("C".encode("UTF-32BE")) rescue $!.class))

# Edge removals keep the receiver and returned piece independent, including NULs.
def remove_span(input, *span)
  string = input.dup
  untouched = string.dup
  identity = string.object_id
  piece = string.slice!(*span)
  p [string.bytes, piece&.bytes, untouched.bytes,
     string.encoding.name, piece&.encoding&.name,
     string.object_id == identity, piece&.equal?(string)]
end

remove_span("a\0b\0".b, -1)
remove_span("a\0b\0".b, 0, 2)
remove_span("a\0b\0".b, 1, 2)
remove_span("a\0b\0".b, 0..-1)
remove_span("a\0b\0".b, 4, 0)
remove_span("a\0b\0".b, 8, 1)
remove_span("あいう", -1)
remove_span("あいう", 0, 1)
remove_span("あいう", 1...2)
remove_span("", 0, 0)

string = "\0" * (1024 * 1024)
piece = string.slice!(-1)
p [string.bytesize, piece.bytes, string.getbyte(0), string.getbyte(-1)]
begin
  "abc".freeze.slice!(0, 0)
rescue => error
  p error.class.name
end

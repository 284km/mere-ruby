# Internal byte searches must preserve Ruby character-offset normalization,
# binary NULs, empty needles, overlapping matches and suffix boundaries.
haystacks = ["".b, "aaaa".b, "ab\0ab\0".b, "\xffa\0\xff".b, ("ab" * 40).b]
needles = ["".b, "a".b, "aa".b, "ab".b, "\0".b, "\0a".b, "\xff".b, "absent".b]
haystacks.each do |haystack|
  needles.each do |needle|
    [-haystack.bytesize - 1, -1, 0, 1, haystack.bytesize, haystack.bytesize + 1].each do |offset|
      p haystack.index(needle, offset)
    end
    p haystack.partition(needle)
    p haystack.sub(needle, "X")
    p haystack.gsub(needle, "X")
    p haystack.split(needle, -1)
  end
end
text = "é😀é"
["", "é", "😀", "missing"].each do |needle|
  [-5, -1, 0, 1, 2, 3, 4].each { |offset| p text.index(needle, offset) }
end
puts "byte search offsets preserved"

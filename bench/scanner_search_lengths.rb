require "strscan"
text = "a" * (8 * 1024 * 1024 - 1) + "z"
scanner = StringScanner.new(text)
sum = 0
24.times do |index|
  scanner.reset
  sum += case index % 3
         when 0 then scanner.exist?(/z/)
         when 1 then scanner.skip_until(/z/)
         else scanner.search_full(/z/, false, false)
         end
end
p [text.bytesize, sum, scanner.pos, scanner.matched]

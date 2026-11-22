require "strscan"
patterns = [/\Aa/, /(?:\n|\A)a/, /\Aa(?=b)/, /\A(?m:a.)/, /\A\ba/, /\A\Ba/, /^a/, /(?<=x)a/, /\\A/, /[a^]/]
[false, true].each do |fixed|
  ["ab", "xab", "x\nab", "a\nab", "\\Aab"].each do |text|
    (0..text.bytesize).each do |position|
      patterns.each do |pattern|
        [:scan, :scan_until, :check_until].each do |operation|
          scanner = StringScanner.new(text.dup, fixed_anchor: fixed)
          scanner.pos = position
          result = scanner.public_send(operation, pattern)
          p [fixed, text, position, pattern.source, operation, result, scanner.pos, scanner.matched]
        end
      end
    end
  end
end
text = "éab"
s = StringScanner.new(text)
s.pos = 2
p [s.scan(/\Aa/), s.scan(/b/), s.charpos, s.string.equal?(text)]

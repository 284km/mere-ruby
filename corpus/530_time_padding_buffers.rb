require 'date'

['ab', 'éx', '日🙂'].each do |pad|
  [0, 1, 5, 65_535, 65_536, 65_537, 100_003].each do |width|
    s = '日本abc'
    count = [width - s.length, 0].max
    expected = (pad * (count / pad.length) + pad[0, count % pad.length]) + s
    actual = s.rjust(width, pad)
    raise 'rjust content' unless actual == expected && actual.encoding == s.encoding
    raise 'rjust alias' if actual.equal?(s)
  end
end

t = Time.utc(2001, 2, 3, 4, 5, 6)
['%100003F', '%0100003F', '%-100003Y', '%Z', '%Z/%Z', '%F/%T', 'x%10F', '%Q', ''].each do |fmt|
  before = fmt.dup
  result = t.strftime(fmt.freeze)
  GC.start
  p [fmt, result.length, result[0, 12], result[-12, 12], result.encoding.name, result.frozen?]
  raise 'format mutated' unless fmt == before
end
date = Date.new(2001, 2, 3)
p date.strftime('%20F %10A')
puts 'padding chunks and owned time-format strings preserved'

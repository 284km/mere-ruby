require 'strscan'

# Cross the native integer boundary in every radix, then round-trip exact
# values. The strict and permissive readers deliberately differ on bad input.
[2**62 - 1, 2**62, 2**63, 2**127 + 12345].each do |n|
  (2..36).each do |base|
    s = n.to_s(base)
    raise "Integer radix #{base}" unless Integer(s, base) == n
    raise "to_i radix #{base}" unless s.to_i(base) == n
    grouped = s.chars.join('_')
    raise 'separators' unless Integer(grouped, base) == n && grouped.to_i(base) == n
    raise 'sign' unless Integer(" -#{grouped} ", base) == -n && " -#{grouped} ".to_i(base) == -n
    ['_', '__1', '_!'].each do |suffix|
      begin
        Integer(s + suffix, base)
        raise 'accepted malformed suffix'
      rescue ArgumentError
      end
      raise 'permissive suffix' unless (s + suffix).to_i(base) == n
      raise 'exception: false' unless Integer(s + suffix, base, exception: false).nil?
    end
  end
end

s = 'F' * 2000
n = 16**2000 - 1
raise 'large strict parse' unless Integer(s, 16) == n
raise 'large permissive parse' unless s.to_i(16) == n
raise 'prefix' unless Integer('-0x' + s, 0) == -n && ('-0x' + s).to_i(0) == -n
scanner = StringScanner.new(s + '!')
raise 'scanner' unless scanner.scan_integer(base: 16) == n && scanner.pos == 2000 && scanner.rest == '!'
raise 'zero normalization' unless Integer('0_' * 100 + '0', 16) == 0
GC.start
raise 'result lifetime' unless scanner.matched == s && n.to_s(16) == s.downcase
puts 'large integer parsing: values, separators, errors and lifetimes preserved'

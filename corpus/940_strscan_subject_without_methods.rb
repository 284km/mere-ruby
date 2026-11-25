require 'strscan'

# A native StringScanner reads the subject without sending it nil?. This
# still holds when its singleton class hides every inherited method.
[false, true].each do |fixed|
  string = +'abcädeföghi'
  scanner = StringScanner.new(string, fixed_anchor: fixed)
  class << string
    undef_method(*instance_methods)
  end
  p [scanner.charpos, scanner.scan_until(/ä/), scanner.charpos,
     scanner.scan_until(/ö/), scanner.charpos]
  p [scanner.rest, scanner.peek(2), scanner.peek_byte, scanner.get_byte,
     scanner.pre_match, scanner.post_match, scanner.eos?]
end

string = +'abc'
def string.nil?
  raise 'subject nil? must not be called'
end
scanner = StringScanner.new(string)
p [scanner.scan(/a/), scanner.charpos]

scanner = StringScanner.allocate
[:eos?, :scan].each do |method|
  begin
    method == :scan ? scanner.scan(/a/) : scanner.eos?
  rescue ArgumentError => error
    p [method, error.class, error.message]
  end
end

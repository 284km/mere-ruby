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

# Saved native readers keep their definition after Ruby replaces the name.
readers = [:length, :bytesize, :byteslice, :[], :getbyte, :encoding].map { |name| String.instance_method(name) }
subject = "éab"
arguments = [[], [], [0, 2], [0, 1], [0], []]
readers.zip(arguments).each do |reader, args|
  value = reader.bind_call(subject, *args)
  p(value.is_a?(String) ? value.bytes : value)
end
subject.define_singleton_method(:bytesize) { raise 'subject predicate' }
p readers[1].bind_call(subject)
class String
  alias_method :original_byte_size940, :bytesize
  def bytesize = raise('replaced predicate')
end
p readers[1].bind_call(subject)
class String
  alias_method :bytesize, :original_byte_size940
end

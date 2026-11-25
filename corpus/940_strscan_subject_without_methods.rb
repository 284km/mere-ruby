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

# concat uses the captured native append, including for overridden receivers.
class Logged940 < String
  def <<(other) = super
end
class RejectAppend940 < String
  def <<(other) = raise('subject append override')
end
[Logged940.new('ab'), RejectAppend940.new('ab'), +'ab'].each do |subject|
  if subject.instance_of?(String)
    def subject.<<(other) = raise('singleton append override')
  end
  scanner = StringScanner.new(subject)
  p [(scanner << 'cd').equal?(scanner), subject, scanner.rest, scanner.scan(/\w+/)]
  p [scanner.concat('ef').equal?(scanner), scanner.string, scanner.rest]
end
append940 = String.instance_method(:<<)
subject940 = Logged940.new('ab')
p [append940.bind_call(subject940, 'cd').equal?(subject940), subject940]
p [append940.bind(subject940).call('ef').equal?(subject940), subject940]
subject940 = Logged940.new('ab').freeze
begin
  append940.bind_call(subject940, 'cd')
rescue FrozenError => error
  p [error.class, error.receiver.equal?(subject940), subject940]
end
[[], ['c', 'd']].each do |args|
  begin
    append940.bind_call(subject940, *args)
  rescue => error
    p [error.class, error.message]
  end
end
converter940 = Object.new
def converter940.to_str = 'cd'
subject940 = Logged940.new('ab')
p [append940.bind_call(subject940, converter940).equal?(subject940), subject940]
subject940 = Logged940.new('ab')
p [append940.bind_call(subject940, 99).equal?(subject940), subject940]

subject940 = Logged940.new('ab')
p [append940.bind_call(subject940, 'cd') { raise 'ignored block' }.equal?(subject940), subject940]
converter940 = Object.new
subject940 = Logged940.new('ab')
converter940.define_singleton_method(:to_str) { subject940.freeze; 'cd' }
begin
  append940.bind_call(subject940, converter940)
rescue FrozenError => error
  p [error.class, error.receiver.equal?(subject940), subject940]
end

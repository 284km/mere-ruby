# A fresh keyword packet may become **kwargs, but a borrowed packet must
# retain independent state when it is forwarded or reused by another call.
def keyword_rest_only(**kwargs) = kwargs
plain_keyword_rest = proc { |**kwargs| kwargs }
lambda_keyword_rest = ->(**kwargs) { kwargs }
source = {a: 1, b: 2}
[method(:keyword_rest_only), plain_keyword_rest, lambda_keyword_rest].each_with_index do |callable, index|
  value = callable.call(**source)
  value[:a] = 9
  p [:separate_source, index, value, source, value.class, Hash.ruby2_keywords_hash?(value)]
end
class KeywordOwnershipHash < Hash
  def dup = raise('user dup called')
  def initialize_copy(other) = raise('user copy hook called')
end
subclass = KeywordOwnershipHash.new(:default)
subclass[:a] = 3
p [:subclass, keyword_rest_only(**subclass), subclass.default]
def mutating_keyword_rest(**kwargs)
  kwargs.delete(:a)
  kwargs
end
def repeated_keyword_forwarding(...)
  [mutating_keyword_rest(...), keyword_rest_only(...)]
end
p [:repeated_forward, repeated_keyword_forwarding(a: 4, b: 5)]
def mixed_keyword_rest(a:, b: 6, **kwargs) = [a, b, kwargs]
p [:mixed, mixed_keyword_rest(a: 7, c: 8)]
# Reusing the returned Hash positionally must not turn it into keywords.
returned = keyword_rest_only(a: 9)
begin
  keyword_rest_only(returned)
rescue ArgumentError => error
  p [:positional, error.class, error.message]
end
# A captured keyword rest survives GC and is independent of later calls.
def capture_keyword_rest(**kwargs)
  -> { GC.start; kwargs }
end
kept = capture_keyword_rest(a: 'retained')
capture_keyword_rest(a: 'other')
GC.start
p [:captured, kept.call]
# A block conversion can run Ruby after the packet is created.
converter = Object.new
def converter.to_proc
  keyword_rest_only(a: :nested)
  proc {}
end
p [:conversion, keyword_rest_only(a: 10, &converter)]
# Measure real allocations after setup, with a supplied count table.
$keyword_rest_counts = {}
def measure_keyword_rest(label)
  ObjectSpace.count_objects($keyword_rest_counts)
  before = $keyword_rest_counts[:T_HASH]
  value = yield
  ObjectSpace.count_objects($keyword_rest_counts)
  p [label, $keyword_rest_counts[:T_HASH] - before, value]
end
empty = {}
GC.start
GC.disable
measure_keyword_rest(:method_hashes) { keyword_rest_only(a: 11) }
measure_keyword_rest(:proc_hashes) { plain_keyword_rest.call(a: 12) }
measure_keyword_rest(:lambda_hashes) { lambda_keyword_rest.call(a: 13) }
measure_keyword_rest(:empty_hashes) { keyword_rest_only(**empty) }
GC.enable

# A packet exposed before binding is borrowed, so conversion callbacks cannot
# keep an alias to the Hash the keyword-rest target receives.
$keyword_escape_marker = Object.new
$keyword_escape_seen = []
def find_keyword_packet_escape
  ObjectSpace.each_object(Hash) do |hash|
    if hash.key?(:keyword_escape_marker) && hash[:keyword_escape_marker].equal?($keyword_escape_marker)
      $keyword_escape_seen << hash
    end
  end
end
escape_converter = Object.new
def escape_converter.to_proc
  find_keyword_packet_escape
  proc {}
end
escaped_result = keyword_rest_only(keyword_escape_marker: $keyword_escape_marker, &escape_converter)
p [:conversion_alias, $keyword_escape_seen.any? { |hash| hash.equal?(escaped_result) }]
$keyword_escape_seen.clear
def keyword_default_escape(first = find_keyword_packet_escape, **kwargs) = kwargs
escaped_default = keyword_default_escape(keyword_escape_marker: $keyword_escape_marker)
p [:default_alias, $keyword_escape_seen.any? { |hash| hash.equal?(escaped_default) }]

# Hash-key callbacks can observe the completed keyword Hash during seeding.
# Ruby gives the target that same Hash; a pre-seeding exposure must not force
# a later copy, unlike a block-conversion exposure after packet construction.
$seed_marker = Object.new
$seed_seen = []
$seed_busy = false
class SeedEscapeKey
  def hash
    unless $seed_busy
      $seed_busy = true
      ObjectSpace.each_object(Hash) do |hash|
        if hash.key?(:keyword_escape_marker) && hash[:keyword_escape_marker].equal?($seed_marker)
          $seed_seen << hash
        end
      end
      $seed_busy = false
    end
    17
  end
  def eql?(other) = equal?(other)
end
def seed_keyword_target(**kwargs) = kwargs
key = SeedEscapeKey.new
result = seed_keyword_target(:keyword_escape_marker => $seed_marker, key => :value)
p [:seed_alias, $seed_seen.any? { |hash| hash.equal?(result) }]

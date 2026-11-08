require 'psych'

source = "- &id001\n  a: b\n- *id001\n"
value = Psych.parse(source).transform
p value
p value[0].equal?(value[1])
value = Psych.parse("--- &root\n- *root\n").to_ruby
p value.equal?(value[0])
value = Psych.parse("---\na: &entry []\nb: *entry\n").transform
p value['a'].equal?(value['b'])

# Parsing, including early returns and exceptions, must not enable aliases in
# subsequent safe loads or retain anchors across documents.
[source, '', '--- *missing'].each do |input|
  begin
    node = Psych.parse(input)
    p node ? node.transform.class : node
  rescue Psych::BadAlias => error
    p error.class.to_s
  end
  begin
    Psych.safe_load(source)
  rescue Psych::BadAlias => error
    p error.class.to_s
  end
end
begin
  Psych.parse('--- *id001').transform
rescue Psych::BadAlias => error
  p error.class.to_s
end

# This is the load/parse/emit sequence used by upstream test_yaml's helper.
# Previously the safe-loader exception also escaped parse().transform, so the
# helper kept retrying the whole assertion until the memory limit was reached.
expected = [{'a' => 'b'}] * 2
p Psych.unsafe_load(source) == expected
p Psych.parse(source).transform == expected
p Psych.unsafe_load(Psych.dump(expected)) == expected
p Psych.parse(Psych.dump(expected)).transform == expected

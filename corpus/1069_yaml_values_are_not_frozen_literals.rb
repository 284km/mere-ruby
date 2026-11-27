# The embedded Psych is one source with `# frozen_string_literal: true` at its
# top, as each of Psych's own files has (note 559 §10: without it the
# scanner's `c == "\n"` made a new String a byte). What a load returns is
# still the program's to change: an empty scalar, a block scalar, a quoted
# one, a tag's and an anchor's values -- none of them frozen.
require "yaml"
doc = YAML.load(<<~Y, aliases: true)
  empty:
  quoted: ''
  dq: ""
  plain: word
  block: |
    line
  folded: >-
    a
    b
  stripped: |-
  list: [x, '', "y"]
  tagged: !!str 12
  etag: !!str
  anchor: &a shared
  again: *a
Y
doc.each do |k, v|
  vs = v.is_a?(Array) ? v : [v]
  vs.each { |s| next unless s.is_a?(String); s << "!" }
end
p doc
p doc.values.flatten.select { |v| v.is_a?(String) }.map(&:frozen?).uniq
p YAML.load("--- ''\n").frozen?, YAML.load("---\n").inspect, YAML.load("a: |+\n\n").values.map(&:frozen?)
# what Psych emits: a String with variables, a String subclass, symbols
class Tag1069 < String; end
s = +"text"
s.instance_variable_set(:@note, "n")
out = YAML.dump({ "s" => s, "t" => Tag1069.new("sub"), sym: :v, "e" => "", "nl" => "a\nb" })
puts out
back = YAML.unsafe_load(out)
p back["s"].instance_variable_get(:@note), back["t"].class, back[:sym], back["e"].frozen?, back["nl"]
p Psych.parse_stream("- a\n- b\n").to_ruby, YAML.load_stream("--- 1\n--- two\n")

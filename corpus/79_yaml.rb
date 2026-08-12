# YAML is a C extension in CRuby (psych.so). Here it is a loader subset
# shipped as Ruby source: block mappings and sequences, flow collections, the
# implicit scalar types, comments and multiple documents. No emitter, no
# anchors, no tags -- see KNOWN_GAPS.md.
require "yaml"

DOCS = [
  "---\n1:\n  :name: hokkaido\n  :area: north\n2:\n  :name: aomori\n  :area: tohoku\n",
  "---\n1:\n- - 10000\n  - 70895\n- - 400000\n  - 996509\n2:\n- - 185501\n  - 185501\n",
  "a: 1\nb: two\nc: true\nd: false\ne: ~\nf: 1.5\ng: \"quoted # not comment\"\nh: 'single'\n",
  "- 1\n- 2\n- three\n",
  "top:\n  mid:\n    leaf: 9\n  other: 3\n",
  "list:\n  - a\n  - b\nmap:\n  x: 1\n",
  "# a comment\n---\nk: v   # trailing\n",
  "flow: [1, 2, three]\nfmap: {a: 1, b: two}\n",
  "empty:\nnested:\n  - k: 1\n    j: 2\n  - k: 3\n",
  # YAML 1.1: a float needs a decimal point AND a signed exponent, so
  # "1e3" and "1.0e3" stay Strings while "1.0e+3" is a Float
  "n: -12\nbig: 1e3\nplain: 1.0e3\nreal: 1.0e+3\nlow: 1.0E-3\nneg: -0.5\nsym: :foo\nstr: plain words here\n",
  "inf: .inf\nninf: -.inf\nhalf: .5\nwhole: 5.\n",
  "TRUE: True\nNULL: Null\nesc: \"a\\tb\\nc\"\n",
]
DOCS.each_with_index { |d, i| p [i, YAML.load(d)] }

p YAML.load("").inspect
p YAML.load_stream("---\na: 1\n---\nb: 2\n")
p Psych.equal?(YAML)
p YAML.safe_load("x: 1")
p YAML.load("k: v", symbolize_names: true)

# a round trip through a real file
path = "/tmp/mrb_corpus.yml"
File.write(path, "---\nname: mere\nlist:\n  - 1\n  - 2\nnested:\n  a: true\n")
p YAML.load_file(path)
File.delete(path)

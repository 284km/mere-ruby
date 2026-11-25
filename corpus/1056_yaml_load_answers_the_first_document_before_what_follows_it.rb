# YAML.load answers the FIRST document. libyaml ends a document before it
# looks for the start of the next one, so Psych's handler has the first
# document whole and Psych.parse returns from its block there; what follows
# it is never read. Only a reader of the whole stream (load_stream) meets the
# error.
#
# activerecord's yaml_column_test writes its YAML in single quotes,
#
#   '--- !ruby/object:DoesNotExistAndShouldntEver {}\n'
#
# so a backslash and an `n` follow the mapping. The parser reported them as
# "did not find expected <document start>" before the document's end was
# announced, where ruby raises for the unknown class.
require "yaml"
def t
  yield
rescue => e
  e.class
end
y = '--- !ruby/object:DoesNotExistAndShouldntEver {}\n'
p t { YAML.load(y) }
p t { YAML.unsafe_load(y) }
p t { YAML.safe_load(y) }
p t { YAML.load('--- {}\n') }
p t { YAML.load('--- [1, 2]\n') }
p t { YAML.parse('--- [1]\n').to_ruby }
p t { YAML.load("--- {a: 1} trailing") }
# the whole stream is an error
p t { YAML.load_stream('--- {}\n') }
p t { YAML.parse_stream('--- [1]\n') }
# ...and the documents before it were handed over
seen = []
p t { YAML.load_stream('--- [1]\n') { |d| seen << d } }, seen
# well-formed streams are as they were
p YAML.load("--- 1\n--- 2\n"), YAML.load_stream("--- 1\n--- 2\n"), YAML.load("a: 1\n"), YAML.load("")

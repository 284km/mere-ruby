# Every primitive method used to ignore whatever it was handed: `"bad".to_s(123)`
# answered "bad" and `[].size(1)` answered 0, where Ruby raises. Ignoring an
# argument is a wrong answer twice over -- the call was a mistake, and the
# mistake is invisible.
#
# The list of zero-argument methods is the oracle's: CRuby was asked which
# (name, class) pairs answer "wrong number of arguments", rather than which ones
# raise ArgumentError -- `5.to_s(99)` raises that for an invalid radix and DOES
# take an argument. That distinction is why Integer#to_s, String#to_i, #chomp
# and the rest of the optional-argument family still accept theirs.
def t(label); r = yield; puts "#{label}: #{r.inspect}"; rescue => e; puts "#{label}: #{e.class}: #{e.message}"; end

t("str.to_s(1)")    { "a".to_s(1) }
t("str.length(1)")  { "a".length(1) }
t("str.empty?(1)")  { "a".empty?(1) }
t("str.strip(1)")   { " a ".strip(1) }
t("str.chars(1)")   { "a".chars(1) }
t("arr.size(1)")    { [1].size(1) }
t("arr.sort(1)")    { [1].sort(1) }
t("hash.keys(1)")   { {a: 1}.keys(1) }
t("nil.to_a(1)")    { nil.to_a(1) }
t("int.abs(1)")     { (-1).abs(1) }
t("int.even?(1)")   { 2.even?(1) }
t("sym.to_s(1)")    { :s.to_s(1) }
t("float.abs(1)")   { 1.5.abs(1) }
t("obj.frozen?(1)") { "a".frozen?(1) }

# the ones that DO take an argument still do
t("int.to_s(2)")    { 5.to_s(2) }
t("int.to_s(36)")   { 5.to_s(36) }
t("int.to_s(99)")   { 5.to_s(99) }
t("int.to_s(1)")    { 5.to_s(1) }
t("str.to_i(16)")   { "ff".to_i(16) }
t("str.chomp('c')") { "abc".chomp("c") }
t("str.upcase")     { "a".upcase }
t("str.upcase(:ascii)") { "a".upcase(:ascii) }
t("str.upcase(1)")  { "a".upcase(1) }
t("arr.first(1)")   { [1,2].first(1) }
t("arr.sum(10)")    { [1,2].sum(10) }

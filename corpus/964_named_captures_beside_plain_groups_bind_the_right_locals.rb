# `/literal/ =~ str` binds a local for each named group. Beside a named
# group a plain paren does not capture, so it has no number -- but it was
# counted when the locals were bound, and each local got the capture of the
# group after it. The sqlite3 adapter reads an index that way:
#   /\bON\b\s*"?(\w+?)"?\s*\((?<expressions>.+?)\)(?:\s*WHERE\b\s*(?<where>.+?))?.../im =~ index_sql
# `expressions` was the WHERE clause or nil, and every table with an
# expression index or a partial index failed to load its indexes.
def idx(index_sql)
  /\bON\b\s*"?(\w+?)"?\s*\((?<expressions>.+?)\)(?:\s*WHERE\b\s*(?<where>.+?))?(?:\s*\/\*.*\*\/)?\s*\z/im =~ index_sql
  [expressions, where]
end
[
  'CREATE INDEX expression on ex (number % 10)',
  'CREATE INDEX expression on ex (number % 10) /* comment */',
  'CREATE INDEX "expression" ON "ex" (id % 10, max(id, number)) WHERE id > 1000',
  "CREATE INDEX expression ON ex (\n  id % 10,\n  max(id, number))\nWHERE\n  id > 1000",
  'CREATE UNIQUE INDEX "index_ex_on_number" ON "ex" ("number")',
  'CREATE INDEX "partial" ON "ex" ("id") WHERE number > 100',
  'no index here',
  # nil does not match: the locals are nil, not unbound
  nil,
].each { |s| p idx(s) }

# plain groups before, between and after; nested; a non-capturing group
if /(a)(?<x>b)(c)(?<y>d)(e)/ =~ "abcde"
  p [x, y, $~.captures, $~.names, $1, $2, $3]
end
if /((?<inner>\d)(\d))+(?<out>z)?/ =~ "12"
  p [inner, out, $~.to_a]
end
/(?:q)(?<only>r)/ =~ "qr"
p only
# a failed match leaves the locals nil and $~ nil
/(z)(?<m1>y)/ =~ "abc"
p m1, $~
/(?<n1>a)/ =~ "a"
p n1, $~[0]
/(?<n2>b)/ =~ nil
p n2, $~
# a Symbol on the right
/(s)(?<sy>y)/ =~ :sym
p sy

# \k<name> in a replacement names the same group
p "x on ex (a)".sub(/(\w+) (?<n>\w+)/, '<\k<n>>'), "ab".gsub(/(a)(?<b>b)/, '\k<b>\k<b>')
# without a named group, plain parens are numbered as ever
/(a)(b)/ =~ "ab"
p $1, $2, "ab".sub(/(a)(b)/, '\2\1')

# nil (or what is no string) on the other side is a match that failed: $~ is
# nil after it, whichever way the match was asked
r = /(?<q>a)/
checks = [
  -> { r =~ nil }, -> { r === nil }, -> { r === 5 }, -> { r.match(nil) }, -> { r.send(:=~, nil) },
  -> { case nil when r then 1 end }, -> { case Object.new when r then 1 end },
]
p checks.map { |c| r =~ "a"; [c.call, $~] }
# ...but these two do not touch it
r =~ "a"; p r.match?(nil), $~[0]
r =~ "a"; p((nil =~ r), $~[0])

# A Regexp's own singleton methods, and a Regexp subclass instance handed to
# the builtins that take a pattern.

def show(label)
  r = yield
  puts "#{label}: #{r.inspect}"
rescue => e
  puts "#{label}: #{e.class}: #{e.message}"
end

# String#match / Symbol#match ask the pattern's own #match, and yield its
# answer to a block
o = Regexp.new("foo")
def o.match(x, y, z) = x + y + z
show("String#match") { "foo".match(o, "bar", "baz") }
show("Symbol#match") { :foo.match(o, "bar", "baz") }
show("with a block") { r = nil; "foo".match(o, "bar", "baz") { |y| r = y }; r }
show("singleton_methods") { o.singleton_methods }
show("plain match still") { "foobar".match(/bar/)[0] }

# grep asks the pattern's own ===
# (a pattern no literal below shares: mere-ruby keys a Regexp's singleton by
#  its value, so an equal literal would share it -- note 460)
always = Regexp.new("never-written-literally")
def always.===(other) = true
show("grep") { [1, :a, "b"].grep(always) }
show("grep_v") { [1, :a, "b"].grep_v(always) }
show("plain grep") { %w[ax by cx].grep(/x/) }

# a Regexp subclass instance is the Regexp it holds
class MyRe < Regexp; end
m = MyRe.new("o+")
show("match") { "foo".match(m)[0] }
show("match?") { "foo".match?(m) }
show("=~") { "xoo" =~ m }
show("gsub") { "foo".gsub(m, "0") }
show("sub") { "foo".sub(m) { |s| s.upcase } }
show("scan") { "foo boo".scan(m) }
show("split") { "aoob".split(m) }
show("grep") { %w[a oo b].grep(m) }
show("index") { "xfoo".index(m) }
show("own ===") { m === "boo" }

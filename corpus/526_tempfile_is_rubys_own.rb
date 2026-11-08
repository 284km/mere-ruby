# Tempfile is ruby 4.0.9's lib/tempfile.rb; a File's clone is its own copy.
require "tempfile"

def show(label)
  v = yield
  puts "#{label}: #{v.inspect}"
rescue Exception => e
  puts "#{label}: #{e.class}: #{e.message}"
end

t = Tempfile.new("foo")
path = t.path
show("basename") { File.basename(path).start_with?("foo") }
t.write("abc")
t.close
show("closed, still there") { File.exist?(path) }
t.unlink
show("unlinked") { [File.exist?(path), t.path] }

t = Tempfile.new(["bar", ".txt"])
show("suffix") { File.extname(t.path) }
p2 = t.path
t.close!
show("close!") { [File.exist?(p2), t.path] }

t = Tempfile.new("dup")
d = t.dup
d.close
show("dup closed alone") { [d.closed?, t.closed?] }
c = t.clone
c.close
show("clone closed alone") { [c.closed?, t.closed?] }
t.close(true)

show("open block") { Tempfile.open("blk") { |f| f.class } }
show("reopen") do
  Tempfile.open("ro") do |f|
    f.print "x"
    g = f.open
    [g.class, g.read]
  end
end
show("create block") { Tempfile.create("cr") { |f| [f.class, File.exist?(f.path)] } }

shown = nil
r = Tempfile.create(anonymous: true) do |f|
  shown = f.path
  f.puts "foo"
  f.rewind
  [f.class, f.read, f.stat.mode & 0777]
end
show("anonymous") { [r, shown.end_with?("/")] }

f = File.open(__FILE__)
g = f.clone
g.close
show("File#clone") { f.closed? }
show("clone freeze") { f.clone(freeze: true).frozen? }
f.close

# ...and a lone splat on the right of a multiple assignment asks a builtin's
# to_a: an Enumerator, a Hash, a Range (a String has none)
e = [1, 2, 3].each
a, b = *e
show("splat enumerator") { [a, b] }
a, b = *{k: 1}
show("splat hash") { [a, b] }
a, b = *(4..5)
show("splat range") { [a, b] }
a, b = *"str"
show("splat string") { [a, b] }
a, b = *nil
show("splat nil") { [a, b] }

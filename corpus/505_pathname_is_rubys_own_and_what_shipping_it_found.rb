# Pathname is ruby 4.0's own pathname_builtin.rb, shipped byte for byte (note
# 511's stage 3: test/pathname 144 -> 285 of 287). What running it found in
# the interpreter: Module#method_defined? with the ancestors left out counted
# Object's builtins (so the file's Ruby <=> and sub were never defined), an
# object without #to_path or #to_str was a NoMethodError from File.path, a
# plain object answered `=~` with nil (Object#=~ is gone since ruby 3.2), a
# Proc's #binding was a snapshot (local_variable_set and `eval("$~ = m",
# blk.binding)` wrote into a copy), an eval under a binding ran under the
# caller's `$~` frame instead of the binding's, and a stat under an
# unsearchable directory was ENOENT where it is EACCES.
require "pathname"
require "tmpdir"

p Pathname.new("a//b/../c").cleanpath, Pathname.new("a//b/../c").cleanpath(true)
%w[/ // . .. a /. /.. a/ a//b a/. ./a ../a /../a /a/.. /a/b/../c a/b/../.. a/.. ../.. ../a/..].each do |s|
  print s.inspect, " ", Pathname.new(s).cleanpath.to_s.inspect, " ", Pathname.new(s).cleanpath(true).to_s.inspect, "\n"
end
p Pathname("/").root?, Pathname("//").root?, Pathname("/a").root?, Pathname("").root?
p Pathname(".").parent, Pathname("/").parent, Pathname("a/b").parent, Pathname("a").parent
p Pathname("/a/b/c").relative_path_from("/a/d"), Pathname("/../a").relative_path_from("/b"), Pathname("a").relative_path_from("a")
p((Pathname("/a").relative_path_from("b") rescue $!.message))
p Pathname("/x/y/z").descend.to_a, Pathname("/x/y/z").ascend.to_a, Pathname("x/y").descend.map(&:to_s)
p Pathname("a") + "b", Pathname("a") + "../b", Pathname("a") + "/b", Pathname("/") + "..", Pathname("a") + "..", Pathname("..") + "a"
p Pathname("a").join("b", "c"), Pathname("a").join("/b", "c"), Pathname("/a").join
p Pathname("foo.rb").sub_ext(".txt"), Pathname("foo").sub_ext(".txt"), Pathname("foo.tar.gz").sub_ext(""), Pathname("a.b/c").sub_ext(".x")
p Pathname("abc.gif").sub(/\..*/) { $~[0].upcase }, Pathname("abc").sub("b", "B"), Pathname("abc").sub(/c/, "C")
p Pathname("a/b/c").each_filename.to_a, Pathname("/a/b").each_filename.to_a
p Pathname("a/b/c").basename, Pathname("a/b/c.rb").basename(".rb"), Pathname("a/b/c").dirname, Pathname("a/b/c.rb").extname, Pathname("a/b/c").split
p Pathname("b") <=> Pathname("a"), Pathname("a/b") <=> Pathname("a-b"), Pathname("a") <=> "a", [Pathname("b"), Pathname("a"), Pathname("a/b")].sort
p Pathname("a") == Pathname("a"), Pathname("a").eql?(Pathname("a")), Pathname("a").hash == Pathname("a").hash, Pathname("a") == "a"
p((Pathname("a") =~ /a/ rescue $!.class), (Pathname.new(Object.new) rescue $!.message), (Pathname.new(nil) rescue $!.class), (Pathname.new("a\0b") rescue $!.class))
p Pathname("a").frozen?, Pathname("a").freeze.to_s.frozen?, Pathname("a").to_s.frozen?
p Kernel.Pathname("x"), Pathname(Pathname("y")).equal?(Pathname("y")), Pathname("a").inspect, Pathname("a").to_path
p Pathname("a").relative?, Pathname("/a").absolute?, Pathname("a/").to_s, Pathname("a").mountpoint?
class O; def to_path = "from_to_path"; end
class S; def to_str = "from_to_str"; end
p Pathname(O.new), Pathname(S.new), File.path(O.new), File.path(S.new), (File.path(Object.new) rescue $!.message)
Dir.mktmpdir("pn") do |dir|
  Dir.chdir(dir) do
    Dir.mkdir("d"); File.write("d/x", "1\n2\n"); Dir.mkdir("d/e")
    pn = Pathname("d")
    p pn.children.sort, pn.children(false).sort, pn.entries.sort, pn.each_child.to_a.sort.size, pn.directory?, pn.exist?, pn.file?
    p Pathname("d/x").read, Pathname("d/x").readlines, Pathname("d/x").each_line.to_a, Pathname("d/x").size, Pathname("d/x").empty?, Pathname("d/e").empty?
    p pn.glob("*").sort, Pathname.glob("d/*").sort, pn.find.map(&:to_s).sort
    Pathname("d/n").mkpath; p Pathname("d/n").directory?; Pathname("d/n").rmtree; p Pathname("d/n").exist?
    Pathname("d/m").mkdir; Pathname("d/m").rmdir; Pathname("d/x").unlink; p pn.children.map(&:to_s)
    Pathname("d/w").write("w"); p Pathname("d/w").read, Pathname("d/w").realpath == Pathname(File.realpath("d/w")), Pathname("d/nope").realdirpath.basename
    File.chmod(0, "d")
    p((File.lstat("d/w").class rescue $!.class), (File.stat("d/w").class rescue $!.class))
    File.chmod(0755, "d")
    tmp = Pathname.mktmpdir; p tmp.directory?; tmp.rmtree
  end
end
# Module#method_defined? with the ancestors left out
class MD; def own; end; end
p MD.method_defined?(:own, false), MD.method_defined?(:to_s, false), MD.method_defined?(:to_s), MD.method_defined?(:<=>, false), MD.method_defined?(:sub, false)
p String.method_defined?(:sub, false), Integer.method_defined?(:<=>, false), Hash.method_defined?(:each, false), Object.method_defined?(:to_s, false)
# Proc#binding is live
def with_block(&b)
  b.binding.local_variable_set(:seen, 1)
  eval("$~ = 'hit'.match(/hit/)", b.binding)
  yield
end
def caller_frame
  seen = 0
  with_block { p [seen, $~ && $~[0]] }
  p [seen, $~ && $~[0]]
end
caller_frame
"top" =~ /top/
with_block { p [:top_block, $~[0]] }
p $~[0]
def raising(&b)
  eval("raise 'in binding'", b.binding)
rescue => e
  p [e.message, $~ && $~[0]]
end
raising { }
p $~[0]

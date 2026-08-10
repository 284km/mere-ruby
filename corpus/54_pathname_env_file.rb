# Pathname ships as source (there is no stdlib to load it from), and the
# File / ENV pieces it leans on.

require "pathname"

a = Pathname.new("/usr/local/lib")
p a.to_s, a.basename.to_s, a.dirname.to_s, a.extname, a.absolute?, a.relative?, a.root?
p((a + "ruby").to_s, (a / "x.rb").to_s, a.join("a", "b").to_s)
p Pathname.new("rel").to_s, Pathname.new("rel").absolute?
p Pathname.new("a/b/../c/./d").cleanpath.to_s
p Pathname.new("/a/b/c/d").relative_path_from(Pathname.new("/a/b")).to_s
p Pathname.new("/a/b").relative_path_from(Pathname.new("/a/b/c/d")).to_s
p Pathname.new("x/y.tar.gz").sub_ext(".zip").to_s
p Pathname.new("/a/b") == Pathname.new("/a/b"), Pathname.new("/a") == "/a"
p [Pathname.new("/b"), Pathname.new("/a")].sort.map(&:to_s)
p Pathname.new("/x").split.map(&:to_s)
p Pathname.new("a/b").parent.to_s
segs = []
Pathname.new("/a/b/c").each_filename { |x| segs << x }
p segs
p Pathname("q").class, Pathname(Pathname.new("q")).to_s
p Pathname.new("/a").inspect

# File path helpers, including the edges Pathname exercises
p File.dirname("/x"), File.dirname("/"), File.dirname("x"), File.dirname("a/b")
p File.dirname("/a/b"), File.dirname("a/"), File.dirname(""), File.dirname("/a/b/")
p File.basename("/x"), File.basename("a/"), File.basename("/")
p File.basename("a/b.rb", ".rb"), File.basename("a/b.rb", ".*"), File.basename("b", ".rb")
p File.basename("a/b.tar.gz", ".*"), File.basename(".x", ".*")
p File.extname("a/b.tar.gz"), File.extname("a/b"), File.extname(".bashrc")
p File.extname("a.b/c"), File.extname("x.")
p File.absolute_path("/y"), File.absolute_path("z", "/base")

# ENV is a real table: reads, writes, and the whole-hash forms
h = ENV.to_hash
p h.class, h["PATH"] == ENV["PATH"], ENV.keys.size == h.size
ENV["MRB_CORPUS_A"] = "1"
p ENV["MRB_CORPUS_A"], ENV.to_h["MRB_CORPUS_A"], ENV.keys.include?("MRB_CORPUS_A")
ENV.update("MRB_CORPUS_B" => "2")
p ENV["MRB_CORPUS_B"], ENV.to_a.assoc("MRB_CORPUS_A")
ENV.delete("MRB_CORPUS_A")
p ENV["MRB_CORPUS_A"], ENV.key?("MRB_CORPUS_A")
ENV.replace(h)
p ENV["MRB_CORPUS_B"], ENV["PATH"] == h["PATH"], ENV.empty?

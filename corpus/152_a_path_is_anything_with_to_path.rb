# In ruby a path argument is any object that answers #to_path -- Pathname above
# all. bundler writes its lockfile as
#   filesystem_access(file) { |p| File.open(p, "wb") { |f| f.puts(contents) } }
# where p is a Pathname, so refusing one stopped Bundler.setup, and the refusal
# arrived at the top as an interpreter message because a primitive that cannot
# open a file has no ruby exception of its own.
require "pathname"
dir = Pathname.new("corpus")
pn = dir + "zzz_to_path.txt"

p [pn.class, pn.to_s, pn.respond_to?(:to_path)]
File.open(pn, "wb") { |f| f.puts("written through a Pathname") }
p File.read(pn)
p File.exist?(pn)
p File.size(pn)
p File.basename(pn)
p File.extname(pn)
File.write(pn, "written by File.write\n")
p File.readlines(pn)
p File.open(pn) { |f| f.read }
p IO.read(pn)

# an object of one's own, answering only #to_path, is a path too
class MyPath
  def initialize(s); @s = s; end
  def to_path; @s; end
end
mine = MyPath.new(pn.to_s)
p File.read(mine)
p File.exist?(mine)

# the open itself is where ruby reports a path it cannot write
begin
  File.open(Pathname.new("corpus/no_such_dir_zzz/x.txt"), "wb") { |f| f.puts("x") }
rescue SystemCallError => e
  p [e.class, e.message]
end
begin
  File.open("corpus/no_such_dir_zzz/y.txt", "a") { |f| f.puts("y") }
rescue SystemCallError => e
  p [e.class, e.message]
end

# ... and a read of a missing path still names it
begin
  File.read(Pathname.new("corpus/no_such_file_zzz.txt"))
rescue Errno::ENOENT => e
  p [e.class, e.message]
end
File.delete(pn)
p File.exist?(pn)

# Witness for the core/file, core/filetest, core/file/stat and core/dir arc:
# the answers ruby gives, in the shapes ruby/spec asks for them.
require "tmpdir"

# a class's own method_missing is asked, as an instance's is
class FS
  def self.method_missing(m, *a) = [m, a]
end
p FS.directory?("x"), FS.size

Dir.mktmpdir("mr320") do |t|
  Dir.chdir(t) do
    %w[a a/b .hid brace].each { |d| Dir.mkdir(d) }
    %w[a/b/c.rb a/d.rb e.rb .hid/f.rb brace/x.js.rjs brace/x.html.erb].each { |f| File.write(f, "12345678") }
    # a write into a directory that is not there is ENOENT
    p((File.write("zz/y", "1") rescue $!.class))
    File.symlink("a", "ln")

    # the predicates check their argument as rb_stat does
    p [File.exist?("e.rb"), FileTest.exist?("e.rb"), File.file?("/dev/null"), File.directory?("a")]
    [[], [nil], [1], ["e.rb", "a"]].each do |args|
      begin
        File.exist?(*args)
      rescue ArgumentError, TypeError => e
        p e.class
      end
    end
    p((File.size("nope") rescue $!.class), File.size?("e.rb"), File.zero?("e.rb"))

    # stat follows the link, lstat does not
    p [File.stat("ln").directory?, File.lstat("ln").symlink?, File.ftype("ln")]
    p File.realpath("ln/b") == File.realpath("a/b"), File.readlink("ln")

    # glob: "**" alone is "*", "**/" recurses real directories only, a
    # trailing "/" answers directories, braces keep their order
    p Dir.glob("**")
    p Dir.glob("**/*.rb")
    p Dir.glob("**/")
    p Dir.glob("ln/*/c.rb"), Dir.glob("*/b/c.rb")
    p Dir.glob("brace/x{.js,.html}{.erb,.rjs}")
    p Dir.glob(".*"), Dir.glob("*", File::FNM_DOTMATCH)
    p Dir.glob("*.rb", base: "a")

    # Dir#each reads from the top and leaves the position at the end
    d = Dir.new("a")
    p d.each { }.equal?(d), d.read, d.each.size
    d.close
    p d.close

    # utime sets both times
    File.utime(Time.at(1_000_000_000), Time.at(1_000_000_100), "e.rb")
    p [File.atime("e.rb").to_i, File.mtime("e.rb").to_i]
  end
end

# fnmatch is ruby's fnmatch, not glob's
p [File.fnmatch("**/*.rb", "main.rb"), File.fnmatch("**/*.rb", "main.rb", File::FNM_PATHNAME),
   File.fnmatch("*", "a/b"), File.fnmatch("*", "a/b", File::FNM_PATHNAME),
   File.fnmatch("[a-z]", "D", File::FNM_CASEFOLD), File.fnmatch("\\a", "\\a", File::FNM_NOESCAPE),
   File.fnmatch("c{at,ub}s", "cubs", File::FNM_EXTGLOB), File.fnmatch("nested/**", "nested/a/b", File::FNM_PATHNAME)]

# expand_path keeps a leading run of slashes and the argument's encoding
p File.expand_path("////a//b"), File.expand_path("/x/../y"), File.expand_path("a".encode("ISO-8859-1"), "/").encoding
p((File.expand_path("~no_such_user_mr320") rescue $!.class))
p File.absolute_path("~", "/")

# a binary path's Errno message is binary
e = Errno::ENOENT.new("/p\xE3".b)
p e.message.encoding, e.message.include?("/p\xE3".b)

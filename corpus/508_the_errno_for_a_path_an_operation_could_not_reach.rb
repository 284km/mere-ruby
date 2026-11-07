# The errno for a path an operation could not reach (note 511's stage 3:
# fileutils's rm_r without permissions, test_find's unreadable directory).
# Under a directory that cannot be searched (chmod 0) ruby says EACCES for
# open, read, unlink, chmod, rename, chown, readlink, utime, Dir.open and
# Dir.children -- this interpreter said ENOENT, ENOTDIR, or opened the Dir and
# listed nothing. A symbolic link that leads only to links is ELOOP for
# open/read/stat (ENOENT here). lchown works on a dangling link (the link
# itself is there). The file builtins hand back no errno, so it is worked
# out from the path, once, for all of them (fs_absent_name).
require "tmpdir"
require "find"
return if Process.uid == 0

def t
  yield
rescue SystemCallError => e
  [e.class, e.message.sub(/ - .*\z/, "")]
end

Dir.mktmpdir do |root|
  Dir.chdir(root) do
    Dir.mkdir("d")
    Dir.mkdir("d/sub")
    File.write("d/f", "x")
    File.write("d/sub/g", "x")
    File.symlink("loop", "loop")
    File.symlink("nowhere", "dangling")
    File.write("plain", "x")
    File.chmod(0, "d")
    begin
      p t { Dir.open("d") {} }, t { Dir.children("d") }, t { Dir.entries("d") }, t { Dir.each_child("d") {} }
      p t { File.open("d/f") {} }, t { File.read("d/f") }, t { File.open("d/f", "w") {} }, t { File.write("d/f", "y") }
      p t { File.stat("d/f") }, t { File.lstat("d/f") }, t { File.stat("d/sub/g") }, t { File.delete("d/f") }, t { File.unlink("d/sub/g") }
      p t { Dir.rmdir("d/sub") }, t { Dir.mkdir("d/n") }, t { File.chmod(0o644, "d/f") }, t { File.rename("d/f", "d/g") }, t { File.rename("plain", "d/g") }
      p t { File.chown(nil, nil, "d/f") }, t { File.lchown(nil, nil, "d/f") }, t { File.readlink("d/f") }, t { File.utime(0, 0, "d/f") }
      p File.exist?("d/f"), File.symlink?("d/f"), File.file?("d/f"), File.readable?("d/f")
      p t { Dir.open("d/sub") {} }, t { Find.find("d", ignore_error: false) { |f| } }, (a = []; Find.find("d") { |f| a << f }; a)
    ensure
      File.chmod(0o755, "d")
    end
    # a directory that is there and cannot be read: opendir's EACCES, before
    # the first entry
    File.chmod(0o300, "d")
    begin
      p t { Dir.open("d") { |x| x.read } }, t { Dir.children("d") }, File.exist?("d/f"), t { File.read("d/f") }
    ensure
      File.chmod(0o755, "d")
    end
    p t { File.open("loop") {} }, t { File.read("loop") }, t { File.stat("loop") }, File.lstat("loop").symlink?, t { File.readlink("loop") }
    p t { File.exist?("loop") }, t { File.chmod(0o644, "loop") }, t { File.utime(0, 0, "loop") }, t { File.delete("loop") }
    p t { File.chown(nil, nil, "dangling") }, t { File.lchown(nil, nil, "dangling") }, t { File.lutime(0, 0, "dangling") }, t { File.utime(0, 0, "dangling") }
    p t { File.stat("dangling") }, t { File.open("dangling") {} }, t { File.read("plain/x") }, t { File.open("plain/") {} }, t { Dir.open("plain") {} }
    p t { File.read("absent/x") }, t { File.delete("absent/x") }, t { File.rename("absent/x", "y") }, t { Dir.open("absent") {} }
  end
end

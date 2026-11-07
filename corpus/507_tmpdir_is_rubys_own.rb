# tmpdir is ruby's own lib/tmpdir.rb (note 511's stage 3): Dir.tmpdir walks
# the candidates ($TMPDIR, $TMP, $TEMP, the system's, /tmp, .) and warns
# about the ones it skips; Dir.mktmpdir cleans a traversal out of the prefix,
# refuses an empty parent, takes a [prefix, suffix] pair; File::Stat's
# world_writable? and world_readable? answer the permission bits (0777)
# alone, as ruby's do -- the sticky bit was in the answer before.
require "tmpdir"
require "stringio"

p Etc.systmpdir.is_a?(String), Dir.tmpdir.start_with?("/"), Dir.tmpdir.end_with?("/")

Dir.mktmpdir do |root|
  root = File.realpath(root)
  envs = %w[TMPDIR TMP TEMP]
  saved = envs.each_with_object({}) { |v, h| h[v] = ENV.delete(v) }
  begin
    file = File.join(root, "TMPDIR")
    File.write(file, "")
    ENV["TMPDIR"] = file
    ENV["TMP"] = root
    err = StringIO.new
    old = $stderr
    $stderr = err
    got = Dir.tmpdir
    $stderr = old
    p got == root, err.string.sub(root, "<root>")
    ENV["TMPDIR"] = ""
    p Dir.tmpdir == root
    ENV["TMPDIR"] = File.join(root, "absent")
    p Dir.tmpdir == root
    File.unlink(file)

    # a traversal in the prefix is cleaned out: the directory is made under
    # the parent, named from the letters alone
    d = Dir.mktmpdir("../../../foo") { |x| x }
    p File.dirname(d) == root, File.basename(d).start_with?("foo"), File.exist?(d)
    d = Dir.mktmpdir(["pre", "/../suf"]) { |x| x }
    p File.dirname(d) == root, File.basename(d).start_with?("pre"), File.basename(d).end_with?("suf")
    # the block's argument is a copy: mutating it does not move the cleanup
    kept = nil
    Dir.mktmpdir("m") { |x| kept = x.dup; x << "zzz" }
    p File.exist?(kept)
    # without a block the directory stays and is answered
    d = Dir.mktmpdir("keep")
    p File.directory?(d), File.stat(d).mode & 0o777
    FileUtils.remove_entry(d)
    p File.exist?(d)
    p((Dir.mktmpdir("foo", "") rescue $!.class), (Dir.mktmpdir("foo", Struct.new(:to_path).new("")) rescue $!.class))
    p((Dir.mktmpdir(nil, File.join(root, "absent")) rescue $!.class))
    p((Dir.mktmpdir(1) rescue [$!.class, $!.message]))
    p Dir::Tmpname::UNUSABLE_CHARS, Dir::Tmpname.tmpdir == root
    n = Dir::Tmpname.create("x", root) { |path, i, opts, origdir| p [File.dirname(path) == root, i, opts, origdir == root] }
    p File.basename(n).start_with?("x")

    w = File.join(root, "w")
    Dir.mkdir(w, 0o777)
    File.chmod(0o777, w)
    st = File.stat(w)
    p st.world_writable?, st.world_readable?, File.world_writable?(w)
    File.chmod(0o1777, w)
    st = File.stat(w)
    p st.world_writable?, st.sticky?
    File.chmod(0o700, w)
    p File.stat(w).world_writable?, File.stat(w).world_readable?
  ensure
    $stderr = old
    ENV.update(saved)
  end
end

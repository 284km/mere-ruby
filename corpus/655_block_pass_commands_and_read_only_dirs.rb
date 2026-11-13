# The rubygems round: `recv.meth arg, &blk` passes the block as the call's
# block -- a `break` in it ends the method it was given to, as
# `recv.meth(arg, &blk)` does (rubygems' Util.traverse_parents walked on
# past the Gemfile it found) -- and opening a file with an integer mode or a
# permission in a read-only directory raises Errno::EACCES (FileUtils.cp
# there came out as an internal error).
class K
  def self.call_with(x, &b) = b.call(x)
  def self.yield_to(x) = yield(x)
end

def via_command(&b) = ([1, 2, 3].each { |h| K.call_with "a", &b }; :done)
def via_yield(&b) = ([1, 2, 3].each { |h| K.yield_to "a", &b }; :done)
def via_parens(&b) = ([1, 2, 3].each { |h| K.call_with("a", &b) }; :done)
def via_chdir(&b) = ([1, 2, 3].each { |h| Dir.chdir "/", &b }; :done)

%i[via_command via_yield via_parens via_chdir].each do |m|
  n = 0
  v = send(m) { |d| n += 1; break :broke if n == 2 }
  p [m, v, n]
end

require "fileutils"
require "tmpdir"
Dir.mktmpdir do |base|
  ro = File.join(base, "ro")
  Dir.mkdir(ro)
  src = File.join(base, "src.txt")
  File.write(src, "x")
  File.chmod(0o555, ro)
  w = File::WRONLY | File::CREAT | File::TRUNC
  {
    "integer mode" => -> { File.open(File.join(ro, "a"), w).close },
    "integer mode, perm, block" => -> { File.open(File.join(ro, "b"), w, 0o644) { |f| f.write "y" } },
    "string mode, perm" => -> { File.open(File.join(ro, "c"), "w", 0o600).close },
    "FileUtils.cp" => -> { FileUtils.cp(src, File.join(ro, "d")) },
  }.each do |label, pr|
    begin
      pr.call
      p [label, :opened]
    rescue SystemCallError => e
      p [label, e.class]
    end
  end
ensure
  File.chmod(0o755, ro) if ro && File.exist?(ro)
end

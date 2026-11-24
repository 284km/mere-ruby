# module_function on an inherited method writes a private entry into the
# module; a module's copy that runs out of `super` says "for module";
# String#encode keeps a subclass; IO#wait on a descriptor closed behind the
# stream's back is EBADF, and wait_writable on a read end is IOError; io/wait
# has no ready?; and a child started with SIGINT ignored keeps it ignored
require 'rbconfig'
require 'io/wait'
require 'tmpdir'

module E
  def y = :ey
  def z = :ez
end
module U
  include E
  module_function :y
  def z = super
  module_function :z
end
p U.private_instance_methods(false).sort
p U.y
p((U.z rescue $!.message))
class C; include U; def t = [y, z]; end
p C.new.t
p((C.new.y rescue $!.class))

class S < String; end
s = S.new("abc")
p s.encode("UTF-16LE").class, s.encode("UTF-8").class, s.encode.class
p s.encode("UTF-8").equal?(s)
p s.dup.force_encoding("ASCII-8BIT").encode("UTF-8", invalid: :replace, undef: :replace).class
t = S.new("x")
p t.encode!("UTF-16LE").equal?(t), t.class
p "plain".encode("UTF-16LE").class

r, w = IO.pipe
p((r.wait_writable(0.01) rescue [$!.class, $!.message]))
IO.for_fd(r.fileno, autoclose: true).close
p((r.wait(0.01) rescue $!.class))
p((r.wait_readable(0.01) rescue $!.class))
p((r.wait(IO::READABLE, 0.01) rescue $!.class))
p((IO.select([r], nil, nil, 0.01) rescue $!.class))
p IO.method_defined?(:ready?)
w.close

# (the shell ignores it and execs the interpreter, as `cmd &` in a
#  non-interactive shell does; a signal sent to itself is then dropped)
old_int = Signal.trap("INT", "DEFAULT")
old_hup = Signal.trap("HUP", "DEFAULT")
begin
  # Control the parent's disposition too: a background/nohup launcher can
  # otherwise make the uncontrolled child inherit an unrelated SIG_IGN.
  src = 'p Signal.trap("INT", "DEFAULT"); p Signal.trap("INT", "DEFAULT"); p Signal.trap("HUP", "DEFAULT")'
  src2 = 'Process.kill(:INT, $$); sleep 0.05; puts :alive'
  [src, src2].each do |code|
    IO.popen(["sh", "-c", "trap '' INT; exec \"$0\" -e \"$1\"", RbConfig.ruby, code]) { |io| print io.read }
  end
  IO.popen([RbConfig.ruby, "-e", src]) { |io| print io.read }
ensure
  Signal.trap("INT", old_int)
  Signal.trap("HUP", old_hup)
end

m = Module.new
def m.q = super
c = Class.new
def c.q = super
p((m.q rescue $!.message.sub(/0x\h+/, "X")))
p((c.q rescue $!.message.sub(/0x\h+/, "X")))

# (review: the inherited module_function entry has no body -- a later
#  redefinition in the source module is what the includer runs; a
#  singleton-classed subclass instance encodes into its class; a read-only
#  mode whose encoding name has an "a" is still read-only)
module E2; def y = :old; end
module U2; include E2; module_function :y; end
module E2; def y = :new; end
class X2; include U2; def t = y; end
p [X2.new.t, U2.y, U2.private_instance_methods(false)]
t2 = S.new("c")
def t2.hi = 1
p [t2.encode("UTF-16LE").class, t2.encode("UTF-16LE").respond_to?(:hi)]
path = File.join(Dir.tmpdir, "corpus778_#{$$}")
File.write(path, "x")
File.open(path, "r:binary") { |f| p((f.wait_writable(0) rescue [$!.class, $!.message])) }
File.open(path, "r:windows-1252") { |f| p((f.wait_writable(0) rescue [$!.class, $!.message])) }
File.delete(path)

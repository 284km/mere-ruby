# Round 12 of note 537 (the runtime, Mere v0.1.724): a pty and its
# terminal settings (PTY.open, io/console's echo / raw / winsize / iflush),
# a child on a pty's slave that has it as its controlling terminal
# (PTY.spawn, PTY.check), expect; a file unlinked while open keeps its size
# and stat (fstat); a peer's ids, a descriptor passed over a socket
# (send_io / recv_io, recvmsg with scm_rights), the empty sender of a
# stream's recvmsg and nil at its end, connect(2) on an existing socket
# (UDP keeps its family, connect_nonblock), the interface list; a read
# buffer keeps its encoding; Signal.trap('PIPE', 'SYSTEM_DEFAULT') survives
# IO.pipe.
require "pty"
require "io/console"
require "expect"
require "socket"
require "tmpdir"

# --- a pty: master IO, slave File, the slave's mode, echo and raw
PTY.open do |m, s|
  p [m.class, s.class, s.tty?, File.chardev?(s.path), m.path == "masterpty:" + s.path]
  p File.stat(s.path).mode & 0777
  s.print "abc\n"
  p m.gets
  p s.echo?
  s.raw do
    p s.echo?
    s.print "def\n"
    p m.gets
  end
  p s.echo?
  s.noecho { p s.echo? }
  s.echo = false
  p s.echo?
  s.echo = true
  p s.winsize
  s.winsize = [24, 80]
  p s.winsize, m.winsize
  m.print "x"
  s.iflush
  m.print "y\n"
  p s.gets
end
r = PTY.open { :block_value }
p r
File.open(IO::NULL) do |f|
  begin
    f.echo?
  rescue SystemCallError => e
    p e.message.include?(IO::NULL)
  end
  begin
    f.winsize = [1, 2, 3]
  rescue ArgumentError => e
    p e.message
  end
end

# --- a child on the slave: its controlling terminal, its output, check
r, w, pid = PTY.spawn("/bin/sh", "-c", "stty size; echo done")
p r.gets, r.gets
Process.wait(pid)
r.close
w.close
st = nil
PTY.spawn("cat") do |r2, w2, id|
  p PTY.check(id)
  w2.close
  r2.close
  20.times { break if (st = PTY.check(id)); sleep 0.05 }
end
p st.class
p((PTY.getpty("/no/such/program") rescue $!.class))

# --- expect over a pipe
rd, wr = IO.pipe
wr.print "login: "
p rd.expect("login:", 1)
rd.close
wr.close

# --- fstat: a file unlinked while open
Dir.mktmpdir do |d|
  f = File.open(File.join(d, "gone"), "w+")
  f.write "12345678"
  f.flush
  File.delete(f.path)
  p f.size, f.stat.size, f.stat.file?
  f.close
end

# --- a peer's ids, a descriptor passed, recvmsg
a, b = UNIXSocket.pair
p a.getpeereid == [Process.euid, Process.egid]
p((TCPServer.new("127.0.0.1", 0).getpeereid rescue $!.class))
pr, pw = IO.pipe
a.send_io(pr)
got = b.recv_io
pw.syswrite "via"
p got.sysread(3), got.fileno != pr.fileno
a.send_io(pr)
data, sender, flags, *ctls = b.recvmsg(scm_rights: true)
p data, sender.afamily, flags, ctls.size, ctls[0].cmsg_is?(:SOCKET, :RIGHTS), ctls[0].unix_rights.map(&:class)
a.sendmsg("\0", 0, nil, [Socket::SOL_SOCKET, Socket::SCM_RIGHTS, [pr.fileno].pack("i")])
_, _, _, *c2 = b.recvmsg
p c2.size, c2[0].unix_rights
a.close
p b.recvmsg
b.close

# --- connect(2) on an existing socket
srv = TCPServer.new("127.0.0.1", 0)
port = srv.local_address.ip_port
s = Socket.new(:INET, :STREAM)
begin
  r3 = s.connect_nonblock(Socket.sockaddr_in(port, "127.0.0.1"), exception: false)
  p [:wait_writable, 0].include?(r3)
  IO.select(nil, [s], nil, 2)
  p s.connect_nonblock(Socket.sockaddr_in(port, "127.0.0.1"), exception: false)
ensure
  s.close
end
c, = srv.accept
c.close
srv.close
u = UDPSocket.new(Socket::AF_INET)
u.connect("127.0.0.1", 9)
p u.local_address.afamily == Socket::AF_INET, u.remote_address.ip_address
u.close
p Socket.getifaddrs.any? { |i| i.addr && i.addr.ip? && i.addr.ip_address == "127.0.0.1" }
p((Socket.pair(:CATS, :STREAM) rescue $!.class))

# --- a read into a buffer keeps the buffer's encoding
rr, ww = IO.pipe
ww.write "ab"
buf = +"x"
rr.read(1, buf)
p buf, buf.encoding
rr.close
ww.close

# --- SYSTEM_DEFAULT for PIPE is the OS's action, IO.pipe or not
pid = fork do
  Signal.trap("PIPE", "SYSTEM_DEFAULT")
  r4, w4 = IO.pipe
  r4.close
  loop { w4.write("a" * 1024) }
end
Process.wait(pid)
p $?.signaled?, $?.termsig == Signal.list["PIPE"]

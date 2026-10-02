# A child a signal ended is `signaled?` with its number (the waiting shell
# reports 128 + N, and the status reads it back); an unrescued
# SignalException and an Errno::EPIPE on stdout end the process OF the
# signal; and a write to a pipe nobody reads is an Errno::EPIPE where it
# happens, which a rescue catches.
require "rbconfig"
require "socket"
require "tempfile"

me = RbConfig.ruby
run = lambda do |src|
  r, w = IO.pipe
  pid = spawn(me, "-e", src, out: w, err: File::NULL)
  w.close
  r.gets
  r.close
  Process.wait2(pid)[1]
end
[["loop { puts :ok }", "a closed pipe"],
 ["begin; loop { puts :ok }; rescue Errno::EPIPE; exit 7; end", "EPIPE rescued"],
 ["puts 1; Process.kill(:TERM, $$); sleep 1", "TERM to itself"],
 ["puts 1; raise SignalException, 'HUP'", "an unrescued SignalException"]].each do |src, what|
  st = run.(src)
  p [what, st.signaled?, st.termsig, st.exitstatus, st.success?]
end
pid = spawn("kill -PIPE $$")
Process.wait(pid)
p [$?.signaled?, $?.termsig, $?.exitstatus, $?.to_s.sub(/\d+/, "N"), $?.to_i]
p system("kill -TERM $$")
begin
  system("kill -TERM $$", exception: true)
rescue => e
  p e.message
end

# a pipe's ends, a socketpair, a timeout carried by #dup, a frozen IO closed
r, w = IO.pipe
r.timeout = 0.25
d = r.dup
p [d.timeout, w.timeout]
d.close
r.freeze
p r.fileno.is_a?(Integer)
r.close
w.close
a, b = UNIXSocket.pair
a.write "pq"
p b.read(2)
a.close
p b.read
b.close

# a Tempfile is a path to File.open (its #to_path answered by delegation)
t = Tempfile.new("c284")
t.puts "foo"
t.close
p File.open(t, "rt") { |f| f.each_codepoint.to_a.size }
t.close(true)

# a resource limit is the child's
f = IO.popen([me, "-e", "print Process.getrlimit(:NOFILE)[0]"], rlimit_nofile: 64)
p f.read
f.close

# Process.spawn did not exist, and Process.wait always said ECHILD: "there
# are no children in this model". A child is started by a background shell
# now, so spawn answers at once with the child's real pid, and wait, wait2,
# waitpid, detach and last_status reap it and report its status.
r, w = IO.pipe
pid = Process.spawn("echo", "a  b", "*", out: w)
p pid.is_a?(Integer), Process.wait(pid) == pid, $?.pid == pid, $?.exitstatus, $?.success?
w.close
p r.read
pid = spawn("exit 7")
got, st = Process.wait2
p got == pid, st.exitstatus, Process.last_status.exitstatus
begin
  Process.wait
rescue Errno::ECHILD => e
  p e.message
end
pid = spawn("sleep 5")
p Process.wait(pid, Process::WNOHANG)
Process.kill(:KILL, pid)
p Process.waitpid(pid) == pid
t = Process.detach(spawn({"GREETING" => "hi"}, "test \"$GREETING\" = hi"))
p t.class, t.class.superclass, t.join.value.exitstatus, t.pid == t[:pid]
p Thread.new { Process.last_status }.value
p Process.detach(2**30).value
begin
  Process.spawn("no_such_command_here")
rescue Errno::ENOENT => e
  p e.message, $?.exitstatus
end
[[:echo], ["echo", nil], ["a\0b"]].each do |args|
  begin
    Process.spawn(*args)
  rescue TypeError, ArgumentError => e
    p [e.class, e.message]
  end
end
p Process.waitall

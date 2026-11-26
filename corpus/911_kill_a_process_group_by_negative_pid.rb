# Process.kill with a NEGATIVE pid signals that process group, as kill(2)
# does. kill(1) read `kill -s KILL -<pid>` as a second signal, so a group
# that was there answered ESRCH and its members ran on -- puma's
# integration helper stops an unresponsive server by its group.
pid = spawn("sleep", "30", pgroup: true)
sleep 0.2
p Process.getpgid(pid) == pid
p Process.kill(0, -pid)
p Process.kill(:KILL, -pid)
_, st = Process.wait2(pid)
p st.signaled?, st.termsig
pid = spawn("sleep", "30", pgroup: true)
sleep 0.2
p Process.kill("TERM", -pid)
_, st = Process.wait2(pid)
p st.termsig == Signal.list["TERM"]
begin
  Process.kill(:KILL, -pid)
rescue Errno::ESRCH => e
  p e.class
end

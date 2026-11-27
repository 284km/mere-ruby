# Process keeps its own state (the table of children spawn handed out, the
# counter that names their files, the groups and the argv0 it read once, the
# flag exec sets around spawn) where a program cannot see it: ruby's Process
# has no instance variables, before or after any of these.
p Process.instance_variables

p Process.argv0.frozen?, Process.argv0.equal?(Process.argv0)
p Process.groups.is_a?(Array), Process.maxgroups.positive?
old = Process.maxgroups
Process.maxgroups = 8
p Process.maxgroups
Process.maxgroups = old
begin
  Process.maxgroups = 0
rescue ArgumentError => e
  p e.message
end

pid = spawn("exit 3")
p Process.wait(pid) == pid, $?.exitstatus
p `echo hi`
r, w = IO.pipe
pid = spawn("echo out", out: w)
w.close
p r.read
p Process.wait2(pid)[1].success?
pid = spawn("true")
p Process.waitall.map { |x, st| [x == pid, st.exitstatus] }
begin
  Process.wait
rescue Errno::ECHILD => e
  p e.class
end

pid = fork { exit!(Process.instance_variables.empty? ? 5 : 6) }
Process.wait(pid)
p $?.exitstatus

p Process.instance_variables
# nor are its helpers among its singleton methods (the clock's table was)
Process.clock_getres(:TIME_BASED_CLOCK_REALTIME)
p Process.singleton_methods.grep(/\A__/)
# a program's own instance variable on Process is still listed
Process.instance_variable_set(:@mine, 1)
p Process.instance_variables

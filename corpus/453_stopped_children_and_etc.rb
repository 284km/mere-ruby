# tmpdir loads etc.so, as ruby's does, so Etc is there after it; and
# `require "etc.so"` is the same library as `require "etc"`.
require "tmpdir"
p defined?(Etc)
p require("etc.so"), require("etc")
p Etc.respond_to?(:uname)

# A process that sends itself STOP is stopped until a CONT -- it is no
# SignalException -- and waitpid(WUNTRACED) reports the stop.
pid = fork do
  Process.kill(:STOP, Process.pid)
  exit 3
end
_, s = Process.waitpid2(pid, Process::WUNTRACED)
p s.stopped?, s.stopsig == Signal.list["STOP"], s.exited?, s.signaled?, s.exitstatus, s.success?
p s.to_i == ((Signal.list["STOP"] << 8) | 0x7f)
puts s.to_s.sub(/\Apid \d+/, "pid N").sub(/\(signal \d+\)/, "(signal S)")
Process.kill(:CONT, pid)
_, s = Process.waitpid2(pid)
p s.exited?, s.exitstatus, s.stopped?

# Without WUNTRACED the stop is not reported: the wait goes on to the end.
pid = fork do
  Process.kill(:TSTP, Process.pid)
  exit 4
end
Thread.new { sleep 0.3; Process.kill(:CONT, pid) }
_, s = Process.waitpid2(pid)
p s.exitstatus

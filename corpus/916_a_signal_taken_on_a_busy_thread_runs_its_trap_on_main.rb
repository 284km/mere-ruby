# A signal that arrives while another thread is busy -- never waiting, so
# the scheduler never idles -- still runs its trap on the main thread, which
# is joining that thread. The busy thread took the signal at a statement
# and left it queued for the main thread without waking it: a puma worker
# serving requests never ran the URG trap that promotes it to a mold.
$stdout.sync = true
seen = []
Signal.trap(:USR2) { seen << (Thread.current == Thread.main); $stop = true }
busy = Thread.new do
  n = 0
  n += 1 until $stop
  n > 0
end
spawn("sh", "-c", "sleep 0.3; kill -USR2 #{Process.pid}")
p busy.value
p seen
Process.wait

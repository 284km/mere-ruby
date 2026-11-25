# A trap runs on the MAIN thread -- also while the main thread joins another
# thread, and also when the signal arrives while another thread is inside a
# method. It ran on whichever thread was in a method (puma's TERM trap ran on
# its reactor thread and deadlocked its stop), and a main thread joining
# never ran it at all.
$stdout.sync = true
seen = []
Signal.trap(:USR2) { seen << [:usr2, Thread.current == Thread.main]; $stop = true }

def poll_until_stopped
  sleep 0.02 until $stop
  :polled
end

worker = Thread.new { poll_until_stopped }
waiter = Thread.new { worker.join; :joined }
spawn("sh", "-c", "sleep 0.3; kill -USR2 #{Process.pid}")
p waiter.value
p seen
Process.wait

# ...and a signal a thread sends to its own process from inside a method
$stop = false
seen.clear
Signal.trap(:USR1) { seen << [:usr1, Thread.current == Thread.main]; $stop = true }
def send_from_a_method
  Process.kill(:USR1, Process.pid)
  sleep 0.02 until $stop
  :sent
end
t = Thread.new { send_from_a_method }
p t.value
p seen

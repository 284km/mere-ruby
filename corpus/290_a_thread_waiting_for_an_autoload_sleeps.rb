# A thread that reads a constant another thread is autoloading waits for the
# load -- and while it waits it is STOPPED, as ruby's is. It passed until the
# load was over instead: a loader that slept kept it spinning, never "sleep"
# to Thread#status, and what each turn allocated stayed (CRuby's
# test_bug_13526, ten threads, went past 6.5 GB; note 305).
require "tmpdir"
Dir.mktmpdir do |d|
  path = File.join(d, "slow_const.rb")
  File.write(path, "$entered = true\nsleep\nSlowConst = 1\n")
  autoload :SlowConst, path
  threads = Array.new(3) { Thread.new { SlowConst } }
  Thread.pass until threads.all?(&:stop?)
  p threads.map(&:status)
  p $entered
  1000.times { Thread.pass }
  p threads.map(&:alive?)
end

# ...and one that finishes wakes them: they see the constant it defined
Dir.mktmpdir do |d|
  path = File.join(d, "quick_const.rb")
  File.write(path, "Thread.pass\nQuickConst = :defined\n")
  autoload :QuickConst, path
  threads = Array.new(4) { Thread.new { QuickConst } }
  p threads.map(&:value)
end

# ...and a load that RAISES wakes them too: each waiter tries the file itself
# and meets the same error
Dir.mktmpdir do |d|
  path = File.join(d, "raising_const.rb")
  File.write(path, "Thread.pass\nsleep 0.05\nraise 'boom'\n")
  autoload :RaisingConst, path
  threads = Array.new(3) { Thread.new { begin; RaisingConst; rescue => e; [e.class, e.message]; end } }
  p threads.map(&:value).uniq
end

# ...as does a loader that is KILLED: the waiter loads the file itself
Dir.mktmpdir do |d|
  path = File.join(d, "killed_const.rb")
  File.write(path, "if $second then KilledConst = :second else $second = true; sleep; end\n")
  autoload :KilledConst, path
  loader = Thread.new { KilledConst }
  Thread.pass until loader.stop?
  waiter = Thread.new { KilledConst }
  Thread.pass until waiter.stop?
  p waiter.status
  loader.kill
  loader.join
  p waiter.join(5) ? waiter.value : :still_waiting
end

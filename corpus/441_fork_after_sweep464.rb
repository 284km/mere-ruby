# fork after sweep464: in the child the fiber that forked is the root (a
# fiber transferred to from it comes back to it; its end is the process's),
# an autoload or a require another thread was running is abandoned there,
# the missing script is named after the interpreter's path, and
# Hash#values_at answers a missing key with the default.

require "tmpdir"

def show(label)
  r = yield
  puts "#{label}: #{r.inspect}"
rescue Exception => e
  puts "#{label}: #{e.class}: #{e.message}"
end

# a fiber transferred to in a child forked inside a fiber returns to the
# fiber that forked, not to one of the parent's
show("transfer in a forked fiber") do
  r, w = IO.pipe
  Fiber.new do
    pid = fork do
      r.close
      xpid = nil
      Fiber.new {
        xpid = fork do
          3.times { Fiber.new {}.transfer; Fiber.new { Fiber.yield } }
          exit!(true)
        end
      }.transfer
      _, st = Process.waitpid2(xpid)
      w.write(st.success? ? "ok" : "ng")
      exit!(true)
    end
    w.close
    Process.wait(pid)
  end.resume
  r.read
end

# the fiber that forked ending is the child's end: it exits 0 there and
# does not go on with the parent's code
show("fork in a fiber") do
  r, w = IO.pipe
  pid = Fiber.new { fork }.resume
  if pid.nil?
    w.write("continued")
    exit!(3)
  end
  w.close
  Process.wait(pid)
  [$?.exitstatus, r.read]
end

# an autoload another thread is loading when the child forks: the child
# loads it itself
dir = File.join(Dir.tmpdir, "corpus441_#{$$}")
Dir.mkdir(dir) unless Dir.exist?(dir)
File.write(File.join(dir, "al441.rb"), "sleep 0.2; class Autoload441; end\n")
autoload :Autoload441, File.join(dir, "al441.rb")
show("autoload across fork") do
  thrs = []
  2.times do
    thrs << Thread.new { Autoload441 && nil }
    thrs << Thread.new { fork { Autoload441 } }
  end
  thrs.each(&:join)
  thrs.filter_map(&:value).map { |pid| Process.waitpid2(pid)[1].success? }
end
File.delete(File.join(dir, "al441.rb"))
Dir.rmdir(dir)

# a script that is not there: "<interpreter>: No such file ... (LoadError)"
show("missing script") do
  r, w = IO.pipe
  pid = spawn(RbConfig.ruby, "./corpus441_not_there.rb", err: w)
  w.close
  Process.wait(pid)
  msg = r.read
  [$?.exitstatus, msg.start_with?(RbConfig.ruby + ": "), msg[/: (.*)/, 1]]
end

# values_at answers a missing key with the default, as [] does
show("values_at block default") { Hash.new { |h, k| k * 2 }.values_at(1, 2) }
show("values_at default") { h = Hash.new(5); h[1] = 0; h.values_at(1, 2) }
show("values_at default_proc=") { g = {a: 1}; g.default_proc = proc { |_, k| k.to_s }; g.values_at(:a, :b) }
show("values_at none") { {x: 1}.values_at(:x, :y) }

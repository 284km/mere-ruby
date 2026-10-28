# A forked child draws its own random numbers, and a thread that forks is its
# child's main thread: when it ends, the child ends (note 449).

srand(1234)
r1 = IO.popen("-") { |f| f ? f.read : (print rand; exit!(0)) }
r2 = IO.popen("-") { |f| f ? f.read : (print rand; exit!(0)) }
p r1 != r2
p r1 != rand.to_s

f = nil
th = Thread.start do
  unless f = IO.popen("-")
    STDERR.reopen(STDOUT)
    puts "child"
    exit
  end
  Process.wait2(f.pid)
end
_, status = th.value
p status.success?
print f.read
f.close

p((Process.waitpid2(nil) rescue $!.class))

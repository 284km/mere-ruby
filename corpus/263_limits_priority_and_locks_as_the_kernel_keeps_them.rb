# Resource limits, the scheduling priority and flock(2), asked of the kernel.
# Nothing here prints a machine's own limit: every line is a class, a
# relationship between two answers, or a value this program set and read back,
# so the output is the same on any host that has the calls.
def err
  yield
rescue StandardError => e
  [e.class, e.message]
end

# One resource, three spellings: a Symbol, a String and the platform's number.
nofile = Process.getrlimit(:NOFILE)
p nofile.size, nofile.map(&:class)
p Process.getrlimit("NOFILE") == nofile, Process.getrlimit(Process::RLIMIT_NOFILE) == nofile
p Process.constants.grep(/\ARLIMIT_/).all? { |c|
  Process.getrlimit(c.to_s.sub("RLIMIT_", "").to_sym) == Process.getrlimit(Process.const_get(c))
}
p %i[RLIMIT_CORE RLIMIT_CPU RLIMIT_DATA RLIMIT_NOFILE RLIMIT_STACK].all? { |c| Process.const_defined?(c) }
p Process::RLIM_INFINITY.class, Process::RLIM_INFINITY >= 2**63 - 1
p err { Process.getrlimit(:FOO) }, err { Process.getrlimit("core") }
p err { Process.getrlimit(nil) }

# What is set is what is read back, and -- going the other way -- a soft limit
# can be put back exactly where it was.
soft, hard = nofile
p Process.setrlimit(:NOFILE, 64, hard), Process.getrlimit(:NOFILE) == [64, hard]
p Process.setrlimit(:NOFILE, soft, hard), Process.getrlimit(:NOFILE) == nofile
core = Process.getrlimit(:CORE)
p Process.setrlimit(:CORE, 0, core[1]), Process.getrlimit(:CORE)[0]
p Process.setrlimit("CORE", *core), Process.getrlimit(:CORE) == core
p err { Process.setrlimit(:CORE, 100, 50) }
p err { Process.setrlimit(:CORE, :FOO) }, err { Process.setrlimit(:FOO, 1) }
cpu = Process.getrlimit(:CPU)
if cpu[1] == Process::RLIM_INFINITY
  Process.setrlimit(:CPU, 1_000_000, :INFINITY)
  a = Process.getrlimit(:CPU)[0]
  Process.setrlimit(:CPU, :INFINITY, "INFINITY")
  p [a, Process.getrlimit(:CPU)[0] == Process::RLIM_INFINITY]
  Process.setrlimit(:CPU, *cpu)
else
  p [1_000_000, true]
end

# The priority: raising one's own nice value is always allowed, and a process
# that is not there is ESRCH.
prio = Process.getpriority(Process::PRIO_PROCESS, 0)
p prio.class, [Process::PRIO_PROCESS, Process::PRIO_PGRP, Process::PRIO_USER]
up = prio < 19 ? prio + 1 : prio
p Process.setpriority(Process::PRIO_PROCESS, 0, up), Process.getpriority(Process::PRIO_PROCESS, 0) == up
p err { Process.getpriority(Process::PRIO_PROCESS, 2147483646) }
p err { Process.getpriority(nil, 0) }

# flock(2) belongs to an OPEN FILE, so two opens of one path in one process
# contend exactly as two processes would; LOCK_NB turns the wait into false.
path = "/tmp/mere_ruby_corpus_263_#{Process.pid}"
File.write(path, "x")
a = File.open(path)
b = File.open(path)
p [File::LOCK_SH, File::LOCK_EX, File::LOCK_NB, File::LOCK_UN]
p a.flock(File::LOCK_EX), b.flock(File::LOCK_EX | File::LOCK_NB), b.flock(File::LOCK_SH | File::LOCK_NB)
p a.flock(File::LOCK_UN), b.flock(File::LOCK_EX | File::LOCK_NB), a.flock(File::LOCK_SH | File::LOCK_NB)
p b.flock(File::LOCK_UN), a.flock(File::LOCK_SH), b.flock(File::LOCK_SH | File::LOCK_NB)
a.close
b.close
File.delete(path)

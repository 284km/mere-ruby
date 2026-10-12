# Process as test_process asks it (note 315): a Status survives Marshal and
# equals its Integer from either side, $0 is frozen, sleep counts its
# arguments and refuses a negative Rational, an unknown clock is EINVAL and
# getres answers :hertz, Process::UID / GID know names, spawn refuses a fd
# named twice, a bad rlimit, a duplex IO and a missing redirect path in the
# parent (relative paths opened where the parent stands), an Array of one
# word is never a shell line, and a bare `abort` in a rescue reports $!.
require "tmpdir"
def t(n)
  r = begin; yield.inspect; rescue Exception => e; "#{e.class}: #{e.message}"; end
  puts "#{n}: #{r}"
end
t(1) { system("exit 3"); s = $?; [s == s.to_i, s.to_i == s, [0, s.to_i] == [0, s], Marshal.load(Marshal.dump(s)) == s, s.exitstatus] }
t(2) { [$0.frozen?, Process.argv0.frozen?] }
t(3) { sleep(1, 1) }
t(4) { [-1, -1.0, -1r].map { |x| begin; sleep(x); rescue ArgumentError => e; e.message; end } }
t(5) { [Process.clock_getres(:foo), 1] rescue $!.message }
t(6) { Process.clock_gettime(123456) rescue $!.message }
t(7) { [Process.clock_getres(:TIMES_BASED_CLOCK_MONOTONIC, :hertz), Process.clock_getres(:GETTIMEOFDAY_BASED_CLOCK_REALTIME, :hertz)] }
t(8) { Process.constants.grep(/\ACLOCK_/).all? { |c| Process.const_get(c).is_a?(Integer) } }
t(9) { [Process::UID.sid_available?, Process::GID.sid_available?, [true, false].include?(Process::UID.re_exchangeable?)] }
t(10) { require "etc"; [Process::UID.from_name(Etc.getpwuid(Process.uid).name) == Process.uid, (Process::GID.from_name("no such group here") rescue $!.class)] }
t(11) { Process.initgroups("\0", 0) }
t(12) { [[], [1, 2, 3]].map { |v| begin; system("true", :rlimit_nofile => v); rescue ArgumentError => e; e.message; end } }
t(13) { IO.popen(["echo", "x", STDOUT => STDOUT]) { |io| io.read } }
t(14) { IO.popen(["echo bar"]) { |io| io.read } }
t(15) { r, w = IO.pipe; system("true", :in => "no/such/file") }
t(16) { Dir.mktmpdir { |d| Dir.chdir(d) { Dir.mkdir("foo"); system("pwd", chdir: "foo", out: "o.txt"); [File.exist?("o.txt"), File.exist?("foo/o.txt")] } } }
t(17) { IO.popen("cat", "r+") { |d| system("true", d => STDOUT) } }
t(18) { r = IO.popen([RbConfig.ruby, "-e", "begin; raise 'from the rescue'; rescue; abort; end"], err: [:child, :out], &:read); [r.include?("from the rescue"), $?.success?] }

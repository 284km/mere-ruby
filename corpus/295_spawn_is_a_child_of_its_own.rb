# spawn without a shell between (note 316): the child is this process's own
# (its parent pid is ours, a shell adds no SHLVL), descriptors are put in
# place through copies so a rotation reads what it was given, [:child, x]
# chains are made in the order they depend on and a cycle is refused as ruby
# refuses it, a script with no #! line is read by /bin/sh, an inherited
# descriptor can be written in the child, and a missing redirect file is
# created before a missing command is refused.
require "tmpdir"
require "rbconfig"
def t(n)
  r = begin; yield.inspect; rescue Exception => e; "#{e.class}: #{e.message}"; end
  puts "#{n}: #{r}"
end
RB = RbConfig.ruby
t(1) { IO.popen(["sh", "-c", "echo $PPID"], &:read).to_i == Process.pid }
t(2) { IO.popen({"SHLVL" => nil}, ["sh", "-c", "echo ${SHLVL-unset}"], &:read) }
t(3) { a, b = IO.pipe; c, d = IO.pipe; pid = spawn("sh", "-c", "echo B >&#{b.fileno}; echo D >&#{d.fileno}", b => d, d => b); b.close; d.close; Process.wait pid; [a.read, c.read] }
t(4) { Dir.mktmpdir { |dir| Dir.chdir(dir) { Process.wait spawn("sh", "-c", "echo err >&2; echo out", STDOUT => "o", STDERR => [:child, 3], 3 => [:child, 4], 4 => [:child, STDOUT]); File.read("o") } } }
t(5) { [{3 => [:child, 4], 4 => [:child, 3]}, {STDOUT => [:child, STDOUT]}, {STDOUT => [:child, 3]}].map { |o| begin; spawn("true", o); rescue ArgumentError => e; e.message; end } }
t(6) { Dir.mktmpdir { |dir| Dir.chdir(dir) { File.write("s", "echo from-sh", perm: 0o755); IO.popen(["./s"], &:read) } } }
t(7) { Dir.mktmpdir { |dir| Dir.chdir(dir) { r, w = IO.pipe; w.close_on_exec = false; system("sh", "-c", "echo hi >&#{w.fileno}"); w.close; r.read } } }
t(8) { Dir.mktmpdir { |dir| Dir.chdir(dir) { [(spawn("no-such-command-here", 3 => ["made", File::WRONLY | File::CREAT]) rescue $!.class), File.exist?("made")] } } }
t(9) { pid = spawn("sh", "-c", "kill -TERM $$"); Process.wait pid; [$?.signaled?, $?.termsig == Signal.list["TERM"]] }
t(10) { system("exit 7"); [$?.exitstatus, $?.success?] }
t(11) { Dir.mktmpdir { |dir| Dir.chdir(dir) { IO.popen([RB, "-e", 'STDERR.reopen("e", "w"); STDERR.print "x"; STDERR.flush; print File.read("e")'], &:read) } } }

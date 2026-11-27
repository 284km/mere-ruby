# Process's methods answer in every Ractor, as ruby's C functions do. The
# prelude keeps Process's child table and caches in locals its methods
# capture (so Process.instance_variables stays empty, corpus 1076), and a
# method made from an ordinary block raises "defined with an un-shareable
# Proc in a different Ractor" outside the Ractor that made it -- which
# Process.spawn, wait and argv0 did inside a Ractor.
verbose = $VERBOSE
$VERBOSE = nil
Ractor.new {}.value
$VERBOSE = verbose

def check1077(name)
  case name
  when :argv0 then Process.argv0.class
  when :groups then Process.groups.class
  when :maxgroups then Process.maxgroups.class
  when :maxgroups_set then Process.maxgroups = Process.maxgroups; :set
  when :spawn_wait then pid = Process.spawn("true"); Process.wait(pid); $?.exitstatus
  when :spawn_wait2 then pid = Process.spawn("true"); Process.wait2(pid)[1].exitstatus
  when :waitall then Process.spawn("true"); Process.waitall.size
  when :backticks then `echo hi`.chomp
  when :system then system("true")
  when :detach then pid = Process.spawn("true"); Process.detach(pid).value.exitstatus
  when :echild
    begin
      Process.wait
    rescue Errno::ECHILD => e
      e.class
    end
  end
end

%i[argv0 groups maxgroups maxgroups_set spawn_wait spawn_wait2 waitall
   backticks system detach echild].each do |name|
  p Ractor.new(name) { |n|
    begin
      [n, check1077(n)]
    rescue Exception => e
      [n, e.class, e.message]
    end
  }.value
end

# The same, twice in one Ractor and then in main: one child table for all.
p Ractor.new {
  a = Process.spawn("true")
  b = Process.spawn("true")
  [Process.wait2(b)[0] == b, Process.wait2(a)[0] == a]
}.value
pid = Process.spawn("true")
p Process.wait2(pid)[0] == pid
p Process.instance_variables

# A program's own closure is still bound to the Ractor that made it.
module UserClosure1077
  value = 1
  define_singleton_method(:read) { value }
end
p Ractor.new {
  begin
    UserClosure1077.read
  rescue RuntimeError => error
    [error.class, error.message]
  end
}.value
p UserClosure1077.read

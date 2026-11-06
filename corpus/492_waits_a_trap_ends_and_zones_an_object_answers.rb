# What CRuby's own tests found left: a trap that runs while the main thread
# waits (a Queue#pop, a Mutex, an unbounded sleep after the last other thread
# ended) and the wait it ends; two threads waiting on one child; $stdin closed
# under a reader in another thread; a zone object's dst? (Time#to_a's isdst
# too) and a zone name given to Time.now / Time.at through a subclass's
# find_timezone; Kernel#inspect bound to a Struct or an immediate; ENV under a
# default_internal (transcoded, not relabelled); TracePoint :script_compiled;
# and a call with too many literal arguments.
q = Thread::Queue.new
trap(:USR1) { q.push :usr1 }
Thread.new { 2.times { Process.kill(:USR1, $$); sleep 0.05 } }
p q.pop, q.pop
q2 = Thread::Queue.new
trap(:USR2) { q2.push :late }
Thread.new { sleep 0.05; Process.kill(:USR2, $$) }
p q2.pop
m = Mutex.new
seen = []
trap(:USR1) { seen << :trap }
Thread.new { m.synchronize { Process.kill(:USR1, $$); sleep 0.1 } }
sleep 0.02
m.synchronize { seen << :locked }
p seen
begin
  trap(:TERM) { raise "term" }
  Thread.new { sleep 0.05 }
  spawn("sh", "-c", "sleep 0.3; kill -TERM #{$$}")
  sleep
rescue => e
  p e.message
  Process.wait
end

rp, wp = IO.pipe
pid = fork { wp.close; rp.read }
t2 = Thread.new { Process.waitpid(-1) rescue $!.class }
Thread.pass until t2.stop?
t3 = Thread.new { Process.waitpid(pid) rescue $!.class }
Thread.pass until t3.stop?
wp.close
p [t2, t3].map(&:value).sort_by(&:to_s).map { |v| v == pid ? :pid : v }
rp.close

ir, iw = IO.pipe
$stdin.reopen(ir)
ir.close
reader = Thread.new { begin; $stdin.read(1); rescue IOError => e; [e.class, e.message]; end }
sleep(0.02) until reader.stop?
$stdin.close
p reader.value, $stdin.closed?, ($stdin.read rescue [$!.class, $!.message])
iw.close

class Zone
  attr_reader :name
  def initialize(name, off, off2) = (@name, @off, @off2 = name, off, off2)
  def dst?(t) = (4..9).cover?(t.mon)
  def utc_to_local(t) = t + (dst?(t) ? @off2 : @off)
  def local_to_utc(t) = t - (dst?(t) ? @off2 : @off)
  def abbr(t) = dst?(t) ? "ZDT" : "ZST"
end
class ZTime < Time
  def self.find_timezone(name) = name == "Zone/Here" ? Zone.new(name, -8 * 3600, -7 * 3600) : raise(ArgumentError, name)
end
z = Zone.new("Zone/Here", -8 * 3600, -7 * 3600)
s = ZTime.new(2018, 7, 1, 12, 0, 0, z)
w = ZTime.new(2018, 1, 1, 12, 0, 0, z)
p s.dst?, w.dst?, s.utc_offset, w.utc_offset, s.to_a[8], w.to_a[8]
p ZTime.at(0, in: "Zone/Here").zone.name, ZTime.now(in: "Zone/Here").zone.class
p Time.utc(2018, 7, 1).to_a[8]

ki = Kernel.instance_method(:inspect)
S = Struct.new(:x)
o = S.new(5)
o.instance_variable_set(:@a, 1)
p ki.bind_call(o).sub(/0x\h+/, "X"), ki.bind_call(S.new).sub(/0x\h+/, "X")
p [1, nil, :s, 1.5, true].map { |v| ki.bind_call(v).sub(/0x\h+/, "X") }

key = "MR492テスト"
ENV[key] = "vé"
Encoding.default_internal = "Windows-31J"
k = ENV.keys.find { |x| x.b.start_with?("MR492") }
p k.encoding, k.bytes, ENV.to_h[k]&.encoding, ENV.to_h[k]&.bytes
ENV.delete_if { |kk, _| false }
p ENV.keys.count { |x| x.b.start_with?("MR492") }
Encoding.default_internal = nil
p ENV[key].encoding, ENV[key]
ENV.delete(key)

ev = []
tp = TracePoint.new(:script_compiled) { |t| ev << [t.instruction_sequence.path, t.eval_script] }
tp.enable do
  eval("1 + 1", nil, "e1.rb")
  nil.instance_eval("2", "e2.rb")
  Object.class_eval("3", "e3.rb")
end
p ev

def many(*a) = a.size
p eval("many(#{(0...1000).to_a.join(", ")})")
begin
  eval("many(#{(0...140000).to_a.join(", ")})")
rescue SystemStackError => e
  p e.class
end

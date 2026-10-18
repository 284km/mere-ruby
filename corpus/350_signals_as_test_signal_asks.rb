# Signals as test_signal asks (note 374): Process.kill takes an object with
# #to_str as its signal name and refuses anything else as "bad signal type",
# with ruby's arity message; a signal sent to ourselves whose default action
# is to do nothing (CONT, CHLD, URG, WINCH) does nothing when nothing trapped
# it; "-SIGEXIT" is a negative signal name; Signal.list hands back the same
# frozen String keys every time.
p((SignalException.new("-SIGEXIT") rescue $!.message))
p SignalException.new(:INT).signo, SignalException.new("SIGINT").signo, SignalException.new(2).signo
x = false
old = Signal.trap(:INT) { |_| x = true }
o = Object.new
def o.to_str = "SIGINT"
Process.kill(o, $$)
sleep 0.01 until x
p x
Signal.trap(:INT, old)
p((Process.kill(Object.new, $$) rescue $!.message))
p((Process.kill(nil, $$) rescue $!.message))
p((Process.kill rescue $!.message), (Process.kill(:INT) rescue $!.message))
p((Process.kill(:BOGUS, $$) rescue $!.message))
Process.kill(:CONT, $$); Process.kill(:CHLD, $$); Process.kill(:WINCH, $$); Process.kill(:URG, $$)
p :alive
a = Signal.list.keys.map(&:object_id).sort
b = Signal.list.keys.map(&:object_id).sort
p a == b, Signal.list.keys.all?(&:frozen?), Signal.list["INT"], Signal.list.size > 20
h = Signal.list
h["NEW"] = 99
p Signal.list.key?("NEW")

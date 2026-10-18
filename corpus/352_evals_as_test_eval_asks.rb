# Evals as test_eval asks (note 376): `return` in a string eval'd inside a
# proc whose method has returned is a LocalJumpError, as the proc's own
# `return` is (a live method is returned from, a lambda answers); a file name
# given to eval keeps its encoding in __FILE__; and `def nil.x` (true, false)
# defines on NilClass, as `def (nil).x` does.
def op1 = proc { return :x }
def op2 = proc { eval("return :ng") }
def ol = lambda { eval("return :ok") }
p((op1.call rescue $!.class))
p((begin; op2.call; rescue LocalJumpError => e; [e.class, e.reason, e.exit_value]; end))
p ol.call
def live
  pr = proc { eval("return :inner") }
  pr.call
  :after
end
p live
def n; eval("return 6"); 9; end
p n
fname = "あ".encode("euc-jp")
r = eval("__FILE__", nil, fname, 1)
p r == fname, r.encoding
p eval("__FILE__", nil, "plain.rb", 1).encoding
def nil.test_binding = :nb
def true.tt = :t
def false.ff = :f
p nil.test_binding, true.tt, false.ff, NilClass.instance_method(:test_binding).owner
class << nil
  remove_method :test_binding
end
p nil.respond_to?(:test_binding)

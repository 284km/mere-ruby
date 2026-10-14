# Lambdas as CRuby's test_lambda asks them (note 332): a lambda is a
# return boundary however it runs -- as a block too (`1.tap(&->(*) {
# return 0 })` returns from the lambda, not from the method around it) --
# and a stabby lambda with optional parameters still counts its arguments.
def t(n)
  r = begin; yield.inspect; rescue Exception => e; "#{e.class}: #{e.message}"; end
  puts "#{n}: #{r}"
end
def ret_cur310(v) = (1.tap(&->(*) { return 0 }); v)
def yb310 = yield
def ret_callee310(v) = (yb310(&->(*) { return 0 }); v)
def brk310(v) = (1.tap(&->(*) { break 0 }); v)
def proc_ret310 = ([1, 2].each(&proc { return :from_proc }); :after)
t(1) { [ret_cur310(42), ret_callee310(42), brk310(42), proc_ret310] }
t(2) { [instance_eval(&->(_) { return :ok }), instance_exec(&->() { return :ok2 })] }
t(3) { [[1, 2].map(&->(x) { return x * 10 }), [[1, 2]].map(&->(a) { a })] }
t(4) { [->(a, b, c = 3, d = 4) { [a, b, c, d] }.call(1, 2), (->(a, b = 1) {}.call rescue $!.message), (->(a, b = 1) {}.call(1, 2, 3) rescue $!.message)] }
t(5) { [(lambda { |a, b = 1| }.call rescue $!.message), (lambda { |a, b = 1| }.call(1, 2, 3) rescue $!.message), ->(a, b = 1, *c) { [a, b, c] }.call(1, 2, 3)] }
t(6) { l = ->(x) { return x + 1 }; [l.call(1), [1, 2].map(&l), l.(5)] }

# Calls and keywords as test_call and test_keyword ask them (note 346).
def t(name)
  r = begin; yield.inspect; rescue Exception => e; "#{e.class}: #{e.message[0, 70]}"; end
  puts "#{name}: #{r}"
end
$stderr = $stdout

# an argument error's backtrace starts in the callee, at its definition
def two(a, b) = 1
t(:arity) { begin; two(1); rescue => e; e.backtrace[0, 2]; end }
def kf(a:) = a
t(:unknown_kw) { begin; kf(a: 1, b: 2); rescue => e; [e.message, e.backtrace[0, 2]]; end }
t(:missing_kw) { begin; kf; rescue => e; [e.message, e.backtrace[0, 2]]; end }
o = Object.new
eval("def o.h(a:) = a", nil, "xyzzy")
t(:eval_path) { begin; o.h(a: 0, b: 1); rescue => e; [e.backtrace_locations[0].path, e.backtrace_locations[0].label]; end }
class K; def self.s(a) = a; def i(a) = a; end
t(:class_meth) { begin; K.s; rescue => e; e.backtrace[0, 2]; end }
t(:in_block) { begin; [1].each { K.new.i(1, 2) }; rescue => e; e.backtrace[0, 2]; end }
l = ->(a) { a }
t(:lambda) { begin; l.call; rescue => e; e.backtrace[0, 2]; end }
pr = proc { |a:| a }
t(:proc_kw) { begin; pr.call(a: 1, b: 2); rescue => e; e.backtrace[0, 2]; end }
b = eval("proc {|a:| a}", nil, "xyzzy", 1)
t(:proc_path) { begin; b.call(a: 0, b: 1); rescue => e; e.backtrace_locations[0].path; end }
t(:raise_inside) { begin; two(1, 2); [1].fetch(5); rescue => e; e.backtrace[0, 2]; end }

# keywords and blocks are refused in an index assignment
def se(src) = (begin; eval(src); "no error"; rescue SyntaxError => e; e.message[/(keyword|block) arg given in index assignment/]; end)
t(:ia_kwsplat) { se("h[**kw] += 1") }
t(:ia_kw) { se("h[kw: 1] = 2") }
t(:ia_both) { se("o[**o, &o] += 1") }
t(:ia_blk) { se("h[&o] = 2") }
t(:ia_or) { se("h[0, **kw] ||= 1") }

# a def run inside a method takes the method's scope
class TC
  KK = [1, 2]
  def m
    def self.a = yield(*KK)
    a { |*x| x }
  end
end
t(:nested_def) { TC.new.m }

# ruby2_keywords: warnings, an emptied flagged hash, a splat that is not last
t(:r2k_post) { ruby2_keywords def r2p(*a, b) = [a, b] }
t(:r2k_sym) { :foo.to_proc.ruby2_keywords; 1 }
def opt(a = :opt) = a
ruby2_keywords def clear_opt(*args) = (args.last.clear; opt(*args))
t(:r2k_empty) { clear_opt(a: 1) }
def kwargs(**kw) = kw
def single(arg) = arg
ruby2_keywords def foo(*args) = args
args = foo(a: 1)
marked = args.last
single(marked)
t(:r2k_after_positional) { x = kwargs(*args); [x, x.equal?(marked)] }
def yk(*a, **k) = [a, k]
def via(*v) = yk(*v, **{})
t(:r2k_not_last) { via(*args) }

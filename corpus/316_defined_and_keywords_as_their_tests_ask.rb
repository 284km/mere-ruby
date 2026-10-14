# defined? and keywords as CRuby's test_defined and test_keyword ask them
# (note 338): defined? looks into array and hash literals and splats, knows
# the methods every object has, asks respond_to_missing? for a call written
# with parentheses and answers one shared frozen String per answer; #dig
# passes its keys on positionally; a to_enum size block gets the enumerator's
# arguments; a Yielder checks a lambda's arguments; a kwrest overwritten
# before a bare super must still be a Hash; ruby2_keywords names methods.
def t(n)
  r = begin; yield.inspect; rescue Exception => e; "#{e.class}: #{e.message.gsub(/0x\h+/, '0x')}"; end
  puts "#{n}: #{r}"
end
t(1) { [defined?([*a]), defined?(itself(*a)), defined?([*itself]), defined?(itself(*itself)), defined?([1, *[2]])] }
t(2) { [defined?({a: a}), defined?({a => 1}), defined?({**a}), defined?(itself(a: a)), defined?({a: 1})] }
t(3) { [defined?(String).frozen?, defined?(String).equal?(defined?(Array)), defined?(@nope316), defined?(dup)] }
class RTM316
  attr_reader :called
  def initialize; @called = false; end
  def respond_to_missing?(n, p = false); @called = true; n == :existing_method; end
  def fe = defined?(existing_method())
  def fn = defined?(non_existing_method())
  def fv = defined?(non_existing_method)
end
t(4) { o = RTM316.new; a = [o.fv, o.called]; [*a, o.fe, o.fn, o.called] }
t(5) {
  c = Object.new; def c.dig(**args) = args
  d = Object.new; def d.method_missing(_, *args) = args
  e = Object.new; def e.dig(*args) = args
  [([c].dig(0, a: 1) rescue $!.class), [d].dig(0, a: 1), {k: e}.dig(:k, 1, b: 2), ({k: 1}.dig(:k, 2) rescue $!.message)]
}
t(6) { c = Object.new; m = ->(*args) { args }; m2 = ->(*args, **kw) { [args, kw] }
       [c.to_enum(:each, 1, 2, &m).size, c.to_enum(:each, 1, a: 1, &m).size, c.to_enum(:each, **{}, &m).size, c.to_enum(:each, 1, a: 1, &m2).size] }
t(7) { g = Enumerator::Generator; f = -> { true }
       [(g.new { |y| y.yield(a: 1) }.each(&f) rescue $!.message), g.new { |y| y.yield(**{}) }.each(&f), (g.new { |y| y << 1 }.each(&f) rescue $!.class), g.new { |y| y.yield 1, 2 }.each { |a, b| [a, b] }] }
t(8) {
  k = Class.new { def initialize(**h); @h = h; end; attr_reader :h }
  k2 = Class.new(k) { def initialize(d:, **h); h = [2, 3]; super; end }
  k3 = Class.new(k) { def initialize(d:, **h); h = nil; super; end }
  [(k2.new(d: 4) rescue $!.message), k3.new(d: 4).h]
}
t(9) { [(Class.new { ruby2_keywords } rescue $!.message)] }
$stderr = $stdout
o316 = Object.new
def o316.foo(*args) = yield(*args)
o316.method(:foo).to_proc.ruby2_keywords
t(10) { :warned_above }

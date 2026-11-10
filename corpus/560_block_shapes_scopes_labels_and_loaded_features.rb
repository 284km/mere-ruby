# Round 10 of note 537 (the interpreter's structure): Enumerable#map hands
# #each a block of the user block's arity (and Hash#each yields a two-argument
# one the key and value apart); a block's assigned name is its own when the
# enclosing scope does not have it yet; a second `_` parameter is its own;
# a def inside a define_method'd proc goes where the proc was written;
# main.using in a wrapped load; Lazy#with_object; Lazy#grep's $~ in a
# method; `K.raise { }` for a class with its own raise; Thread#raise(e)
# keeps e's backtrace; block labels count the blocks as written; `break` in a
# Thread body; TracePoint target_line checks; $LOADED_FEATURES' raw entries
# and the load path; $LOAD_PATH.resolve_feature_path; pp shipped; an Errno
# message about a binary path is binary.
require "tmpdir"

# --- map's block for #each has the user block's arity
class Nums
  include Enumerable
  def initialize(*a) = @a = a
  def each(&b) = (@a.each(&b); self)
end
n = Nums.new(1, 2, 3)
def n.each(&block)
  $arities << block.arity
  super
end
$arities = []
p n.map { |a, b| a }, n.collect { |i| i }, n.map { |*x| x }, $arities
two = Class.new { def r(a, b) = [a, b]; def one(a) = a }.new
p({1 => :a, 2 => :b}.map(&two.method(:r)))
p({1 => :a}.map(&two.method(:one)))
p({1 => 2}.map(&->(k, v) { k + v }))

# --- a block's own locals, decided where the block is made
e = Enumerator.new { |y| r = y.yield 3; y << r << 2 << 1 }
r = []
e.each { |x| r << x; x * 2 }
p r
x = 1
[1].each { |i| x = 5; fresh = 7 }
p [x, defined?(fresh)]
pr = proc { |a| w = a; w }
w = 0
p [pr.call(4), w]
for q in [1, 2]; qq = q; end
p qq
# (a local the receiver or the arguments assign is written before the block)
sm = []
p [(sm << mm = 58).map { |v| mm += 1; v }, mm]
p [[1].each_with_object(ww = []) { |v, acc| ww << v; acc << v }, ww]
class DMLocals
  define_method(:f) { |*a| rr = a.size; rr }
  define_method(:g) { |v; zz| zz = v; zz }
end
p [DMLocals.new.f(1, 2), DMLocals.instance_method(:f).arity, DMLocals.new.g(3), DMLocals.instance_method(:g).arity]

# --- a second `_` is a parameter of its own
p proc { |_, _ = 1, _:, _: 2| }.parameters
p(-> _, _, _ = 1, *_, _:, _: 2, **_, &_ {}.parameters)

# --- a def inside a define_method'd proc
class Home; P = -> { def made_at_home = 42 }; end
class Away; define_method(:run, Home::P); end
Away.new.run
p [Home.new.respond_to?(:made_at_home), Away.new.respond_to?(:made_at_home)]

# --- main.using in a wrapped load
Dir.mktmpdir do |d|
  File.write("#{d}/u1.rb", "using Module.new\n")
  File.write("#{d}/u2.rb", "MAIN560 = self\nmodule X560; MAIN560.send(:using, Module.new); end\n")
  File.write("#{d}/u3.rb", "def foo560 = using(Module.new)\nfoo560\n")
  %w[u1 u2 u3].each do |f|
    begin
      load "#{d}/#{f}.rb", true
      p [f, :ok]
    rescue => ex
      p [f, ex.class, ex.message]
    end
  end
end

# --- Lazy#with_object, Lazy#grep's $~ inside a method
p (0..Float::INFINITY).lazy.with_object(:o).first(2)
def lazy_grep
  "z" =~ /z/
  got = ["abc", "def"].lazy.grep(/b/) { |s| [s, $&] }.force
  [got, $~]
end
p lazy_grep

# --- a class with its own raise, called with a block
class OwnRaise
  def self.raise(*a, &b) = [:own, a, b ? b.call : nil]
end
p OwnRaise.raise(1) { :blk }

# --- Thread#raise(e): e as it was, backtrace and all
ex0 = nil
begin; raise "raised"; rescue => ex0; end
t = Thread.new { Thread.current.report_on_exception = false; sleep }
Thread.pass until t.stop?
t.raise(ex0)
got = (t.join rescue $!)
p [got == ex0, got.backtrace == ex0.backtrace]

# --- block labels count the blocks as written, not the frames around them
def run_it(&b) = Object.new.instance_exec(&b)
labels = []
[1].each do
  run_it do
    labels << caller_locations(0, 1)[0].label
    -> { labels << caller_locations(0, 1)[0].label }.call
    Thread.new { labels << caller_locations(0, 1)[0].label }.join
  end
end
p labels

# --- `break` in a Thread body is LocalJumpError, where it is
t = Thread.new do
  begin
    break :brk
  rescue LocalJumpError => lje
    [lje.class, lje.reason, lje.exit_value]
  end
end
p t.value
p Thread.new { i = 0; while true; i += 1; break if i > 2; end; i }.value

# --- TracePoint target_line
tp = TracePoint.new(:line) {}
[[1, -> { }], [-2, -> { }], [Object.new, -> { }]].each do |tl, tgt|
  begin
    tp.enable(target_line: tl, target: tgt) { }
  rescue => ex
    p [ex.class, ex.message.sub(/Object/, "X")]
  end
end

# --- $LOADED_FEATURES: raw entries, the load path, a missing .rb
Dir.mktmpdir do |d|
  Dir.mkdir("#{d}/code"); Dir.mkdir("#{d}/code/b"); Dir.mkdir("#{d}/code/c")
  %w[code code/b code/c].each { |s| File.write("#{d}/#{s}/lf560.rb", "$lf560 << #{s.inspect}\n") }
  $lf560 = []
  lp = $LOAD_PATH.dup
  lf = $LOADED_FEATURES.dup
  begin
    Dir.chdir("#{d}/code") do
      $LOADED_FEATURES << "./lf560.rb"
      p require("./lf560.rb")
      $LOADED_FEATURES << "../code/lf560.rb"
      p require("../code/lf560.rb")
    end
    # (ruby resolves an entry pushed by hand against the cwd when it next
    #  indexes the features -- not asked here)
    $LOADED_FEATURES.replace(lf.dup)
    $LOAD_PATH.unshift "#{d}/code"
    p require("lf560")
    $LOAD_PATH.unshift "#{d}/code/b"
    p require("lf560")
    $LOADED_FEATURES << "#{d}/code/c/x560.so"
    File.write("#{d}/code/c/x560.rb", "$lf560 << :x\n")
    p require("#{d}/code/c/x560")
    $LOADED_FEATURES << "nofile560"
    p require("nofile560")
    p $lf560
  ensure
    $LOAD_PATH.replace(lp)
    $LOADED_FEATURES.replace(lf)
  end
end

# --- resolve_feature_path, and pp is there to require
p $LOAD_PATH.resolve_feature_path("pp").then { |k, f| [k, File.basename(f)] }
p $LOAD_PATH.resolve_feature_path("etc").then { |k, f| [k, File.basename(f, ".*")] }
p $LOAD_PATH.resolve_feature_path("no_such_feature_560")
p require("pp"), [1, {a: 2}].pretty_inspect
p [$:.size > 0, $:.all? { |s| s.is_a?(String) }]

# --- an Errno about a binary path is binary
begin
  File.stat("/missing560\xE3E4".b)
rescue SystemCallError => ex
  p [ex.class, ex.message.encoding, ex.message.include?("/missing560\xE3E4".b)]
end

# --- round 11: a lambda's own locals are no parameters of the method it
# becomes; File.new(fd) is a File; IO#reopen(io) takes the other's mode and
# class, a singleton method on the stream notwithstanding
class DMLambda
  define_method(:x, lambda { |*a, &b| tt = a.size; [a, tt] })
end
p DMLambda.new.x(1, 2)
Dir.mktmpdir do |d|
  File.write("#{d}/r", "L1\nL2\n")
  fd = IO.sysopen("#{d}/r")
  f = File.new(fd)
  p [f.class, f.gets]
  f.close
  w = IO.new(IO.sysopen("#{d}/w", "w", 0644), "w")
  def w.to_io = raise("not asked")
  r = IO.new(IO.sysopen("#{d}/r", "r"), "r")
  p [w.reopen(r).class, w.gets]
  w.close
  r.close
end

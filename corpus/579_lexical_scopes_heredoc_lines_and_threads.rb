# Round 16 of note 541: binding.local_variables lists a scope's locals from
# where the scope begins (a later `b = 1` already counts, parameters first);
# an interpolation in a heredoc's body runs at its own line; the first
# Thread.new returns before the thread begins; Refinement#import_methods
# refuses what is not Ruby code (a C extension's, a define_method's); a Hash
# with a singleton #each goes through it for Enumerable's methods; and
# ObjectSpace::WeakKeyMap stores keep their refusals.
require "zlib"

# --- binding.local_variables (in a method: the main script's own locals,
#     declared further down, are listed by ruby and not here)
def lv_blocks
  [1].each { p binding.local_variables; a = 1; b = 2 }
  [1].each { |x| p binding.local_variables; c = 1 }
end
lv_blocks
def lv_m
  p binding.local_variables
  d = 1
  e = 2
end
lv_m
def lv_eval = proc { |a| b = 1; eval("c = 2; binding.local_variables") }.call(0)
p lv_eval

# --- a heredoc interpolation's line
def line_of
  yield
rescue NameError => e
  e.backtrace[0][/:(\d+):/, 1].to_i - __LINE__
end
p(line_of {
  <<-HERE.chomp
    a
    #{undefined_c}
  HERE
})
p(line_of {
  <<~HERE
    #{undefined_d}
  HERE
})
p(line_of { [<<-A, <<-B]
  #{undefined_e}
  A
  #{undefined_f}
  B
})

# --- the first thread begins after Thread.new returns
seen = []
TracePoint.new(:thread_begin) { seen << (Thread.current == $t) }.enable(target_thread: nil) do
  $t = Thread.new {}
  seen << $t.status
  $t.join
end
p seen

# --- import_methods
module Mine
  def a = :a
  define_method(:b) { :b }
end
module OnlyRuby
  def c = :c
end
Module.new do
  refine(String) do
    [Zlib, Mine, OnlyRuby].each do |m|
      import_methods m
      p [m, :imported]
    rescue ArgumentError => e
      p [m, e.message[/\A[^:]+/], e.message.include?("#{m}#")]
    end
  end
end
p Zlib.private_instance_methods(false).sort

# --- a Hash with a singleton #each
log = []
h = {1 => "a", 2 => "b"}
h.define_singleton_method(:each) { |&b| log << :each; super(&b) }
p h.map { |k, v| v }, h.flat_map { |k, v| [k] }, h.count, h.min_by { |k, v| -k }
p h.select { |k, v| k > 1 }, h.to_a, h.include?(1)
p log.size

# --- ObjectSpace::WeakKeyMap
m = ObjectSpace::WeakKeyMap.new
k1 = Object.new
p (m[k1] = 5), m[k1], m.getkey(k1).equal?(k1)
[nil, true, 1, 1.5, :s, 2**70].each do |bad|
  begin
    m[bad] = 1
  rescue ArgumentError => e
    p e.message
  end
end
begin
  m[BasicObject.new] = 1
rescue NoMethodError => e
  p e.class
end
s = +"str"
m[s] = 1
p m.getkey("str").equal?(s), m.key?("str")
10_000.times { m[Object.new] = 1 }
m.clear
p m.inspect[/size=\d+/]

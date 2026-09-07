def try(l)
  p l.call
rescue => e
  puts "#{e.class}: #{e.message}"
end

# ---- 1. a Float max is TRUNCATED, and the answer is an Integer ----------
# Scaling the float directly answered a Float for every one of them; ruby
# truncates the max first and only a max that truncates to zero stays a Float.
srand(1234)
p [rand(1.5).class, rand(2.5).class, rand(1.0).class, rand(0.5).class,
   rand(1.5) <= 1, rand(2.5) <= 2, rand(0.5) < 0.5, rand(3).class]
p [rand(1.5), rand(1.0)]

# ---- 2. hex digits sit on both sides of an underscore -------------------
# ruby 3.2's reader stopped its strtod at the first underscore and then wanted
# DECIMAL digits only; this was written against that reference.
%w[0xa1_0 0x1_0a 0x1_f 0xa_b_c 0x1p1_0 1_0.5 1_0e1_0 .5 5.].each do |s|
  puts "#{s} = #{Float(s).inspect}"
end
# ...the rules that did NOT move are about the underscore's POSITION.
%w[0x_1 0x1__0 0x1f_ 1__0.5 1_.5].each do |s|
  begin
    Float(s)
    puts "#{s} accepted"
  rescue => e
    puts "#{s} ! #{e.class}"
  end
end

# ---- 3. nil / true / false accept a singleton method -------------------
# Their singleton class IS the class, and ruby defines the method there --
# refusing was the only answer here.
p nil.define_singleton_method(:c203_n) { :n }
p true.define_singleton_method(:c203_t) { :t }
p [nil.c203_n, true.c203_t, NilClass.instance_method(:c203_n).owner]
NilClass.send(:remove_method, :c203_n)
TrueClass.send(:remove_method, :c203_t)
[-> { 1.define_singleton_method(:x) { } },
 -> { :s.define_singleton_method(:x) { } }].each { |f| try(f) }

# ---- 4. one name is one name, however many doors know it ---------------
# Three doors added to this list and two added the same names, so it answered
# 137 entries of which 69 were distinct. And chomp / chop / sub / gsub are -n
# only: ruby does not list them, and this interpreter has no -n.
k = Kernel.private_instance_methods(false)
p [k.size == k.uniq.size, k.include?(:chomp), k.include?(:chop),
   k.include?(:sub), k.include?(:gsub), k.include?(:initialize)]
p [k.include?(:puts), k.include?(:format), k.include?(:raise), k.include?(:loop),
   k.include?(:require), k.include?(:block_given?)]
p [defined?(chomp), defined?(puts)]
pub = Kernel.public_instance_methods(false)
p pub.size == pub.uniq.size

# ---- 5. SystemCallError takes a LOCATION as its third argument ---------
# The message builder knew about a location all along; the constructor took
# two parameters, so the three-argument form was a wrong-arity call.
p [SystemCallError.new("msg", 2, "loc").message,
   SystemCallError.new("msg", 2, "loc").errno,
   SystemCallError.new("msg", 2, "loc").class,
   SystemCallError.new("msg", 2, nil).message,
   Errno::ENOENT.new("msg", "loc").message,
   SystemCallError.new("msg", 999, "loc").message]

# ---- 6. a C method's parameters come from its ARITY --------------------
# An empty list claims a method that takes nothing; ruby derives them from the
# arity, with no names. A method the object only CLAIMS through
# respond_to_missing? is [[:rest]].
p [1.method(:+).parameters, 1.method(:between?).parameters,
   [].method(:push).parameters, [].method(:size).parameters,
   [].method(:each).parameters, 1.method(:to_s).parameters]
class Claims203
  def respond_to_missing?(n, priv) = true
  def method_missing(n, *a) = :mm
end
c = Claims203.new
p [c.method(:whatever).parameters, c.method(:whatever).arity,
   c.method(:whatever).name, c.method(:whatever).owner, c.method(:whatever).call]

# ---- 7. `public :m` in a subclass makes that subclass the owner --------
# A visibility statement is a method entry in ruby; reading the method table
# alone walked past it to the ancestor that wrote the body.
class Ancestor203
  private

  def hidden = :h
end
class Descendant203 < Ancestor203
  public :hidden
end
p [Descendant203.instance_method(:hidden).owner,
   Descendant203.new.method(:hidden).owner,
   Ancestor203.instance_method(:hidden).owner,
   Descendant203.new.hidden]
try -> { Ancestor203.new.hidden }

# ---- 8. the backtrace is captured AT THE RAISE ------------------------
# #backtrace is asked long after `$!` has moved on, and keying the answer on
# "is this still $!" answered nil for every one of those.
e1 = begin
  raise
rescue RuntimeError
  $!
end
p [e1.class, e1.message, e1.backtrace.class, e1.backtrace.first.class,
   !!(e1.backtrace.first =~ /203_visibility/), !!(e1.backtrace.first =~ /:\d+:in /)]
e2 = begin
  raise "boom"
rescue => x
  x
end
p [e2.message, e2.backtrace.class, !!(e2.backtrace.first =~ /203_visibility/)]
bt = begin
  raise "and $@ is a view on it"
rescue
  $@
end
p [bt.class, bt.size >= 1, !!(bt.first =~ /203_visibility/)]
# ...and set_backtrace still wins over the captured one.
e3 = RuntimeError.new("set")
e3.set_backtrace(["a:1:in 'x'"])
p [e3.backtrace, (begin ; raise e3 ; rescue => y ; y.backtrace ; end)]
p [RuntimeError.new("never raised").backtrace]

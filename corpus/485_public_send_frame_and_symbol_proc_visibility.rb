# Kernel#public_send is a method of its own in a backtrace (send and __send__
# are not), &:sym calls only public methods, and an explicit receiver keeps a
# singleton class's private methods private -- main's included.
class C
  def boom; raise "x"; end
  def here; caller(0)[0, 2].map { |l| l[/'.*'/] }; end
  def pub; :pub; end
  protected def pro; :pro; end
  private def pri; :pri; end
  def inside; [(tap(&:pro) rescue $!.class), (tap(&:pri) rescue $!.class), tap(&:pub).class]; end
end
c = C.new
begin; c.public_send(:boom); rescue => ex; p ex.backtrace[0, 2].map { |l| l[/'.*'/] }; end
begin; c.send(:boom); rescue => ex; p ex.backtrace[0, 2].map { |l| l[/'.*'/] }; end
p c.public_send(:here)
p c.__send__(:here)
[-> { public_send() }, -> { public_send(Object.new) }, -> { c.public_send(:nope) }].each do |l|
  begin; l.call; rescue => ex; p [ex.class, ex.backtrace[0][/'.*'/]]; end
end
p [1, 2].public_send(:map) { |x| caller(0)[1][/'.*'/] }
p c.inside
p((c.tap(&:pro) rescue $!.class), (c.tap(&:pri) rescue $!.class))
p [c].map(&:pub)

singleton_class.class_eval do
  public def m_pub; :m_pub; end
  protected def m_pro; :m_pro; end
  private def m_pri; :m_pri; end
end
m = self
p [m.m_pub, m.m_pro, (m.m_pri rescue $!.message)]
p [tap(&:m_pub).class, (tap(&:m_pro) rescue $!.message), (tap(&:m_pri) rescue $!.message)]
def top_level; :top; end
p((m.top_level rescue $!.message))
p self.top_level
s = +"str"
def s.secret; :s; end
s.singleton_class.send(:private, :secret)
p((s.secret rescue $!.class))
p s.send(:secret)

# Kernel#eval taken as a Method reads its caller's frame
class C
  method(:eval).call("def made_by_method_eval; :made; end")
end
p C.new.made_by_method_eval
x = 5
p method(:eval).call("x + 1")
# Kernel#warn bound to Warning writes the text itself
def Warning.warn(*a, **k) = raise("Warning.warn called")
$stderr = $stdout
Kernel.instance_method(:warn).bind(Warning).call("bound to Warning")
$stderr = STDERR
p Regexp.new("a").send(:initialize, "b") rescue p [$!.class, $!.message]
def kw(a: 1, b:, c: 2, d:); end
p method(:kw).parameters
p proc { |x, y: 1, z:| }.parameters

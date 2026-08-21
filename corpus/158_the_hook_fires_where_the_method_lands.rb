# `method_added` belongs where a method is INSTALLED, not where the `def` is
# written, and it fires AFTER the visibility is recorded -- ruby's hook sees the
# method as it finally is. Both were wrong here, and thor found both: it asks
# `public_method_defined?(meth)` and returns unless the method is public, and it
# wraps its own helpers in `no_commands do ... def ... end`.
class Seen
  @log = []
  def self.log; @log; end
  def self.method_added(m); @log << [m, public_method_defined?(m)]; end

  def plain; end
  [1].each { def in_a_block; end }
  if true
    def in_an_if; end
  end
  begin
    def in_a_begin; end
  end
  1.times { def in_a_times; end }

  private
  def a_private_one; end
  protected
  def a_protected_one; end
  public
  def public_again; end
end
p Seen.log

# ... and the flag a hook sets while methods are being defined is visible to it,
# which is the shape thor's `no_commands` relies on.
class Ctx
  @depth = 0
  @seen = []
  def self.seen; @seen; end
  def self.quiet
    @depth += 1
    yield
  ensure
    @depth -= 1
  end
  def self.quiet?; @depth > 0; end
  def self.method_added(m); @seen << [m, quiet?]; end

  def loud; end
  quiet do
    def hushed1; end
    def hushed2; end
  end
  def loud2; end
end
p Ctx.seen

# a singleton definition fires nothing, as in ruby
class NoFire
  @log = []
  def self.log; @log; end
  def self.method_added(m); @log << m; end
  def self.a_class_method; end
  def an_instance_method; end
end
p NoFire.log

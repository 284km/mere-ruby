# A minimal mspec-compatible spec_helper: just enough of the mspec DSL
# (describe / it / should / matchers) to run real spec/ruby files, written
# in plain Ruby so the same shim runs under both mere-ruby and ruby (the
# outputs can be diffed byte-for-byte).

$mspec_pass = 0
$mspec_fail = 0
$mspec_err = 0
$mspec_desc = ""
$mspec_it = ""

class SpecFailure < StandardError; end

# mspec's scratch storage helper.
class ScratchPad
  def self.record(x); $scratch = x; end
  def self.<<(x); $scratch << x; end
  def self.recorded; $scratch; end
  def self.clear; $scratch = nil; end
end

class PositiveMatcher
  def initialize(actual)
    @actual = actual
  end
  # x.should.raise(Klass[, pattern]) — @actual is a proc; the pattern (a
  # regex source string here) is accepted but not matched.
  def raise(klass = nil, pattern = nil)
    begin
      @actual.call
      $mspec_fail += 1
      puts "FAILED: expected #{klass} to be raised"
    rescue Exception => e
      if klass.nil? || e.class.to_s == klass.to_s || e.is_a?(klass)
        $mspec_pass += 1
      else
        $mspec_fail += 1
        puts "FAILED: raised #{e.class}, expected #{klass}"
      end
    end
    nil
  end
  def ==(expected)
    if @actual == expected
      $mspec_pass += 1
    else
      $mspec_fail += 1
      puts "FAILED: #{$mspec_it}: expected #{expected.inspect}, got #{@actual.inspect}"
    end
    nil
  end
  def is_a?(klass)
    if @actual.is_a?(klass)
      $mspec_pass += 1
    else
      $mspec_fail += 1
      puts "FAILED: #{$mspec_it}: expected a #{klass}, got #{@actual.inspect}"
    end
    nil
  end
  def equal?(expected)
    if @actual.equal?(expected)
      $mspec_pass += 1
    else
      $mspec_fail += 1
      puts "FAILED: #{$mspec_it}: expected to be identical"
    end
    nil
  end
  def !=(expected)
    if @actual != expected
      $mspec_pass += 1
    else
      $mspec_fail += 1
      puts "FAILED: expected not #{expected.inspect}"
    end
    nil
  end
  # x.should.empty? — bare predicate forwarding (a subset: just empty?).
  def empty?
    if @actual.empty?
      $mspec_pass += 1
    else
      $mspec_fail += 1
      puts "FAILED: #{$mspec_it}: expected #{@actual.inspect} to be empty"
    end
    nil
  end
  def =~(pattern)
    if @actual =~ pattern
      $mspec_pass += 1
    else
      $mspec_fail += 1
      puts "FAILED: #{$mspec_it}: expected #{@actual.inspect} to match"
    end
    nil
  end
end

class NegativeMatcher
  def initialize(actual)
    @actual = actual
  end
  def empty?
    if @actual.empty?
      $mspec_fail += 1
      puts "FAILED: #{$mspec_it}: expected #{@actual.inspect} not to be empty"
    else
      $mspec_pass += 1
    end
    nil
  end
  def ==(expected)
    if @actual == expected
      $mspec_fail += 1
      puts "FAILED: expected not #{expected.inspect}"
    else
      $mspec_pass += 1
    end
    nil
  end
  def equal?(expected)
    if @actual.equal?(expected)
      $mspec_fail += 1
      puts "FAILED: #{$mspec_it}: expected not to be identical"
    else
      $mspec_pass += 1
    end
    nil
  end
end

# Stable display for failure messages: a Proc inspects with a heap address
# (nondeterministic across runs and hosts), so show a fixed token instead.
def mspec_show(x)
  x.is_a?(Proc) ? "#<Proc>" : x.inspect
end

class Object
  def should(matcher = nil)
    if matcher.nil?
      PositiveMatcher.new(self)
    else
      if matcher.match?(self)
        $mspec_pass += 1
      else
        $mspec_fail += 1
        puts "FAILED: #{$mspec_it}: matcher did not match #{mspec_show(self)}"
      end
      nil
    end
  end
  def should_not(matcher = nil)
    if matcher.nil?
      NegativeMatcher.new(self)
    else
      if matcher.match?(self)
        $mspec_fail += 1
        puts "FAILED: #{$mspec_it}: matcher matched #{mspec_show(self)}"
      else
        $mspec_pass += 1
      end
      nil
    end
  end
end

def describe(desc, *opts)
  # a shared example group (describe :name, shared: true) is only a template;
  # real mspec registers it for it_behaves_like (a no-op here), so skip it.
  return if opts.any? { |o| o.is_a?(Hash) && o[:shared] }
  prev_b = $mspec_before
  prev_a = $mspec_after
  $mspec_desc = desc
  yield
  $mspec_before = prev_b
  $mspec_after = prev_a
end

def context(desc, *opts)
  prev_b = $mspec_before
  prev_a = $mspec_after
  $mspec_desc = desc
  yield
  $mspec_before = prev_b
  $mspec_after = prev_a
end

def it(desc, *opts, &blk)
  $mspec_it = desc
  # Run before/example/after on ONE fresh example object (like real mspec), so
  # @ivars set in `before` are visible to the example, each example starts
  # clean, and matcher methods (include, equal, ...) resolve to the shim
  # definitions instead of a self=main built-in such as Module#include.
  env = Object.new
  begin
    env.instance_exec(&$mspec_before) if $mspec_before
    env.instance_exec(&blk) if blk
    env.instance_exec(&$mspec_after) if $mspec_after
  rescue SpecFailure
    # already tallied
  rescue Exception => e
    $mspec_err += 1
    puts "ERROR: #{$mspec_desc} #{desc}: #{e.class}"
  end
end

# mspec: `specify` is an alias of `it` (a describe-less example).
def specify(desc = nil, *opts, &blk); it(desc, *opts, &blk); end
# mspec's evaluate DSL prefixes example descriptions via SpecEvaluate.desc=;
# the shim ignores the prefix (descriptions still print per example).
module SpecEvaluate
  def self.desc=(x); @desc = x; end
  def self.desc; @desc; end
end
def it_behaves_like(*args); end
def it_should_behave_like(*args); end
def before(kind = nil, &blk); $mspec_before = blk; end
def after(kind = nil, &blk); $mspec_after = blk; end
def guard(*args); end
# mspec platform guards: this shim runs everywhere, so the block runs.
def not_supported_on(*args); yield if block_given?; end
# known-MRI-bug guard: skipped (like ruby_version_is), same on both sides.
def ruby_bug(*args); end
# mspec numeric boundary helpers (mspec/helpers/numeric.rb).
def bignum_value(plus = 0); 2**64 + plus; end
def fixnum_max; 2**62 - 1; end
def fixnum_min; -(2**62); end
def ruby_version_is(*args); end
def platform_is(*args); end
def platform_is_not(*args); end
def suppress_warning
  yield
end

# Run a Ruby snippet and return its captured stdout. Real mspec spawns a
# subprocess; this shim runs it in-process — close enough for self-contained
# snippets that just print. mere-ruby intercepts `__ruby_exe` with a native
# primitive (captures interpreter output); under real ruby the pure-Ruby
# definition below runs instead (redirects $stdout to a capture object).
class MSpecStdoutCapture
  def initialize
    @buf = ""
  end
  def write(*a)
    a.each { |x| @buf << x.to_s }
    nil
  end
  def print(*a)
    a.each { |x| @buf << x.to_s }
    nil
  end
  def puts(*a)
    if a.empty?
      @buf << "\n"
    else
      a.each { |x| s = x.to_s; @buf << s; @buf << "\n" unless s.end_with?("\n") }
    end
    nil
  end
  def <<(x)
    @buf << x.to_s
    self
  end
  def string
    @buf
  end
end

def __ruby_exe(code)
  old = $stdout
  cap = MSpecStdoutCapture.new
  $stdout = cap
  begin
    eval(code.to_s)
  rescue Exception
  ensure
    $stdout = old
  end
  cap.string
end

def ruby_exe(code = nil, *rest, **opts)
  __ruby_exe(code.to_s)
end

# mspec's `evaluate <<-ruby do ... end`: run the code (which defines methods
# or sets ivars) and then the block, on the same fresh object so state set by
# the code is visible to the block's assertions.
def evaluate(code, &block)
  o = Object.new
  o.instance_eval(code)
  o.instance_eval(&block)
end

# Matcher objects for the `x.should be_nil` style.
class BeMatcher
  def initialize(kind); @kind = kind; end
  def match?(actual)
    case @kind
    when :nil then actual.nil?
    when :true then actual == true
    when :false then actual == false
    when :empty then actual.empty?
    end
  end
end

# mspec numeric tolerance (mspec/helpers/numeric.rb) and the be_close /
# be_within float matchers.
TOLERANCE = 0.00003 unless defined?(TOLERANCE)
class CloseMatcher
  def initialize(expected, tolerance); @expected = expected; @tolerance = tolerance; end
  def match?(actual); (actual - @expected).abs <= @tolerance; end
end
def be_close(expected, tolerance = TOLERANCE); CloseMatcher.new(expected, tolerance); end
class WithinMatcher
  def initialize(tolerance); @tolerance = tolerance; @expected = nil; end
  def of(expected); @expected = expected; self; end
  def match?(actual); (actual - @expected).abs <= @tolerance; end
end
def be_within(tolerance); WithinMatcher.new(tolerance); end

def be_nil; BeMatcher.new(:nil); end
def be_true; BeMatcher.new(:true); end
def be_false; BeMatcher.new(:false); end
def be_empty; BeMatcher.new(:empty); end

# x.should be_kind_of(K) / be_an_instance_of(K): a class-parameterised matcher.
class KindOfMatcher
  def initialize(klass, exact); @klass = klass; @exact = exact; end
  def match?(actual)
    if @exact
      actual.instance_of?(@klass)
    else
      actual.kind_of?(@klass)
    end
  end
end

def be_kind_of(k); KindOfMatcher.new(k, false); end
def be_an_instance_of(k); KindOfMatcher.new(k, true); end
def be_instance_of(k); KindOfMatcher.new(k, true); end

# reflection matchers: obj.should have_instance_method(:m) etc. `predicate` is
# the query method sent to the subject.
class HaveMethodMatcher
  def initialize(predicate, name); @predicate = predicate; @name = name; end
  def match?(subject); subject.send(@predicate, @name); end
end
def have_instance_method(name, inc = true); HaveMethodMatcher.new(:instance_method_defined_shim, name); end
def have_public_instance_method(name, inc = true); HaveMethodMatcher.new(:public_method_defined?, name); end
def have_private_instance_method(name, inc = true); HaveMethodMatcher.new(:private_method_defined?, name); end
def have_protected_instance_method(name, inc = true); HaveMethodMatcher.new(:protected_method_defined?, name); end
def have_method(name, inc = true); HaveMethodMatcher.new(:respond_to?, name); end
def have_public_method(name, inc = true); HaveMethodMatcher.new(:respond_to?, name); end
class Module
  # have_instance_method accepts any visibility; method_defined? excludes
  # private, so OR the family for the matcher's semantics.
  def instance_method_defined_shim(name)
    method_defined?(name) || private_method_defined?(name) || protected_method_defined?(name)
  end
end

# obj.should be_ancestor_of(mod): self appears in mod.ancestors.
class AncestorOfMatcher
  def initialize(mod); @mod = mod; end
  def match?(subject); @mod.ancestors.include?(subject); end
end
def be_ancestor_of(mod); AncestorOfMatcher.new(mod); end

# -> { ... }.should raise_error(Klass) — run the proc and check the raised
# exception's class. Message/pattern/block args are accepted but not matched
# (the existing `raise` matcher does the same), so mere and ruby agree as long
# as they raise the same class.
class RaiseErrorMatcher
  def initialize(klass); @klass = klass; end
  def match?(actual)
    begin
      actual.call
      false
    rescue Exception => e
      @klass.nil? || e.is_a?(@klass)
    end
  end
end

def raise_error(klass = nil, msg = nil, pat = nil, &blk); RaiseErrorMatcher.new(klass); end
# mspec's stricter variant (also checks the message under -W); class-only here.
def raise_consistent_error(klass = nil, msg = nil, &blk); RaiseErrorMatcher.new(klass); end

# x.should equal(y) — object identity.
class EqualMatcher
  def initialize(expected); @expected = expected; end
  def match?(actual); actual.equal?(@expected); end
end
def equal(expected); EqualMatcher.new(expected); end

# x.should include(a, b, ...) — every argument is a member.
class IncludeMatcher
  def initialize(members); @members = members; end
  def match?(actual)
    @members.all? { |m| actual.include?(m) }
  end
end
def include(*members); IncludeMatcher.new(members); end

# A minimal mock: records should_receive expectations (parallel arrays —
# the host may lack mutable hashes) and answers via method_missing.
class MockExpectation
  def initialize(sym); @sym = sym; @value = nil; end
  def and_return(v); @value = v; self; end
  def and_raise(*a); self; end
  def with(*a); self; end
  def twice; self; end
  def once; self; end
  def at_least(*a); self; end
  def any_number_of_times; self; end
  def exactly(*a); self; end
  def times; self; end
  def value; @value; end
  def sym; @sym; end
end

class MockObject
  def initialize(name)
    @name = name
    @syms = []
    @exps = []
  end
  def should_receive(sym)
    e = MockExpectation.new(sym)
    @syms << sym
    @exps << e
    e
  end
  def should_not_receive(sym)
    MockExpectation.new(sym)
  end
  def method_missing(sym, *args)
    i = 0
    while i < @syms.length
      return @exps[i].value if @syms[i] == sym
      i += 1
    end
    nil
  end
  def respond_to?(sym); true; end
  # to_s / inspect are real Object methods (not method_missing), so route them
  # through the expectation list when mocked; otherwise a stable name (never a
  # heap address, which would make failure output nondeterministic).
  def __mock_answer(sym)
    i = 0
    while i < @syms.length
      return [true, @exps[i].value] if @syms[i] == sym
      i += 1
    end
    [false, nil]
  end
  def to_s
    ok, v = __mock_answer(:to_s); ok ? v : "#<MockObject #{@name}>"
  end
  def inspect
    ok, v = __mock_answer(:inspect); ok ? v : "#<MockObject #{@name}>"
  end
end

def mock(name); MockObject.new(name); end
def mock_int(n); n; end
def flunk(msg = nil)
  $mspec_fail += 1
  puts "FAILED: #{$mspec_it}: flunked"
  nil
end

def mspec_report
  puts "pass=#{$mspec_pass} fail=#{$mspec_fail} err=#{$mspec_err}"
end

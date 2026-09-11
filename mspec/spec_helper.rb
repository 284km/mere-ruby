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
  # real mspec forwards any other message to the value and asserts a truthy
  # answer: `"ab".should.include?("a")`, `x.should.between?(1, 2)`. A value
  # that does not answer the message raises NoMethodError, which is the
  # example's own bug to surface.
  def method_missing(sym, *args, &blk)
    if @actual.__send__(sym, *args, &blk)
      $mspec_pass += 1
    else
      $mspec_fail += 1
      puts "FAILED: #{$mspec_it}: expected truthy from ##{sym}"
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
  # see PositiveMatcher#method_missing; here a truthy answer is the failure.
  def method_missing(sym, *args, &blk)
    if @actual.__send__(sym, *args, &blk)
      $mspec_fail += 1
      puts "FAILED: #{$mspec_it}: expected falsy from ##{sym}"
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
    __mspec_verify_stubs
  rescue SpecFailure
    # already tallied
  rescue Exception => e
    $mspec_err += 1
    # The CLASS only: the message would make this record compare two error
    # texts rather than two behaviours, and they differ for reasons the record
    # already names elsewhere. MERE_SPEC_VERBOSE prints it for debugging, and
    # is off in every gate -- an ERROR line is the start of an investigation
    # and "which NoMethodError" is the first thing it needs.
    puts "ERROR: #{$mspec_desc} #{desc}: #{e.class}" +
         (ENV["MERE_SPEC_VERBOSE"] ? " -- #{e.message}" : "")
  end
  # ...and on the failure paths too: a stub left installed would change the
  # NEXT example (one put on a class outlives the object it was put on).
  __mspec_drop_stubs
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
# mspec's `quarantine! do ... end` marks examples as not-to-be-run; the block is
# skipped entirely. It was missing, so the block ran at DESCRIBE time and the
# file died on `undefined method 'quarantine!'` -- under ruby too, which is why
# the pair only showed as a path difference in the two error reports.
def quarantine!(*args); end
# mspec numeric boundary helpers (mspec/helpers/numeric.rb).
# mspec/helpers/numeric.rb: the exceptional Float values a spec names rather
# than writes. Without them core/float/round_spec's three FloatDomainError
# examples raised NameError -- the harness missing, not the interpreter.
def nan_value; 0 / 0.0; end
def infinity_value; 1 / 0.0; end
def bignum_value(plus = 0); 2**64 + plus; end
def fixnum_max; 2**62 - 1; end
def fixnum_min; -(2**62); end
# mspec's version guard, decided by the RUBY_VERSION each side reports. It was a
# no-op -- the block never ran, on either side -- which kept the two runs
# comparable and made the record BLIND: 67 of the files in the swept groups
# carry one, and the blocks behind "3.5" and "4.0" are exactly the behaviour
# this interpreter now claims. A reference move could not show up in the record
# at all while this returned without yielding. Both sides still run the same
# shim and the same RUBY_VERSION, so it remains one question asked twice.
def __mspec_ver_cmp(a, b)
  y = b.to_s.split(".")
  # mspec compares RUBY_VERSION truncated to the BOUND's precision, so that
  # `ruby_version_is "4.0".."4.0"` means "any 4.0.x" rather than "4.0.0 exactly".
  x = a.to_s.split(".")[0, y.size]
  n = x.size > y.size ? x.size : y.size
  i = 0
  while i < n
    xa = (x[i] || "0").to_i
    yb = (y[i] || "0").to_i
    return -1 if xa < yb
    return 1 if xa > yb
    i += 1
  end
  0
end

def ruby_version_is(range)
  ok =
    if range.is_a?(Range)
      b = range.begin.to_s
      e = range.end.to_s
      (b.empty? || __mspec_ver_cmp(RUBY_VERSION, b) >= 0) &&
        (e.empty? || (range.exclude_end? ? __mspec_ver_cmp(RUBY_VERSION, e) < 0 : __mspec_ver_cmp(RUBY_VERSION, e) <= 0))
    else
      __mspec_ver_cmp(RUBY_VERSION, range.to_s) >= 0
    end
  yield if ok && block_given?
end
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
  def initialize(sym); @sym = sym; @value = nil; @with = nil; @raise = nil; @raise_msg = nil; end
  def and_return(v); @value = v; self; end
  def and_raise(e = RuntimeError, msg = nil); @raise = e; @raise_msg = msg; self; end
  # raise what `.and_raise` named, if anything. Called at the moment the mocked
  # method is invoked.
  def raise!
    return if @raise.nil?
    @raise_msg.nil? ? (raise @raise) : (raise @raise, @raise_msg)
  end
  # `.with(args)` narrows the expectation to those arguments. Ignoring it made
  # every registration for a symbol answer from the FIRST one: a mock with
  # `should_receive(:<=>).with(@y).and_return(-1)` and
  # `.with(@x).and_return(0)` compared equal to nothing, and six of
  # core/range/minmax_spec's nine examples errored -- under ruby too, since
  # the shim is the same file on both sides.
  def with(*a); @with = a; self; end
  def matches?(args); @with.nil? || @with == args; end
  def twice; self; end
  def once; self; end
  def at_least(*a); @optional = true; self; end
  def at_most(*a); @optional = true; self; end
  # ⚠ "any number of times" INCLUDES zero, so this expectation must not be
  #  verified. core/numeric/coerce_spec sets one in `before :each` that its
  #  first example never uses.
  def any_number_of_times; @optional = true; self; end
  def optional?; @optional ? true : false; end
  def exactly(*a); self; end
  def times; self; end
  def value; @value; end
  def sym; @sym; end
  # whether the mocked method was actually invoked -- what `should_receive`
  # verifies at the end of the example, and what `should_not_receive` forbids.
  def called!; @called = true; end
  def called?; @called ? true : false; end
end

# `should_receive` / `should_not_receive` on an ORDINARY object, which is how a
# spec says "this protocol must (not) be used": `[].should_not_receive(:to_ary)`
# and `obj.should_receive(:to_str).and_return("x")`. Only MockObject had them,
# so every such example raised NoMethodError -- and the reference ruby runs the
# same shim, so both sides raised and the pair read as MATCH. The stub is
# installed as a real singleton method and REMOVED when the example ends, or a
# stub on a class (`Array.should_receive(:new)`) would outlive it.
# ⚠ a symbol may carry SEVERAL expectations, narrowed by `.with`:
#   `a.should_receive(:<=>).with(x).and_return(0)` followed by
#   `.with(y).and_return(-1)` is two registrations, and the stub has to pick
#   the FIRST whose arguments match. Redefining the singleton method per
#   registration kept only the LAST one -- the same "one name, several
#   answers" mistake MockExpectation#with already exists to avoid, made again
#   one level out. Each entry is [obj, sym, [[expectation, forbidden?], ...]]
#   and the installed method closes over that list, so a later registration
#   for the same pair is seen by the method already defined.
$mspec_stubs = []
module Kernel
  def should_receive(sym)
    __mspec_install_stub(sym, MockExpectation.new(sym), false)
  end
  def should_not_receive(sym)
    __mspec_install_stub(sym, MockExpectation.new(sym), true)
  end
  # mspec's `stub!` is a should_receive that does not have to be received: it
  # only says what the method ANSWERS. Without it `obj.stub!(:to_ary)` was nil
  # and the `.and_return` on the end raised NoMethodError.
  def stub!(sym)
    e = MockExpectation.new(sym)
    e.any_number_of_times
    __mspec_install_stub(sym, e, false)
  end
  def stub(sym); stub!(sym); end
  def __mspec_install_stub(sym, e, forbidden)
    found = nil
    $mspec_stubs.each { |x| found = x if found.nil? && x[0].equal?(self) && x[1] == sym }
    if found
      found[2] << [e, forbidden]
      return e
    end
    exps = [[e, forbidden]]
    begin
      singleton_class.send(:define_method, sym) do |*args, &blk|
        hit = nil
        exps.each { |pair| hit = pair if hit.nil? && pair[0].matches?(args) }
        if hit.nil?
          $mspec_fail += 1
          puts "FAILED: #{$mspec_it}: ##{sym} received with unexpected arguments"
          nil
        else
          hit[0].called!
          if hit[1]
            $mspec_fail += 1
            puts "FAILED: #{$mspec_it}: expected not to receive ##{sym}"
            nil
          else
            hit[0].raise!
            hit[0].value
          end
        end
      end
      $mspec_stubs << [self, sym, exps]
    rescue Exception
      # a frozen object or an immediate has nowhere to put one; the example
      # will surface that on its own terms.
    end
    e
  end
end

# ...verified and undone when the example ends: an expectation that was never
# received is a failure, and the stub must not outlive the example (one put on
# a CLASS would change every example after it).
def __mspec_verify_stubs
  $mspec_stubs.each do |obj, sym, exps|
    exps.each do |e, forbidden|
      if !forbidden && !e.called? && !e.optional?
        $mspec_fail += 1
        puts "FAILED: #{$mspec_it}: expected to receive ##{sym}"
      end
    end
  end
  __mspec_drop_stubs
end

def __mspec_drop_stubs
  $mspec_stubs.each do |obj, sym, _exps|
    begin
      obj.singleton_class.send(:remove_method, sym)
    rescue Exception
    end
  end
  $mspec_stubs = []
end

class MockObject
  def initialize(name)
    @name = name
    @syms = []
    @exps = []
    @sings = []
  end
  def should_receive(sym)
    e = MockExpectation.new(sym)
    @syms << sym
    @exps << e
    # ⚠ ...and a REAL singleton method too: a name Object already answers
    # (==, <, >, <=>, coerce, to_s) never reaches #method_missing, so a
    # registration for it was invisible. core/numeric/remainder_spec mocks
    # `@result.==(0)` and got Object#== instead.
    #
    # ⚠ ...but NOT for the four this class answers carefully itself. Its
    # #respond_to? consults the registration list AND the object's real
    # methods without re-entering itself; a raw stub for that name answers nil
    # whenever the arity does not match the `.with` (ruby calls it with TWO
    # arguments), and core/array/equal_value_spec then recursed forever on its
    # self-referencing arrays. The instrument has to keep the part of itself
    # that was already right.
    __mspec_install_stub(sym, e, false) unless
      sym == :respond_to? || sym == :to_s || sym == :inspect || sym == :method_missing
    e
  end
  def should_not_receive(sym)
    MockExpectation.new(sym)
  end
  # see Kernel#stub!: a registration that answers but is never required.
  def stub!(sym)
    e = MockExpectation.new(sym)
    e.any_number_of_times
    @syms << sym
    @exps << e
    __mspec_install_stub(sym, e, false) unless
      sym == :respond_to? || sym == :to_s || sym == :inspect || sym == :method_missing
    e
  end
  def stub(sym); stub!(sym); end
  # the first registration for this symbol whose `.with` (if any) matches the
  # arguments; a registration without `.with` matches any call.
  def __mock_find(sym, args)
    i = 0
    while i < @syms.length
      return [true, @exps[i]] if @syms[i] == sym && @exps[i].matches?(args)
      i += 1
    end
    [false, nil]
  end
  def method_missing(sym, *args)
    # a spec may mock #method_missing ITSELF, naming the message it expects to
    # be forwarded (string/slice_spec drives the #to_int protocol that way).
    # Looking only for the missing NAME never found that registration.
    ok, e = __mock_find(:method_missing, [sym] + args)
    return (e.raise!; e.value) if ok
    ok, e = __mock_find(sym, args)
    return nil unless ok
    # `.and_raise` was a no-op that answered nil, so a spec that says "this
    # object's #coerce raises" got an object whose #coerce returned nil -- and
    # the interpreter was then measured against the wrong question.
    e.raise!
    e.value
  end
  # A mock answers what it was TOLD to answer, plus whatever it really has (a
  # `def obj.to_int` a spec adds by hand is a real singleton method, and `super`
  # finds it). Claiming EVERY name made the interpreter look wrong wherever a
  # spec's own object is supposed to decline: `5 > mock('x')` raises
  # ArgumentError in ruby because the mock has no #coerce, and this one said it
  # had one -- so the four ordering operators refused with the wrong error for a
  # reason that was in the harness.
  def respond_to?(sym, include_all = false)
    # a spec may MOCK #respond_to? itself (string/slice_spec does, to drive the
    # #to_int protocol through #method_missing); the registration wins, as it
    # already does for #to_s and #inspect.
    ok, e = __mock_find(:respond_to?, [sym, include_all])
    return e.value if ok
    return true if @syms.include?(sym)
    # what this object REALLY has, asked without `super`: a super from a
    # redefined #respond_to? lands back in the builtin probe, which consults
    # this very method again -- `MockObject.new('x').respond_to?(:each_entry)`
    # came back true out of that loop while `:each` came back false.
    # ...and NOT through #methods, #singleton_methods or
    # #singleton_class.instance_methods: all three ask this method again on the
    # way, so the probe recursed until the stack ran out. A singleton a spec
    # adds by hand (`def obj.to_int`) is recorded by the hook below instead.
    return true if @sings.include?(sym)
    self.class.instance_methods.include?(sym)
  end
  # `def obj.to_int` on a mock is a method it really has, and the probe above
  # cannot ask for the list without re-entering itself. Ruby announces each one
  # here as it is installed, so the mock keeps its own list.
  def singleton_method_added(name)
    @sings = [] if @sings.nil?
    @sings << name
  end
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
  def __mock_syms; @syms; end
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

# ---- mspec's own helpers, ported from its source --------------------------
# Nineteen recorded rows stop at one of these, and they are mspec's files, not
# ruby's: `fixture`, `tmp`, `IOStub`, `complain`, `output`, the fs helpers.
# They are transcribed from spec/mspec/lib/mspec rather than reconstructed from
# the call sites, because a helper invented from how it is CALLED answers a
# different question from the one the spec is asking -- and the spec is the
# thing being trusted here.

# helpers/io.rb
class IOStub
  def initialize; @buffer = []; @output = +""; end
  def write(*str); self << str.join(''); end
  def <<(str); @buffer << str; self; end
  def print(*str); write(str.join('') + $\.to_s); end
  def printf(format, *args); self << sprintf(format, *args); end
  def puts(*str)
    if str.empty?
      write "\n"
    else
      write(str.collect { |s| s.to_s.chomp }.concat([nil]).join("\n"))
    end
  end
  def flush; @output += @buffer.join(''); @buffer.clear; self; end
  def to_s; flush; @output; end
  def to_str; to_s; end
  def ==(other); to_s == other; end
  def =~(other); to_s =~ other; end
  def method_missing(name, *args, &block); to_s.send(name, *args, &block); end
  def respond_to_missing?(name, include_private = false); to_s.respond_to?(name, include_private); end
end

# helpers/fixture.rb
def fixture(file, *args)
  path = File.dirname(file)
  path = path[0..-7] if path[-7..-1] == "/shared"
  fixtures = path[-9..-1] == "/fixtures" ? "" : "fixtures"
  path = (File.realpath(path) rescue File.expand_path(path))
  File.join(path, fixtures, *args)
end

# helpers/tmp.rb. ⚠ mspec also refuses a world-writable SPEC_TEMP_DIR, asking
# File.umask -- which mere-ruby does not have. The check is dropped rather than
# faked: it guards against a SHARED temp directory, and this one is created
# under the working directory per process. Said here so the omission is a
# decision and not a gap someone later mistakes for a port that is complete.
SPEC_TEMP_DIR = "#{Dir.pwd}/rubyspec_temp/#{Process.pid}" unless defined?(SPEC_TEMP_DIR)
SPEC_TEMP_UNIQUIFIER = +"0" unless defined?(SPEC_TEMP_UNIQUIFIER)

def tmp(name, uniquify = true)
  mkdir_p SPEC_TEMP_DIR unless File.directory?(SPEC_TEMP_DIR)
  if uniquify and !name.empty?
    slash = name.rindex "/"
    index = slash ? slash + 1 : 0
    name = +name
    name.insert index, "#{SPEC_TEMP_UNIQUIFIER.succ!}-"
  end
  File.join SPEC_TEMP_DIR, name
end

# helpers/fs.rb
def mkdir_p(path)
  parts = File.expand_path(path).split("/")
  name = parts.shift
  parts.each do |part|
    name = File.join name, part
    raise ArgumentError, "path component of #{path} is a file" if File.file? name
    Dir.mkdir(name) unless File.directory? name
  end
end

def rm_r(*paths)
  paths.each do |path|
    path = File.expand_path path
    prefix = SPEC_TEMP_DIR
    unless path[0, prefix.size] == prefix
      raise ArgumentError, "#{path} is not prefixed by #{prefix}"
    end
    if File.symlink? path
      File.delete path
    elsif File.directory? path
      Dir.entries(path).each { |x| rm_r "#{path}/#{x}" unless x =~ /\A\.\.?\z/ }
      Dir.rmdir path
    elsif File.exist? path
      File.delete path
    end
  end
end

def touch(name, mode = "w")
  mkdir_p File.dirname(name)
  File.open(name, mode) { |f| yield f if block_given? }
end

def cp(source, dest)
  File.write(dest, File.read(source))
end

# helpers/warning.rb
def suppress_keyword_warning(&block); suppress_warning(&block); end

# matchers/complain.rb
class ComplainMatcher
  def initialize(complaint = nil, options = nil)
    if complaint.is_a?(Hash)
      @complaint = nil
      @options = complaint
    else
      @complaint = complaint
      @options = options || {}
    end
  end
  def match?(proc)
    saved_err = $stderr
    verbose = $VERBOSE
    err = IOStub.new
    $stderr = err
    $VERBOSE = @options.key?(:verbose) ? @options[:verbose] : false
    begin
      proc.call
    ensure
      $VERBOSE = verbose
      $stderr = saved_err
    end
    @warning = err.to_s
    unless @complaint.nil?
      case @complaint
      when Regexp then return false unless @warning =~ @complaint
      else return false unless @warning == @complaint
      end
    end
    !@warning.empty?
  end
end
def complain(complaint = nil, options = nil); ComplainMatcher.new(complaint, options); end

# matchers/output.rb
class OutputMatcher
  def initialize(stdout, stderr); @out = stdout; @err = stderr; end
  def match?(proc)
    saved_out = $stdout
    saved_err = $stderr
    o = IOStub.new
    e = IOStub.new
    $stdout = o
    $stderr = e
    begin
      proc.call
    ensure
      $stdout = saved_out
      $stderr = saved_err
    end
    unless @out.nil?
      case @out
      when Regexp then return false unless o.to_s =~ @out
      else return false unless o.to_s == @out
      end
    end
    unless @err.nil?
      case @err
      when Regexp then return false unless e.to_s =~ @err
      else return false unless e.to_s == @err
      end
    end
    true
  end
end
def output(stdout = nil, stderr = nil); OutputMatcher.new(stdout, stderr); end

def mspec_report
  puts "pass=#{$mspec_pass} fail=#{$mspec_fail} err=#{$mspec_err}"
end

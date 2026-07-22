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

class Object
  def should(matcher = nil)
    if matcher.nil?
      PositiveMatcher.new(self)
    else
      if matcher.match?(self)
        $mspec_pass += 1
      else
        $mspec_fail += 1
        puts "FAILED: #{$mspec_it}: matcher did not match #{self.inspect}"
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
        puts "FAILED: #{$mspec_it}: matcher matched #{self.inspect}"
      else
        $mspec_pass += 1
      end
      nil
    end
  end
end

def describe(desc, *opts)
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

def it(desc, *opts)
  $mspec_it = desc
  begin
    $mspec_before.call if $mspec_before
    yield
    $mspec_after.call if $mspec_after
  rescue SpecFailure
    # already tallied
  rescue Exception => e
    $mspec_err += 1
    puts "ERROR: #{$mspec_desc} #{desc}: #{e.class}"
  end
end

def it_behaves_like(*args); end
def before(kind = nil, &blk); $mspec_before = blk; end
def after(kind = nil, &blk); $mspec_after = blk; end
def guard(*args); end
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

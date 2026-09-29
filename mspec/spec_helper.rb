# A minimal mspec-compatible spec_helper: just enough of the mspec DSL
# (describe / it / should / matchers) to run real spec/ruby files, written
# in plain Ruby so the same shim runs under both mere-ruby and ruby (the
# outputs can be diffed byte-for-byte).

# mspec/utils/warnings.rb, which every mspec run loads: deprecation warnings
# on (ruby/spec tests for them), experimental ones off
if Object.const_defined?(:Warning) && Warning.respond_to?(:[]=)
  Warning[:deprecated] = true
  Warning[:experimental] = false
end

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
  # x.should.raise(Klass[, message][, cause: c]) { |e| ... } -- mspec's
  # RaiseErrorMatcher (matchers/base.rb, matchers/raise_error.rb): the class,
  # the message (a String is compared, a Regexp matched) and the cause must
  # all agree, and then the block gets the exception, with expectations of its
  # own. An exception that does NOT agree propagates, as mspec re-raises it.
  # (The shim compared the class alone and threw the block away: 1068 message
  # checks and 111 blocks of assertions ran on neither side, and `cause:` was
  # an ArgumentError on both.)
  def raise(exception = Exception, message = nil, options = nil, &block)
    m = RaiseErrorMatcher.new(exception, message, options, &block)
    if m.match?(@actual)
      $mspec_pass += 1
    else
      $mspec_fail += 1
      puts "FAILED: #{$mspec_it}: #{m.failure_line}"
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
  # ⚠ `x.should !~ /re/` needs its OWN method. Object#!~ is defined as the
  # negation of #=~, so without this it ran the matcher above -- which counts
  # a pass when the pattern MATCHES -- and every `should !~` was recorded
  # backwards, on both sides. core/exception/full_message has eleven of them.
  def !~(pattern)
    if @actual =~ pattern
      $mspec_fail += 1
      puts "FAILED: #{$mspec_it}: expected #{@actual.inspect} not to match"
    else
      $mspec_pass += 1
    end
    nil
  end
end

class NegativeMatcher
  def initialize(actual)
    @actual = actual
  end
  # x.should_not.raise(Klass[, message]): passes when nothing is raised, fails
  # when a matching exception is, and lets any other one propagate (mspec). It
  # had no #raise, so method_missing sent #raise to the Proc -- Kernel#raise --
  # and all 155 of them were an ERROR on both sides.
  def raise(exception = Exception, message = nil, options = nil, &block)
    m = RaiseErrorMatcher.new(exception, message, options, &block)
    if m.match?(@actual)
      $mspec_fail += 1
      puts "FAILED: #{$mspec_it}: expected not to raise #{m.expected_text}"
    else
      $mspec_pass += 1
    end
    nil
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

# ---- the example tree, as mspec builds and runs it (runner/context.rb) ----
#
# mspec reads a describe body FIRST and runs its examples AFTERWARDS, and the
# order it runs things in is part of what a spec means:
#   * before(:all) runs once per describe, and it is every ENCLOSING
#     describe's before(:all) as well as the describe's own; before(:each)
#     runs per example, after all of those. So a `before :each` that sets
#     @object wins over a shared group's `before :all` that sets it to nil.
#   * after blocks run innermost first, and later-defined first.
#   * a describe's own examples run before its nested describes.
#   * it_behaves_like adds the shared group's hooks and examples to the
#     describe it is IN (not to a group of its own), after a before(:all)
#     that sets @method / @object.
#   * everything runs on ONE env object (MSpec.protect is
#     `@env.instance_exec(&block)`), so `@value_to_return = ...` written in a
#     describe body reaches that describe's examples, and an ivar one example
#     sets is still there in the next -- examples do not start clean.
# The shim used to run each example the moment `it` was read, on a fresh
# Object, with befores in one flat list: 1781 it_behaves_like lines were then
# no-ops, and once they ran, a spec's `before :each { @object = ... }` was
# overwritten by the shared group's nil, and every describe-level ivar was
# lost -- on BOTH sides, so those rows compared the shim with itself.
class MSpecContext
  attr_reader :desc, :parent, :examples, :children
  attr_accessor :parsed
  def initialize(desc, parent)
    @desc = desc
    @parent = parent
    @parsed = false
    @examples = []
    @children = []
    @before_all = []
    @before_each = []
    @after_each = []
    @after_all = []
    parent.children << self if parent
  end
  def before_list(kind); kind == :all ? @before_all : @before_each; end
  def after_list(kind); kind == :all ? @after_all : @after_each; end
  def add_before(kind, blk); before_list(kind) << blk; end
  def add_after(kind, blk); after_list(kind).unshift(blk); end
  def parents
    l = []
    s = self
    while s
      l.unshift(s)
      s = s.parent
    end
    l
  end
  # outermost first, each describe's in the order they were written
  def pre(kind)
    l = []
    parents.each { |s| l.concat(s.before_list(kind)) }
    l
  end
  # innermost first (and within one describe, the later ones first)
  def post(kind)
    l = []
    parents.reverse.each { |s| l.concat(s.after_list(kind)) }
    l
  end
  # a copy of a shared group's nested describe, placed under +parent+
  def adopt_copy(parent)
    c = MSpecContext.new(@desc, parent)
    c.parsed = @parsed
    [:all, :each].each do |k|
      before_list(k).each { |b| c.add_before(k, b) }
      after_list(k).reverse.each { |b| c.add_after(k, b) }
    end
    @examples.each { |e| c.examples << e }
    @children.each { |ch| ch.adopt_copy(c) }
    c
  end
end

$mspec_env = Object.new
$mspec_cur = nil
# shared example groups, by name: `describe :name, shared: true do` parses
# one here and runs none of it; it_behaves_like copies it in.
$mspec_shared = {}

# One step of the run -- a hook or an example -- with its failure tallied.
# Answers whether it completed. (MSpec.protect; the shim keeps its own tally
# and its one-line reports, and a SystemExit is swallowed as it always was.)
def __mspec_protect(label, blk)
  $mspec_env.instance_exec(&blk)
  true
rescue SpecFailure
  # already tallied
  false
rescue SpecSkipped
  # ⚠ `skip` is mspec's own, and the shim did not have it -- so an example
  #   that MEANT to skip raised NameError and was recorded as an ERROR, which
  #   is a different verdict from the reference's. core/gc/config is the one
  #   that found it: its example skips when the collector has no boolean
  #   setting to toggle, which this one does not.
  #   A skipped example is counted as PASSED here, as real mspec counts it,
  #   so the two sides' tallies mean the same thing.
  $mspec_pass += 1
  false
rescue Exception => e
  $mspec_err += 1
  # The CLASS only: the message would make this record compare two error
  # texts rather than two behaviours, and they differ for reasons the record
  # already names elsewhere. MERE_SPEC_VERBOSE prints it for debugging, and
  # is off in every gate -- an ERROR line is the start of an investigation
  # and "which NoMethodError" is the first thing it needs.
  puts "ERROR: #{label}: #{e.class}" +
       (ENV["MERE_SPEC_VERBOSE"] ? " -- #{e.message}" : "")
  false
end

def __mspec_run_example(ctx, desc, blk)
  $mspec_it = desc
  $mspec_desc = ctx.desc
  label = "#{ctx.desc} #{desc}"
  ok = true
  ctx.pre(:each).each { |b| ok = __mspec_protect(label, b) if ok }
  if ok && blk
    ok = __mspec_protect(label, blk)
  end
  ctx.post(:each).each { |a| __mspec_protect(label, a) }
  __mspec_protect(label, proc { __mspec_verify_stubs }) if ok
  # ...and on the failure paths too: a stub left installed would change the
  # NEXT example (one put on a class outlives the object it was put on).
  __mspec_drop_stubs
end

def __mspec_process(ctx)
  if ctx.parsed && !ctx.examples.empty?
    $mspec_desc = ctx.desc
    ok = true
    ctx.pre(:all).each { |b| ok = __mspec_protect("#{ctx.desc} before :all", b) if ok }
    if ok
      ctx.examples.each { |d, b| __mspec_run_example(ctx, d, b) }
      ctx.post(:all).each { |a| __mspec_protect("#{ctx.desc} after :all", a) }
    end
  end
  ctx.children.each { |c| __mspec_process(c) }
end

def describe(desc, *opts, &blk)
  shared = opts.any? { |o| o.is_a?(Hash) && o[:shared] }
  prev = $mspec_cur
  ctx = MSpecContext.new(desc.to_s, shared ? nil : prev)
  $mspec_cur = ctx
  ctx.parsed = __mspec_protect(desc.to_s, blk) if blk
  $mspec_cur = prev
  if shared
    $mspec_shared[desc.to_s] = ctx
  elsif prev.nil?
    __mspec_process(ctx)
  end
  nil
end

def context(desc, *opts, &blk); describe(desc, *opts, &blk); end

# mspec's `skip`: abandon this example without failing it. Real mspec raises
# its own exception class and the runner counts the example as passed.
class SpecSkipped < StandardError; end
def skip(reason = nil); raise SpecSkipped, reason.to_s; end

def it(desc, *opts, &blk)
  if $mspec_cur
    $mspec_cur.examples << [desc, blk]
  else
    # an example outside any describe runs where it stands
    top = MSpecContext.new("", nil)
    top.parsed = true
    top.examples << [desc, blk]
    __mspec_process(top)
  end
  nil
end

# mspec: `specify` is an alias of `it` (a describe-less example).
def specify(desc = nil, *opts, &blk); it(desc, *opts, &blk); end
# mspec's evaluate DSL prefixes example descriptions via SpecEvaluate.desc=;
# the shim ignores the prefix (descriptions still print per example).
module SpecEvaluate
  def self.desc=(x); @desc = x; end
  def self.desc; @desc; end
end
# mspec's it_behaves_like (runner/shared.rb), word for word: @method and
# @object are set in a before(:all) of the describe it is written in.
def it_behaves_like(desc, meth = nil, obj = nil)
  before(:all) do
    @method = meth
    @object = obj
  end
  after(:all) do
    @method = nil
    @object = nil
  end
  it_should_behave_like desc.to_s
end
# ContextState#it_should_behave_like: the shared group's hooks, examples and
# nested describes join the current describe. A name that was never
# registered is mspec's error too.
def it_should_behave_like(desc)
  state = $mspec_shared[desc.to_s]
  raise Exception, "Unable to find shared 'describe' for #{desc}" unless state
  cur = $mspec_cur
  [:all, :each].each do |k|
    state.before_list(k).each { |b| cur.add_before(k, b) }
    state.after_list(k).each { |b| cur.add_after(k, b) }
  end
  state.examples.each { |e| cur.examples << e }
  state.children.each { |ch| ch.adopt_copy(cur) }
  nil
end
def before(kind = :each, &blk); $mspec_cur.add_before(kind, blk) if $mspec_cur; end
def after(kind = :each, &blk); $mspec_cur.add_after(kind, blk) if $mspec_cur; end
# mspec's guard: the block runs when the condition answers true
def guard(cond = nil)
  ok = cond.respond_to?(:call) ? cond.call : cond
  yield if ok && block_given?
  ok
end
# mspec platform guards: this shim runs everywhere, so the block runs.
def not_supported_on(*args); yield if block_given?; end
# mspec's known-MRI-bug guard: the block is skipped on the versions that have
# the bug (up to and including the one named) and runs after it
def ruby_bug(bug = nil, version = nil)
  yield if block_given? && version && __mspec_ver_cmp(RUBY_VERSION, version.to_s) > 0
end
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
  # without a block it ANSWERS (mspec's run_if): `ruby_version_is("4.0") ?
  # "Object" : "object"` picks a message by version, and nil picked the old one
  # on both sides
  return ok unless block_given?
  yield if ok
end
# mspec's platform guards, decided by RUBY_PLATFORM (the same on both sides
# here). With no block they answer the question, which some specs use inline.
def __mspec_platform?(*args)
  args.any? do |a|
    case a
    when Hash
      a.all? do |k, v|
        case k
        when :c_long_size, :pointer_size, :wordsize then v == 64
        else false
        end
      end
    when :windows, :mingw, :mswin, :cygwin, :android, :aix, :solaris, :openbsd, :netbsd, :freebsd, :dragonfly, :wsl
      RUBY_PLATFORM.include?(a.to_s)
    when :linux then RUBY_PLATFORM.include?("linux")
    when :darwin then RUBY_PLATFORM.include?("darwin")
    when :bsd then RUBY_PLATFORM =~ /bsd|dragonfly/ ? true : false
    else RUBY_PLATFORM.include?(a.to_s)
    end
  end
end
def platform_is(*args)
  ok = __mspec_platform?(*args)
  yield if ok && block_given?
  ok
end
def platform_is_not(*args)
  ok = !__mspec_platform?(*args)
  yield if ok && block_given?
  ok
end
# ---- the rest of mspec's guards and helpers, ported from mspec/lib ----
# ruby/spec's own spec_helper.rb defines this (the code-loading fixtures), and
# 45 of core/kernel/load_spec's examples name it
CODE_LOADING_DIR = File.realpath("fixtures/code", __dir__) unless defined?(CODE_LOADING_DIR)
# Each was missing, and a spec that used one raised NoMethodError under BOTH
# interpreters -- the pair read as agreement about nothing. Found by listing
# every `def` in mspec's helpers/guards/matchers against this file (2026-09-29):
# new_io 104 uses, output_to_fd 68, with_timezone 66, with_feature 47,
# mock_to_path 42, little_endian/big_endian 41, as_user 22, ...
#
# guards/platform.rb's queries that specs call directly
module PlatformGuard
  C_LONG_SIZE = 64
  POINTER_SIZE = 64
  def self.implementation?(*args)
    args.any? { |name| (name == :ruby ? "ruby" : name.to_s) == RUBY_ENGINE }
  end
  def self.standard?; implementation?(:ruby); end
  def self.windows?; false; end
  def self.wasi?; false; end
end
# guards/guard.rb's guard_not
def guard_not(condition)
  yield unless condition.call
end
# guards/endian.rb: decided by the bytes [1].pack('L') lays out
def __mspec_big_endian?; [1].pack('L')[-1] == ?\001; end
def big_endian
  ok = __mspec_big_endian?
  yield if ok && block_given?
  ok
end
def little_endian
  ok = !__mspec_big_endian?
  yield if ok && block_given?
  ok
end
# guards/superuser.rb
def as_superuser
  ok = Process.euid == 0
  yield if ok && block_given?
  ok
end
def as_real_superuser
  ok = Process.uid == 0
  yield if ok && block_given?
  ok
end
def as_user
  ok = Process.euid != 0
  yield if ok && block_given?
  ok
end
# guards/feature.rb and the MSpec registry it asks. ruby/spec's own
# spec_helpers enable the features (library/socket, library/readline).
module MSpec
  @features = {}
  def self.enable_feature(f); @features[f] = true; end
  def self.disable_feature(f); @features.delete(f); end
  def self.feature_enabled?(f); @features.key?(f); end
end
def with_feature(*features)
  ok = features.all? { |f| MSpec.feature_enabled?(f) }
  yield if ok && block_given?
  ok
end
def without_feature(*features)
  ok = !features.all? { |f| MSpec.feature_enabled?(f) }
  yield if ok && block_given?
  ok
end
# guards/version.rb's version_is (ruby_version_is with another base) and
# kernel_version_is (darwin's is the build-time one in RUBY_PLATFORM)
def __mspec_version_ok?(base, req)
  if req.is_a?(Range)
    b = req.begin.to_s
    e = req.end.to_s
    (b.empty? || __mspec_ver_cmp(base, b) >= 0) &&
      (e.empty? || (req.exclude_end? ? __mspec_ver_cmp(base, e) < 0 : __mspec_ver_cmp(base, e) <= 0))
  else
    __mspec_ver_cmp(base, req.to_s) >= 0
  end
end
def version_is(base, req)
  ok = __mspec_version_ok?(base.to_s, req)
  yield if ok && block_given?
  ok
end
def kernel_version_is(req)
  v = RUBY_PLATFORM[/darwin(\d+)/, 1] || `uname -r`.chomp
  ok = __mspec_version_ok?(v, req)
  yield if ok && block_given?
  ok
end
# guards/block_device.rb
def with_block_device
  found = `find /dev /devices -type b 2> /dev/null`
  ok = !(found.nil? || found.empty?)
  yield if ok && block_given?
  ok
end
# helpers/numeric.rb (C long is 64 bits on every host this runs on)
def max_long; 2**63 - 1; end
def min_long; -(2**63); end
# helpers/io.rb
def new_fd(name, mode = "w:utf-8")
  if mode.kind_of? Hash
    if mode.key? :mode
      mode = mode[:mode]
    else
      raise ArgumentError, "new_fd options Hash must include :mode"
    end
  end
  IO.sysopen name, mode
end
def new_io(name, mode = "w:utf-8")
  if Hash === mode
    File.new(name, **mode)
  else
    File.new(name, mode)
  end
end
# helpers/mock_to_path.rb
def mock_to_path(path)
  obj = MockObject.new('path')
  obj.should_receive(:to_path).and_return(path)
  obj
end
# helpers/datetime.rb
def new_datetime(opts = {})
  require 'date'
  value = {
    :year   => -4712,
    :month  => 1,
    :day    => 1,
    :hour   => 0,
    :minute => 0,
    :second => 0,
    :offset => 0,
    :sg     => Date::ITALY
  }.merge opts
  DateTime.new value[:year], value[:month], value[:day], value[:hour],
    value[:minute], value[:second], value[:offset], value[:sg]
end
def with_timezone(name, offset = nil, daylight_saving_zone = "")
  zone = name.dup
  if offset
    # TZ convention is backwards
    offset = -offset
    zone += offset.to_s
    zone += ":00:00"
  end
  zone += daylight_saving_zone
  old = ENV["TZ"]
  ENV["TZ"] = zone
  begin
    yield
  ensure
    ENV["TZ"] = old
  end
end
# helpers/argv.rb
def argv(args)
  if args == :restore
    ARGV.replace(@__mspec_saved_argv__ || [])
  else
    @__mspec_saved_argv__ = ARGV.dup
    ARGV.replace args
    if block_given?
      begin
        yield
      ensure
        argv :restore
      end
    end
  end
end
# matchers/signed_zero.rb
class SignedZeroMatcher
  def initialize(sign); @sign = sign; end
  def match?(actual); (1.0 / actual).infinite? == @sign; end
end
def be_positive_zero; SignedZeroMatcher.new(1); end
def be_negative_zero; SignedZeroMatcher.new(-1); end
# matchers/equal_element.rb
class EqualElementMatcher
  def initialize(element, attributes = nil, content = nil, options = {})
    @element = element
    @attributes = attributes
    @content = content
    @options = options
  end
  def match?(actual)
    matched = true
    if @options[:not_closed]
      matched &&= actual =~ /^#{Regexp.quote("<" + @element)}.*#{Regexp.quote(">" + (@content || ''))}$/
    else
      matched &&= actual =~ /^#{Regexp.quote("<" + @element)}/
      matched &&= actual =~ /#{Regexp.quote("</" + @element + ">")}$/
      matched &&= actual =~ /#{Regexp.quote(">" + @content + "</")}/ if @content
    end
    if @attributes
      if @attributes.empty?
        matched &&= actual.scan(/\w+\=\"(.*)\"/).size == 0
      else
        @attributes.each do |key, value|
          if value == true
            matched &&= (actual.scan(/#{Regexp.quote(key)}(\s|>)/).size == 1)
          else
            matched &&= (actual.scan(%Q{ #{key}="#{value}"}).size == 1)
          end
        end
      end
    end
    !!matched
  end
end
def equal_element(*args); EqualElementMatcher.new(*args); end
# matchers/output_to_fd.rb: the block's writes to that stream, by reopening it
# on a temporary file
class OutputToFDMatcher
  def initialize(expected, to)
    @to, @expected = to, expected
    unless @to.equal?(STDOUT) || @to.equal?(STDERR) || @to.is_a?(IO)
      raise ArgumentError, "#{@to.inspect} is not a supported output target"
    end
  end
  def match?(block)
    old_to = @to.dup
    path = tmp("mspec_output_to_#{$$}_#{Time.now.to_i}")
    begin
      File.open(path, 'w+') do |out|
        @to.reopen out
        begin
          block.call
        ensure
          @to.reopen old_to
          old_to.close
        end
        out.rewind
        @actual = out.read
      end
    ensure
      File.delete path if File.exist?(path)
    end
    case @expected
    when Regexp then !(@actual =~ @expected).nil?
    else @actual == @expected
    end
  end
end
def output_to_fd(what, where = STDOUT); OutputToFDMatcher.new(what, where); end
# mspec's own (helpers/warning.rb): the block runs with $VERBOSE = nil. A bare
# yield let every warning through, and since run_spec.sh runs the reference
# under -W0 and mere-ruby without it, only one side printed them -- the
# "already initialized constant STDOUT" in core/io/shared/new.rb was that.
def suppress_warning
  verbose = $VERBOSE
  $VERBOSE = nil
  yield
ensure
  $VERBOSE = verbose
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

def __ruby_exe(code, file = nil)
  old = $stdout
  cap = MSpecStdoutCapture.new
  $stdout = cap
  begin
    file ? eval(code.to_s, TOPLEVEL_BINDING, file, 1) : eval(code.to_s)
  rescue Exception
  ensure
    $stdout = old
  end
  cap.string
end

# a shell word for each arg (an Array), or shell text as given (a String)
def __mspec_shell_args(a)
  case a
  when nil then nil
  when Array then a.map { |x| "'" + x.to_s.gsub("'", "'\\\\''") + "'" }.join(" ")
  else a.to_s
  end
end
def ruby_exe(code = :__not_given, *rest, **opts)
  # with no code, mspec answers the command line itself, as words
  return RUBY_EXE.split(" ") if code == :__not_given
  # nil code: the interpreter runs what its options and args give it (a
  # script on stdin, `args: "< file"`), not an empty -e
  if code.nil?
    cmd = [RUBY_EXE, opts[:options], __mspec_shell_args(opts[:args])].compact.join(" ")
    return `#{cmd}`
  end
  # mspec runs a FILE in a subprocess of the interpreter under test
  # (`ruby_exe(fixture(...))`). Evaluating the path as code failed identically
  # on both sides, and evaluating the file in-process cannot give it what a
  # main script has: its own DATA, TOPLEVEL_BINDING, $0 and ARGF.
  if code.is_a?(String) && !code.include?("\n") && File.file?(code)
    cmd = [RUBY_EXE, opts[:options], code, __mspec_shell_args(opts[:args])].compact.join(" ")
    return `#{cmd}`
  end
  # ...and so does a snippet that asks for interpreter OPTIONS or shell text
  # (`args: "< file"`, "2>&1"): neither means anything in-process
  # ...and so does every snippet: a subprocess is what mspec runs, and an
  # in-process eval shares the runner's state -- its warning settings, its
  # globals, its at_exit/END list, its $stdout
  if ENV["MSPEC_RUBY_EXE"]
    cmd = [RUBY_EXE, opts[:options], "-e", __mspec_shell_args([code.to_s]), __mspec_shell_args(opts[:args])].compact.join(" ")
    return `#{cmd}`
  end
  # ...and an ARRAY of args is the snippet's ARGV for an in-process run (a
  # String of args is shell text such as "2>&1", which has no in-process
  # meaning)
  saved_argv = nil
  if opts[:args].is_a?(Array)
    saved_argv = ARGV.dup
    ARGV.replace(opts[:args].map(&:to_s))
  end
  begin
    __ruby_exe(code.to_s)
  ensure
    ARGV.replace(saved_argv) if saved_argv
  end
end

# mspec's RUBY_EXE / ruby_cmd: the command line that runs the interpreter under
# test. run_spec.sh names it per side, because neither interpreter can answer
# "my own path". A spec that shells out (`\`#{ruby_cmd(...)}\``, system(...))
# needs this; without it every such example died with NoMethodError on both
# sides and the file read DIFF on the difference between two failures.
RUBY_EXE = ENV["MSPEC_RUBY_EXE"] || "ruby" unless defined?(RUBY_EXE)
# ...and what MSpecScript#setup_env puts in the environment for the programs a
# spec starts (utils/script.rb): the runner's flag, the interpreter, its flags.
# core/process/fixtures/kill.rb reads ENV["RUBY_FLAGS"].split, and without it
# the four process-group examples were a NoMethodError on both sides.
ENV["MSPEC_RUNNER"] = "1"
ENV["RUBY_EXE"] ||= RUBY_EXE
ENV["RUBY_FLAGS"] ||= ""
def ruby_cmd(code, opts = {})
  body = code
  body = "-e #{code.inspect}" if code and !File.exist?(code)
  [RUBY_EXE, opts[:options], body, opts[:args]].compact.join(" ")
end

# mspec's `evaluate <<-ruby do ... end`: run the code (which defines methods
# or sets ivars) and then the block, on the same fresh object so state set by
# the code is visible to the block's assertions.
def evaluate(code, &block)
  o = Object.new
  o.instance_eval(code)
  o.instance_eval(&block)
end

# mspec's `-> { ... }.should block_caller`: run the proc on its own thread and
# watch its status. A thread parked on a lock reports "sleep"; one that ran to
# the end reports false. ⚠ this is the shim's matcher protocol (#match?), not
# mspec's (#matches?) -- the name and the behaviour are mspec's, the interface
# is this file's, and the two mutex files that use it were failing on BOTH
# sides for want of it.
class BlockingMatcher
  def match?(block)
    t = Thread.new { block.call }
    300.times do
      case t.status
      when "sleep"
        t.kill
        (t.join rescue nil)
        return true
      when false, nil
        (t.join rescue nil)
        return false
      end
      Thread.pass
    end
    (t.kill rescue nil)
    true
  end
end
def block_caller
  BlockingMatcher.new
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
# mspec defines this beside TOLERANCE (matchers/be_close.rb): the bound a
# timed wait is allowed to overshoot by. Without it every `timeout:` example
# in shared/queue dies in its thread with NameError while the main thread
# spins in `Thread.pass until t.status == "sleep"` -- the REFERENCE then hits
# the CPU budget and the row reads SLOW on both sides.
TIME_TOLERANCE = 20.0 unless defined?(TIME_TOLERANCE)
class CloseMatcher
  def initialize(expected, tolerance); @expected = expected; @tolerance = tolerance; end
  def match?(actual); (actual - @expected).abs <= @tolerance; end
end
def be_close(expected, tolerance = TOLERANCE); CloseMatcher.new(expected, tolerance); end
# mspec's be_computed_by (mspec/matchers/be_computed_by.rb): each row is
# [receiver, *arguments, expected], and the method is sent with the row's
# arguments plus the matcher's. Without it every example written as a table
# died on the matcher's name on BOTH sides -- 23 files ask for it.
class BeComputedByMatcher
  def initialize(sym, *args); @method = sym; @args = args; end
  def match?(array)
    array.each do |line|
      receiver = line.shift
      value = line.pop
      actual = receiver.send(@method, *(line + @args))
      return false unless actual == value
    end
    true
  end
end
def be_computed_by(sym, *args); BeComputedByMatcher.new(sym, *args); end
# mspec's match_yaml (mspec/matchers/match_yaml.rb): the expectation is YAML
# text when it parses as YAML and is dumped otherwise, and the two sides are
# compared after the trailing-space and document-end cleanup mspec does.
class MatchYAMLMatcher
  def initialize(expected)
    @expected = valid_yaml?(expected) ? expected : expected.to_yaml
  end
  def match?(actual)
    actual.is_a?(String) && clean_yaml(actual) == clean_yaml(@expected)
  end
  def clean_yaml(yaml)
    yaml.gsub(/([^-]|^---)\s+\n/, "\\1\n").sub(/\n\.\.\.\n$/, "\n")
  end
  def valid_yaml?(obj)
    require 'yaml'
    begin
      YAML.respond_to?(:unsafe_load) ? YAML.unsafe_load(obj) : YAML.load(obj)
    rescue StandardError
      false
    else
      true
    end
  end
end
def match_yaml(expected); MatchYAMLMatcher.new(expected); end
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
# mspec's RaiseErrorMatcher, as matchers/raise_error.rb writes it. #match?
# answers false when nothing was raised, true when the exception agrees (after
# giving it to the block), and RE-RAISES one that does not agree -- the class
# of what really happened is the finding, not "a matcher failed".
class RaiseErrorMatcher
  UNDEF_CAUSE = Object.new
  def initialize(exception = Exception, message = nil, options = nil, &block)
    if message.is_a?(Hash)
      @message = nil
      options = message
    else
      @message = message
    end
    @cause = options ? options.fetch(:cause, UNDEF_CAUSE) : UNDEF_CAUSE
    @exception = exception.nil? ? Exception : exception
    @block = block
  end
  def match?(proc)
    proc.call
    false
  rescue Object => actual
    raise actual unless matching_exception?(actual)
    @block.call(actual) if @block
    true
  end
  def matching_exception?(exc)
    return false unless @exception === exc
    ok = case @message
         when String then @message == exc.message
         when Regexp then (@message =~ exc.message) ? true : false
         else true
         end
    return false unless ok
    @cause.equal?(UNDEF_CAUSE) || @cause == exc.cause
  end
  def expected_text
    t = @exception.to_s
    t += " #{@message.inspect}" unless @message.nil?
    t
  end
  def failure_line; "expected #{expected_text} to be raised"; end
end

def raise_error(exception = Exception, message = nil, options = nil, &block)
  RaiseErrorMatcher.new(exception, message, options, &block)
end
# CRuby < 4.1 has inconsistent coercion errors (bugs.ruby-lang.org #21864), so
# mspec ignores the message there -- and the reference here is 4.0.
def raise_consistent_error(exception = Exception, message = nil, options = nil, &block)
  message = nil if RUBY_ENGINE == "ruby" && __mspec_version_ok?(RUBY_VERSION, ""..."4.1")
  RaiseErrorMatcher.new(exception, message, options, &block)
end

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
  # several values are answered one per call, the last one from then on
  # (mspec's MockProxy#returning): `and_return(-1, -1)` was an ArgumentError
  def and_return(*vs)
    if vs.size > 1
      @values = vs
    else
      @values = nil
      @value = vs[0]
    end
    self
  end
  def and_raise(e = RuntimeError, msg = nil); @raise = e; @raise_msg = msg; self; end
  # mspec's and_yield: each call adds one yield, made (in order) to the block
  # the mocked method is called with, before it answers
  def and_yield(*a); (@yields ||= []) << a; self; end
  def yields; @yields || []; end
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
  def value
    return @value if @values.nil?
    return @values[0] if @values.size == 1
    @values.shift
  end
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
        # ⚠ the report goes to STDOUT itself: a spec may stub #write on the
        #   object that IS $stdout (core/kernel/putc), and `puts` from here
        #   called that stub again, which reported again, until the stack ran
        #   out
        if hit.nil?
          $mspec_fail += 1
          STDOUT.puts "FAILED: #{$mspec_it}: ##{sym} received with unexpected arguments"
          nil
        else
          hit[0].called!
          if hit[1]
            $mspec_fail += 1
            STDOUT.puts "FAILED: #{$mspec_it}: expected not to receive ##{sym}"
            nil
          else
            hit[0].raise!
            hit[0].yields.each { |ya| blk.call(*ya) } if blk
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
# mspec's mock_numeric: a Numeric that answers only what a spec stubs on it
# (Kernel#should_receive above). 20 spec files ask for one, and without it
# every such example died on the helper's name on BOTH sides.
class NumericMockObject < Numeric
  def initialize(name, options = {})
    @name = name
    @null = options[:null_object]
  end
  def method_missing(sym, *args, &block)
    @null ? self : super
  end
  def singleton_method_added(val); end
end
def mock_numeric(name, options = {}); NumericMockObject.new(name, options); end
# mspec's argf helper (mspec/helpers/argf.rb): @argf is a FRESH ARGF over the
# given files, because ARGF itself is global. Without it every example written
# around it died on the helper's name on both sides.
def argf(argv)
  if argv.empty? or argv.length > 2
    raise "Only 1 or 2 filenames are allowed for the argf helper so files can be properly closed: #{argv.inspect}"
  end
  @argf ||= nil
  raise "Cannot nest calls to the argf helper" if @argf
  @argf = ARGF.class.new(*argv)
  @__mspec_saved_argf_file__ = @argf.file
  begin
    yield
  ensure
    file1 = @__mspec_saved_argf_file__
    file2 = @argf.file
    file1.close if !file1.closed? and file1 != STDIN
    file2.close if !file2.closed? and file2 != STDIN
    @argf = nil
    @__mspec_saved_argf_file__ = nil
  end
end
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

# ⚠ CLEAR THIS PROCESS'S TEMP DIRECTORY BEFORE ANY SPEC USES IT. The path is
# keyed by pid, pids recycle, and nothing removed the directory afterwards --
# so 436 of them accumulated under the repo, and a run that inherited one
# holding a FILE where it wanted a directory died with "path component ... is
# a file". core/kernel/printf then read DIFF against an interpreter that had
# done nothing wrong. A directory named by THIS pid is stale by definition.
rm_r SPEC_TEMP_DIR if File.exist?(SPEC_TEMP_DIR)

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

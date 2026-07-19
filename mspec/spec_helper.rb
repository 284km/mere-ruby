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
      if klass.nil? || e.class.to_s == klass.to_s
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
  def !=(expected)
    if @actual != expected
      $mspec_pass += 1
    else
      $mspec_fail += 1
      puts "FAILED: expected not #{expected.inspect}"
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
end

class Object
  def should
    PositiveMatcher.new(self)
  end
  def should_not
    NegativeMatcher.new(self)
  end
end

def describe(desc)
  $mspec_desc = desc
  yield
end

def context(desc)
  $mspec_desc = desc
  yield
end

def it(desc)
  $mspec_it = desc
  begin
    yield
  rescue SpecFailure
    # already tallied
  rescue Exception => e
    $mspec_err += 1
    puts "ERROR: #{$mspec_desc} #{desc}: #{e.class}"
  end
end

def it_behaves_like(*args); end
def before(*args); end
def after(*args); end
def guard(*args); end
def ruby_version_is(*args); end
def platform_is(*args); end
def platform_is_not(*args); end
def suppress_warning
  yield
end

def mspec_report
  puts "pass=#{$mspec_pass} fail=#{$mspec_fail} err=#{$mspec_err}"
end

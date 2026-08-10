# A minitest-lite stand-in for rubygems' own test/rubygems/helper.rb.
#
# The real helper is 1705 lines and pulls in all of RubyGems (zlib, psych,
# openssl ...), none of which mere-ruby can load. But the tests for the pure
# classes — Gem::Version, Gem::Requirement, Gem::Dependency — only need a base
# class with minitest's assertions, so this file provides exactly that.
#
# run.sh runs each test file under BOTH ruby and mere-ruby with this same shim
# installed as `helper.rb` and diffs the output, so the tally is a comparison
# against CRuby rather than a claim by the shim.

module Gem
  class TestCase
    CASES = []

    class AssertionFailed < StandardError
    end

    def self.inherited(sub)
      CASES << sub
      super
    end

    # test classes override these and call super, so they must exist.
    def setup
    end

    # The real helper points BUNDLE_GEMFILE at its sandbox tempdir so a Gemfile
    # further up the tree cannot influence the run. There is no sandbox here
    # and nothing reads the variable, so pointing it at a path that does not
    # exist has the same effect.
    def without_any_upwards_gemfiles
      ENV["BUNDLE_GEMFILE"] = "/nonexistent/Gemfile"
    end

    def teardown
    end

    def flunk(msg)
      raise AssertionFailed, msg
    end

    def assert(cond, msg = nil)
      flunk(msg || "expected a truthy value, got #{cond.inspect}") unless cond
      true
    end

    def refute(cond, msg = nil)
      flunk(msg || "expected a falsy value, got #{cond.inspect}") if cond
      true
    end

    def assert_equal(exp, act, msg = nil)
      flunk(msg || "expected #{exp.inspect}, got #{act.inspect}") unless exp == act
      true
    end

    def refute_equal(exp, act, msg = nil)
      flunk(msg || "expected something other than #{exp.inspect}") if exp == act
      true
    end

    def assert_nil(act, msg = nil)
      assert_equal(nil, act, msg)
    end

    def refute_nil(act, msg = nil)
      flunk(msg || "expected not nil") if act.nil?
      true
    end

    def assert_same(exp, act, msg = nil)
      flunk(msg || "expected the same object") unless exp.equal?(act)
      true
    end

    def refute_same(exp, act, msg = nil)
      flunk(msg || "expected a different object") if exp.equal?(act)
      true
    end

    def assert_match(pat, str, msg = nil)
      pat = Regexp.new(Regexp.escape(pat)) if pat.is_a?(String)
      flunk(msg || "expected #{str.inspect} to match #{pat.inspect}") unless pat =~ str
      true
    end

    def refute_match(pat, str, msg = nil)
      pat = Regexp.new(Regexp.escape(pat)) if pat.is_a?(String)
      flunk(msg || "expected #{str.inspect} not to match #{pat.inspect}") if pat =~ str
      true
    end

    def assert_operator(a, op, b, msg = nil)
      flunk(msg || "expected #{a.inspect} #{op} #{b.inspect}") unless a.send(op, b)
      true
    end

    def assert_includes(coll, obj, msg = nil)
      flunk(msg || "expected #{coll.inspect} to include #{obj.inspect}") unless coll.include?(obj)
      true
    end

    # The three small constructors the real helper exposes to these tests
    # (helper.rb:1497/1524/1565), reproduced verbatim.
    def v(string)
      Gem::Version.create string
    end

    def req(*requirements)
      return requirements.first if Gem::Requirement === requirements.first
      Gem::Requirement.create requirements
    end

    def dep(name, *requirements)
      Gem::Dependency.new name, *requirements
    end

    # minitest spells it assert_raises; rubygems' helper aliases assert_raise.
    def assert_raises(*classes)
      classes = [StandardError] if classes.empty?
      begin
        yield
      rescue => e
        return e if classes.any? { |k| e.is_a?(k) }
        flunk("expected #{classes.inspect}, got #{e.class}: #{e.message}")
      end
      flunk("expected #{classes.inspect}, nothing raised")
    end

    def assert_raise(*classes, &blk)
      assert_raises(*classes, &blk)
    end

    # A deterministic, sorted report so the two interpreters' outputs can be
    # compared byte for byte.
    def self.run_all
      npass = 0
      nfail = 0
      nerr = 0
      lines = []
      CASES.each do |klass|
        names = klass.instance_methods(false).map {|m| m.to_s }.select {|m| m.start_with?("test_") }.sort
        names.each do |name|
          t = klass.new
          begin
            t.setup if t.respond_to?(:setup)
            t.send(name)
            npass += 1
          rescue AssertionFailed => e
            nfail += 1
            lines << "FAIL #{klass}##{name}: #{e.message}"
          rescue StandardError => e
            nerr += 1
            lines << "ERR  #{klass}##{name}: #{e.class}"
          end
        end
      end
      lines.sort.each {|l| puts l }
      puts "pass=#{npass} fail=#{nfail} err=#{nerr}"
    end
  end
end

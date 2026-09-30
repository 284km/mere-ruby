# RbConfig::CONFIG answers the keys that are facts about the ruby this
# interpreter reports being: the version parts agree with RUBY_VERSION and
# RUBY_PATCHLEVEL, and the cpu / os parts with RUBY_PLATFORM.
require "rbconfig"
c = RbConfig::CONFIG
major, minor, teeny = RUBY_VERSION.split(".")
p c.values_at("MAJOR", "MINOR", "TEENY", "PATCHLEVEL") == [major, minor, teeny, RUBY_PATCHLEVEL.to_s]
p c["RUBY_PROGRAM_VERSION"] == RUBY_VERSION, c["RUBY_API_VERSION"] == [major, minor].join(".")
p RUBY_PLATFORM.include?(c["host_cpu"]), RUBY_PLATFORM.end_with?(c["host_os"])
p c["prefix"] == RbConfig::TOPDIR
p c.all? { |k, v| k.is_a?(String) && v.is_a?(String) }

# (and three reflection answers from the same pass)
# a Proc can hold instance variables, as any object can
pr = proc {}
pr.instance_variable_set(:@a, 1)
p pr.instance_variable_get(:@a), pr.instance_variables
# Kernel.equal? is a question about the Kernel module, not about main
p Kernel.equal?(Kernel), Kernel.__send__(:equal?, Kernel)
# IO includes Enumerable and then File::Constants, and the interpreter's own
# mixins are not listed
p IO.ancestors.take(3), Dir.ancestors.take(2)
p IO.ancestors.none? { |m| m.name.to_s.end_with?("__Impl") }

# RbConfig is a module, and a program may reopen it (CRuby's test framework does)
p RbConfig.class
module RbConfig
  def self.reopened = :yes
end
p RbConfig.reopened

# rbconfig/sizeof: the platform's C type sizes and limits
require "rbconfig/sizeof"
p RbConfig::SIZEOF["int"], RbConfig::SIZEOF["long"], RbConfig::SIZEOF["void*"]
p RbConfig::LIMITS["FIXNUM_MAX"] == 2**62 - 1, RbConfig::LIMITS["INT_MAX"]

# a multibyte character literal is one character
p ?に, [?に, ?a], ?é.bytes

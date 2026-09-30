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

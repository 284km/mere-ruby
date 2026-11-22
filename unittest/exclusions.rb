# frozen_string_literal: true

# CRuby still applies EXCLUDES through its own ExcludedMethods. Record only
# methods that runner actually removes, rather than counting ledger entries.
if ENV['UNITTEST_EXCLUSIONS']
  module MereRubyExclusionAudit
    def exclude_from(klass)
      before = klass.public_instance_methods(true).grep(/^test_/)
      super
      removed = before - klass.public_instance_methods(true)
      File.open(ENV.fetch('UNITTEST_EXCLUSIONS'), 'a') do |io|
        removed.sort.each do |method|
          reason = excludes[method] || excludes.find { |key, _| Regexp === key && key.match?(method.to_s) }&.last
          io.puts [klass.name, method, reason].join("\t")
        end
      end
    end
  end
  Test::Unit::ExcludesOption::ExcludedMethods.prepend(MereRubyExclusionAudit)
end

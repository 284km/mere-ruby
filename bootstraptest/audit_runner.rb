# Run by the native reference Ruby, with the upstream runner left in charge of
# every assertion kind. Persist discovery and completion before a later crash
# can hide which assertions existed or incorrectly turn them into passes.
require 'json'
require 'digest'

module BootstrapAudit
  LOG = File.open(ENV.fetch('BOOTSTRAP_CASE_LOG'), 'w')
  LOG.sync = true
  SKIP_DIR = ENV.fetch('BOOTSTRAP_SKIP_DIR')

  def self.record(event)
    line = JSON.generate(event)
    raise 'bootstrap case log byte bound exceeded' if LOG.pos + line.bytesize + 1 > 16 * 1024 * 1024
    LOG.puts(line)
  end

  module Registration
    def add(assertion)
      super
      raise 'bootstrap assertion count bound exceeded' if assertion.id > 100000
      kind = caller_locations.map(&:base_label).find { |name| name.start_with?('assert_') || name == 'show_limit' }
      BootstrapAudit.record(event: 'discover', id: assertion.id, file: assertion.path,
                            line: assertion.lineno, kind: kind,
                            source_sha256: Digest::SHA256.hexdigest(assertion.src))
    end
  end

  module Calls
    def call
      @audit_skip_file = File.join(BootstrapAudit::SKIP_DIR, "#{id}.skip")
      BootstrapAudit.record(event: 'start', id: id)
      before = BT_STATE.error
      result = super
      native_status = BT_STATE.error == before ? 'PASS' : 'FAIL'
      skipped = File.file?(@audit_skip_file)
      BootstrapAudit.record(event: 'finish', id: id,
                            status: native_status == 'PASS' && skipped ? 'SKIP' : native_status,
                            skipped: skipped)
      result
    rescue Exception => error
      BootstrapAudit.record(event: 'finish', id: id, status: 'ERROR', error: error.class.name)
      raise
    end

    def make_srcfile(**options)
      filename = super
      source = File.binread(filename)
      original = 'rescue BT_Skip; $!.message; end)'
      raise 'unsupported upstream bootstrap skip wrapper' unless source.scan(original).size == 1
      # Preserve the original result and line count, recording an explicit
      # child skip instead of accepting its expected text as a passing test.
      replacement = "rescue BT_Skip; ::File.write(#{@audit_skip_file.dump}, 'skip'); $!.message; end)"
      File.binwrite(filename, source.sub(original, replacement))
      filename
    end
  end

  HOOK = TracePoint.new(:end) do |trace|
    if defined?(::Assertion) && trace.self.equal?(::Assertion)
      ::Assertion.singleton_class.prepend(Registration)
      ::Assertion.prepend(Calls)
      HOOK.disable
    end
  end
  HOOK.enable

  at_exit do
    error = $!
    BootstrapAudit.record(event: 'final',
                          normal_exit: error.nil? || error.is_a?(SystemExit),
                          exit: error.is_a?(SystemExit) ? error.status : error ? 1 : 0,
                          discovered: defined?(::Assertion) ? ::Assertion.count : 0)
    LOG.close
  end
end

runner = ARGV.shift or abort 'missing upstream bootstrap runner'
# Source files can generate assertions in loops. Both native hosts use the
# same discovery seed; target programs retain the upstream runner's behavior.
srand(1)
load runner

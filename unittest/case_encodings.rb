# frozen_string_literal: true

# Symbol.inspect loses some encoding distinctions. Observe non-ASCII names
# through the pinned Test::Unit callbacks, without changing the test methods.
if ENV["UNITTEST_CASE_ENCODINGS"]
  module MereRubyCaseEncodings
    def self.setup(path)
      @path, @owner, @stopped = path, Process.pid, false
      File.open(path, "wb") { |file| file.write("case-encodings-v1\n") }
    end

    def self.capture(suite, method, kind)
      return if @stopped || Process.pid != @owner
      klass, name = suite.to_s, method.to_s
      return if klass.ascii_only? && name.ascii_only?
      if klass.bytesize + name.bytesize > 16 * 1024
        @stopped = true
        File.open(@path, "ab") { |file| file.write("!limit\n") }
        return
      end
      line = [kind, klass.unpack1("H*"), klass.encoding.name,
              name.unpack1("H*"), name.encoding.name].join("\t") + "\n"
      File.open(@path, "ab") do |file|
        if file.size + line.bytesize > 16 * 1024 * 1024
          @stopped = true
          file.write("!limit\n")
        else
          file.write(line)
        end
      end
    rescue StandardError
      @stopped = true
      begin
        File.open(@path, "ab") { |file| file.write("!error\n") }
      rescue StandardError
        # Missing metadata is also detected by the transcript parser.
      end
    end

    def _start_method(instance)
      super
      MereRubyCaseEncodings.capture(instance.class, instance.__name__, "N")
    end

    def record(suite, method, assertions, elapsed, error, source_location = nil)
      super
      return unless error
      kind = case error
             when Test::Unit::PendedError then "S"
             when Test::Unit::AssertionFailedError then "F"
             when Timeout::Error then "T"
             else "E"
             end
      MereRubyCaseEncodings.capture(suite, method, kind)
    end
  end

  MereRubyCaseEncodings.setup(ENV.fetch("UNITTEST_CASE_ENCODINGS"))
  Test::Unit::Runner.prepend(MereRubyCaseEncodings)
end

# A final class body creates temporary conversion errors, then exit hooks
# perform repeated collections. Count retained errors and time the actual GC.
count = Integer(ARGV.fetch(0, '20000'))
rounds = Integer(ARGV.fetch(1, '20'))
at_exit do
  GC.enable
  GC.start
  warn "retained_errors=#{ObjectSpace.each_object(Encoding::UndefinedConversionError).count}"
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  rounds.times { GC.start }
  warn "collections=#{rounds} seconds=#{Process.clock_gettime(Process::CLOCK_MONOTONIC) - start}"
  p ExitGCWorkload.new.kept
end
GC.disable
Object.const_set(:EXIT_GC_INPUT, count)
class ExitGCWorkload
  def self.build
    codepoints = Array.new(EXIT_GC_INPUT) { |i| (0x1000 + i % 0x1000).chr('UTF-8') }.select do |code|
      begin
        code.encode('US-ASCII')
        true
      rescue Encoding::UndefinedConversionError
        false
      end
    end
    define_method(:kept) { codepoints }
  end
  build
end

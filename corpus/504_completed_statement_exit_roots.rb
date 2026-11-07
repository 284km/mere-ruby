# Exit hooks must keep captured values, but not every temporary allocated by
# the program's final statement. A conservative collector may retain a few
# incidental handles; retaining most of this completed workload is a leak.
at_exit do
  GC.enable
  GC.start
  p ObjectSpace.each_object(Encoding::UndefinedConversionError).count < 1000
  p ExitRootFixture.new.kept
end
GC.disable

class ExitRootFixture
  def self.build
    kept = ['kept', {answer: [42]}]
    selected = (0..4000).map { |i| (i + 0x1000).chr('UTF-8') }.select do |code|
      begin
        code.encode('US-ASCII')
        true
      rescue Encoding::UndefinedConversionError
        false
      end
    end
    define_method(:kept) { [kept, selected] }
  end
  build
end

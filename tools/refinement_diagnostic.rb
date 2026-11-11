      code = proc do
        $c = Class.new do
          def foo; end
        end

        $m = Module.new do
          refine $c do
            def foo; end
          end
        end

        Class.new do
          using $m

          def initialize
            o = $c.new
            o.method(:foo).unbind
          end
        end.new
      end
      1_000.times(&code)
start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      300_000.times(&code)
puts Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

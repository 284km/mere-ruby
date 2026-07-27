      begin
        m = Thread::Mutex.new
        parent = Thread.current
        th1 = Thread.new { m.lock; sleep }
        sleep 0.01 until th1.stop?
        Thread.new do
          sleep 0.01 until parent.stop?
          begin
            fork { GC.start }
          rescue Exception
            parent.raise $!
          end
          th1.run
        end
        m.lock
        pid, status = Process.wait2
        $result = status.success? ? :ok : :ng
      rescue NotImplementedError
        $result = :ok
      end

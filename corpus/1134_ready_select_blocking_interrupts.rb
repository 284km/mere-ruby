def pending_select1134(label, mode, operation)
  ready, resume = Queue.new, Queue.new
  events = []
  worker = Thread.new do
    begin
      Thread.handle_interrupt(StandardError => :never) do
        ready << true
        resume.pop
        Thread.handle_interrupt(StandardError => mode) do
          begin
            operation.call
            events << [:returned, Thread.current.status]
          rescue StandardError => error
            events << [:caught, error.class.name, error.message, Thread.current.status]
          end
        end
      end
    rescue StandardError => error
      events << [:late, error.class.name, error.message, Thread.current.status]
    end
  end
  ready.pop
  worker.raise(StandardError.new("queued select"))
  resume << true
  raise "worker timed out" unless worker.join(5)
  p [label, events]
end

reader, writer = IO.pipe
begin
  pending_select1134(:ready_zero, :on_blocking, -> { IO.select(nil, [writer], nil, 0) })
  pending_select1134(:ready_unlimited, :on_blocking, -> { IO.select(nil, [writer]) })
  pending_select1134(:empty_zero, :on_blocking, -> { IO.select([], [], [], 0) })
  pending_select1134(:nil_zero, :on_blocking, -> { IO.select(nil, nil, nil, 0) })
  pending_select1134(:never, :never, -> { IO.select(nil, [writer], nil, 0) })
  pending_select1134(:invalid_arity, :on_blocking, -> { IO.select })
  p [:normal_ready, IO.select(nil, [writer], nil, 0) == [[], [writer], []], Thread.current.status]
ensure
  reader.close
  writer.close
end

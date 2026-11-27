source = <<~'RUBY'
def show(label)
  p [label, yield]
rescue Exception => error
  p [label, error.class.name, error.message]
end
show(:initial) { [$stdin.lineno, $.] }
show(:set_float) { $stdin.__send__(:lineno=, 10.5) }
show(:after_set) { [$stdin.lineno, $.] }
show(:first_stdin) { [$stdin.gets, $stdin.lineno, $.] }
show(:kernel) { [gets, $stdin.lineno, $.] }
$. = 200
show(:after_global) { [$stdin.lineno, $.] }
show(:last_stdin) { [$stdin.gets, $stdin.lineno, $.] }
show(:bad) { $stdin.lineno = 'str' }
show(:bounds) { $stdin.lineno = 2**32 }
show(:stdout) { STDOUT.lineno = 'str' }
$stdin.close
show(:closed) { $stdin.lineno = 'str' }
RUBY
def run_input(source)
  error_path = "stdin-lines-#{Process.pid}.err"
  begin
    out = IO.popen(['sh', '-c', 'printf "A\nB\nC\n" | exec "$@"',
                    'stdin-lines', RbConfig.ruby, '-e', source, err: error_path], &:read)
    status = $?.exitstatus
    print out
    p [File.binread(error_path), status]
  ensure
    File.unlink(error_path) if File.exist?(error_path)
  end
end
run_input(source)
run_input(<<~'RUBY')
  STDIN.each_line do |line|
    p [:yield, line, STDIN.lineno, $.]
    break
  end
  p [:remaining, STDIN.readlines, STDIN.lineno, $.]
  p [:eof, STDIN.gets, STDIN.lineno, $.]
RUBY
run_input(<<~'RUBY')
  p [:separator, STDIN.gets("B"), STDIN.lineno, $.]
  p [:readline, STDIN.readline, STDIN.lineno, $.]
  p [:rest, STDIN.read, STDIN.lineno, $.]
  begin
    STDIN.readline
  rescue EOFError => error
    p [:end, error.class.name, STDIN.lineno, $.]
  end
  class LineNumber
    def to_int = 7
  end
  value = LineNumber.new
  p [:coercion, STDIN.__send__(:lineno=, value).equal?(value), STDIN.lineno, $.]
RUBY

# Stage the input after both readers actually suspend, then wait for the
# first completed read before supplying the second line. No sleep race.
def run_staged_readers(method, affinity)
  source = <<~'RUBY'
    method, affinity = ARGV.shift, ARGV.shift == 'argf'
    STDOUT.sync = true
    ARGF.file if affinity
    workers = 2.times.map do
      Thread.new do
        line = STDIN.__send__(method)
        p [:read, line, STDIN.lineno, $., affinity ? ARGF.lineno : nil]
      end
    end
    Thread.pass until workers.all? { |worker| worker.status == 'sleep' }
    p [:ready, method, affinity]
    workers.each { |worker| raise 'reader timed out' unless worker.join(15) }
    p [:final, STDIN.lineno, $., affinity ? ARGF.lineno : nil]
  RUBY
  error_path = "stdin-staged-#{method}-#{affinity}-#{Process.pid}.err"
  begin
    command = [RbConfig.ruby, '-e', source, method, affinity ? 'argf' : 'direct']
    IO.popen(command, 'r+', err: error_path) do |pipe|
      pipe.sync = true
      read_event = -> do
        raise 'staged reader output timed out' unless IO.select([pipe], nil, nil, 20)
        line = pipe.gets
        raise 'staged reader exited early' unless line
        print line
      end
      read_event.call
      pipe.write("A\n")
      pipe.flush
      read_event.call
      pipe.write("B\n")
      pipe.flush
      read_event.call
      read_event.call
    end
    p [File.binread(error_path), $?.exitstatus]
  ensure
    File.unlink(error_path) if File.exist?(error_path)
  end
end
%w[gets readline].each do |method|
  run_staged_readers(method, false)
  run_staged_readers(method, true)
end

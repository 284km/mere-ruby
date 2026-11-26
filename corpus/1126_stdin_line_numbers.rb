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

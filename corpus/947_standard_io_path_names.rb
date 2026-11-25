# Standard streams have names; another IO wrapping the descriptor does not.
[STDIN, STDOUT, STDERR].each do |stream|
  p [stream.path, stream.to_path, stream.path.encoding.name]
  io = IO.new(stream.fileno, autoclose: false)
  p [:descriptor, io.path, io.to_path, io.equal?(stream), stream.path]
end
named = IO.new(STDOUT.fileno, path: "named", autoclose: false)
p [:named, named.path, named.to_path]
require "logger"
[STDOUT, STDERR].each do |stream|
  logger = Logger.new(stream)
  dev = logger.instance_variable_get(:@logdev)
  p [:logger, dev.filename, dev.dev.equal?(stream)]
end

GC.start
p [:after_gc, STDIN.path, STDOUT.path, STDERR.path]

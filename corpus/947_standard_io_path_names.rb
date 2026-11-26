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

# Each accessor returns a fresh mutable label, preserving its binary encoding.
[STDIN, STDOUT, STDERR].each do |stream|
  [:path, :to_path].each do |accessor|
    label = stream.public_send(accessor)
    p [:fresh, stream.fileno, accessor, label.frozen?,
       label.equal?(stream.public_send(accessor))]
    label.replace("changed")
    p [:after_replace, stream.path, stream.to_path,
       stream.path.encoding.name, stream.to_path.encoding.name]
    label = stream.public_send(accessor)
    label.force_encoding("UTF-8")
    p [:after_encoding, stream.path, stream.to_path,
       stream.path.encoding.name, stream.to_path.encoding.name]
  end
end

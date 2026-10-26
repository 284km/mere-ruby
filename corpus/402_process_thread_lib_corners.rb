# What ruby/spec's Process, Thread, IO::Buffer, YAML and Time files ask of the
# corners: fork that this build has not, thread-variable keys, a frozen
# thread's message, the native thread id, a string a buffer holds, a closed
# standard stream in a child, exec's descriptor that stays open, a tagged
# YAML document, and a zone given twice
require "rbconfig"
require "yaml"

def try402
  yield
rescue NotImplementedError, StandardError => e
  [e.class, e.message.sub(/0x\h+/, "XX").sub(/ \S+:\d+ /, " ")]
end


th = Thread.new {}
th.join
th.freeze
p try402 { th[:a] = 1 }
key = Object.new
p try402 { Thread.current.thread_variable_get(key) }.first, try402 { Thread.current.thread_variable_set(key, 1) }.first
p Thread.current.native_thread_id.is_a?(Integer), th.native_thread_id

s = +"fur string"
IO::Buffer.for(s) do |b|
  p try402 { s[0] = "t" }
  b.set_string("b")
end
s[1] = "u"
p s

p Process.setrlimit(:NOFILE, *Process.getrlimit(:NOFILE))

out = IO.popen([RbConfig.ruby, "-e", <<~'RUBY'], &:read)
  pid = Process.spawn(RbConfig.ruby, "-e", "begin; STDOUT.puts 'out'; STDERR.puts 'err'; rescue => e; puts 'rescued'; end", err: :close)
  Process.wait(pid)
RUBY
p out

out = IO.popen([RbConfig.ruby, "-e", <<~'RUBY'], &:read)
  f = File.open(RbConfig.ruby)
  puts f.close_on_exec?
  Process.exec("/", f.fileno => f.fileno) rescue nil
  puts f.close_on_exec?
RUBY
p out

module YS402; class Example; def initialize(n) = @name = n; end; end
Person402 = Struct.new(:name, :gender)
[YS402::Example.new("baz"), Person402.new("Jane", "female"), StandardError.new("foobar")].each do |o|
  y = o.to_yaml
  back = YAML.unsafe_load(y)
  p back.class, (back.respond_to?(:message) ? back.message : back.instance_variables)
end
p YAML.unsafe_load("--- !ruby/struct\nname: Jane\n").to_a
p try402 { YAML.load("--- !ruby/object:Object\na: 1\n") }.first

p try402 { Time.new(2000, 1, 1, 0, 0, 0, "+09:00", in: "+09:00") }

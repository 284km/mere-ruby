# A loaded file's top level is a '<top (required)>' frame under
# 'Kernel#load', as a required one is (it read '<main>', with no load frame),
# and a class_exec / Class.new / Module.new block is a block's frame: its
# own label is `block in X`, and a block written inside it is one level more.
# rspec loads spec files and runs describe blocks with module_exec, so its
# "Called from ...:in 'block (2 levels) in <top (required)>'" read 'block in
# <main>'.
dir = "/tmp/mere_ruby_corpus_897_#{$$}"
Dir.mkdir(dir) unless File.directory?(dir)
loaded = File.join(dir, "loaded.rb")
File.write(loaded, <<~RUBY)
  def at_top = caller_locations(0, 3).map(&:label)
  p at_top
  [1].each { p caller_locations(0, 1)[0].label }
  C897 = Class.new
  C897.class_exec { [2].each { p caller_locations(0, 1)[0].label } }
RUBY
load loaded
File.write(File.join(dir, "thrown.rb"), "throw :t, 42\n")
p catch(:t) { load File.join(dir, "thrown.rb"); :not_thrown }
File.write(File.join(dir, "raised.rb"), "def r897 = raise('boom')\nr897\n")
begin
  load File.join(dir, "raised.rb")
rescue => e
  p e.backtrace_locations.map(&:label)
end
File.write(File.join(dir, "returned.rb"), "p :before\nreturn\np :after\n")
load File.join(dir, "returned.rb")

K = Class.new
K.class_exec { $b897 = proc { caller_locations(0, 1)[0].label }; p caller_locations(0, 1)[0].label }
p $b897.call
K.module_exec { [1].each { p caller_locations(0, 1)[0].label } }
def mk897 = Class.new { [1].each { p caller_locations(0, 1)[0].label }; p caller_locations(0, 1)[0].label }
mk897
Module.new { [1].each { [2].each { p caller_locations(0, 1)[0].label } } }
o = Object.new
o.instance_eval { p caller_locations(0, 1)[0].label }
String.class_eval { p caller_locations(0, 2).map(&:label) }
class Kls897; [1].each { p caller_locations(0, 1)[0].label }; end
File.delete(*Dir[File.join(dir, "*.rb")])
Dir.rmdir(dir)

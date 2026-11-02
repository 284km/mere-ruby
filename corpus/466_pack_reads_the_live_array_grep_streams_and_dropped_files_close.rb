# Array#pack reads the array as it is at each item: a conversion that empties
# it leaves the next directive with too few arguments
ary = []
obj = Class.new { define_method(:to_str) { ary.clear; "TALOS" } }.new
ary.push(obj, ".")
p((ary.pack("AA") rescue $!))
a2 = [1, 2, 3]
o2 = Object.new
o2.define_singleton_method(:to_int) { a2.pop; 7 }
a2[0] = o2
p((a2.pack("CC") rescue $!))
p [1, 2].pack("CC"), ["a", nil].pack("AA")

# Enumerable#grep with a block runs it as #each yields -- even an #each that
# keeps the block and calls it later -- and the match is the caller's $~
c = Class.new do
  include Enumerable
  def each(&b) = (@b = b)
  def check2
    @b.call("foo")
    { check2: $1 }
  end
  def check1 = check2.merge({ check1: $1 })
end
o = c.new
r = nil
p o.grep(/(f..)/) { r = $1 }
p r, $1
p o.check1, r, $1
p [1, 2, 3].each_slice(1).grep([2]) { |x| x }
p (1..6).grep_v(2..4) { |x| x * 10 }

# a File nothing reaches gives its descriptor back when a glob runs out
soft, hard = Process.getrlimit(:NOFILE)
Process.setrlimit(:NOFILE, 64, hard)
begin
  fs = []
  tap { tap { (0..100).each { fs << open(File::NULL) } } }
rescue Errno::EMFILE => e
  p e.class
ensure
  fs.clear
end
p Dir.glob(File.join(__dir__, "466_*")).size
Process.setrlimit(:NOFILE, soft, hard)

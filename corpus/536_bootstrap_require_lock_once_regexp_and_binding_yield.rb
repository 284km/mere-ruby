require 'tmpdir'
dir = Dir.mktmpdir("corpus536")

# STDIN reopened onto a writable file writes there; it refuses while it reads.
path = File.join(dir, "stdin.txt")
rw = File.open(path, File::RDWR | File::CREAT | File::EXCL)
save = STDIN.dup
STDIN.reopen(rw)
STDIN.print "a"
STDIN.puts "b"
STDIN.reopen(save)
rw.close
p File.read(path)

# A second thread requiring a file another thread is loading waits for it.
File.write(File.join(dir, "corpus536_lock.rb"), "sleep 0.05\nmodule Corpus536Lock; end\n")
$:.unshift dir
vs = (1..2).map { Thread.start { require "corpus536_lock"; Corpus536Lock } }.map(&:value)
p vs.all? { |v| v == Corpus536Lock }

# yield in a class body is refused wherever the body is; a method's binding
# yields to the block that method was given.
r = begin
  eval "def yield_eigenclass; class << self; yield self; end; end"
rescue SyntaxError => e
  e.message[/Invalid yield/]
end
p r
def binding_of = binding
p binding_of { |a| a }.eval('yield("ok")')
p eval("binding_of { 'ok2' }").eval("yield")

# A proc written in a class body returns from the lambda the class ran in.
r = lambda do
  class Corpus536A
    class B
      proc { return :from_lambda }.call
    end
  end
  :not_here
end.call
p r

# The main thread's locals survive the first thread.
Thread.current[:corpus536] = 1
p(Thread.new { Thread.current[:corpus536] = 10; Thread.pass; Thread.current[:corpus536] }.value + Thread.current[:corpus536])

# def inside instance_eval of an immediate cannot define a singleton method.
r = begin
  0.instance_eval { def corpus536_m() :m end }
  :ng
rescue TypeError => e
  e.message
end
p r
[1].each { def corpus536_m2() :m2 end }
p corpus536_m2

# A /.../o pattern runs its pieces once, and a thread arriving while another
# builds it takes that one's result.
f = proc { |s, c| /#{c.call; s}/o }
i = 0
th2 = Thread.new { sleep 0.01 until i == 1; i = 2; f.call("bar", proc { sleep 0.3 }); nil }
th1 = Thread.new { f.call("foo", proc { i = 1; sleep 0.01 until i == 2; sleep 0.01 }); nil }
[th1, th2].each(&:join)
p f.call.source

# eval's static refusals: a flow word in a rescue body, a given empty file
# name, a hash splat, two splats in one target group, a range's assignment.
%w[break next redo].each do |w|
  p((begin; eval("0 rescue #{w}"); rescue SyntaxError => e; e.message[/Invalid #{w}/]; end))
end
['{*0}', 'v0,(*,v1,) = 0', '0..$1=1', '@0..0'].each do |code|
  m = begin; eval(code, nil, '', 0); rescue SyntaxError => e; e.message; end
  p m[/(?:\^~*|\A:(?:\d+:)?(?! syntax errors? found)(?: syntax error,)?) (.*)/, 1]
end

# Regexp#=~ reads an object through #to_str, and refuses one without it.
o = Object.new
def o.to_str = "xblah"
p(/blah/ =~ o, $~[0], /blah/ =~ nil)
p((begin; /a/ =~ 1; rescue TypeError => e; e.message; end))

# __FILE__ follows the file's frozen_string_literal comment.
on = File.join(dir, "fsl_on.rb"); off = File.join(dir, "fsl_off.rb")
File.write(on, "# frozen_string_literal: true\n$corpus536 = __FILE__.frozen?\n")
File.write(off, "# frozen_string_literal: false\n$corpus536 = __FILE__.frozen?\n")
load on; a = $corpus536
load off; p [a, $corpus536]

require 'fileutils'
FileUtils.rm_rf(dir)
p :done

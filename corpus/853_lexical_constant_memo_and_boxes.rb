# A lexical constant read is remembered (lex_const_key's memo) while the
# constant table stands still. A Ruby::Box switch changes the table without
# a constant write, so the memo is forgotten there too. Before that, a read
# after a box defined the constant named a key the main box did not have:
# a bare StandardError where ruby raises NameError, and `defined?` said
# "constant". The reads run in a child started with RUBY_BOX=1, as corpus 647
# does. (The child's stderr names the program: not compared.)
child = <<~'CHILD'
  module Math
    def self.review_read
      REVIEW_BOX_CONSTANT
    end
  end
  box = Ruby::Box.new
  p box.eval('module Math; REVIEW_BOX_CONSTANT = :box; def self.review_read; REVIEW_BOX_CONSTANT; end; end; Math.review_read')
  begin
    p Math.review_read
  rescue NameError
    p :missing_in_main
  end
  p box.eval('Math.review_read')
  class String
    def self.peek = (defined?(BOXC) ? BOXC : :none)
  end
  p String.peek
  b = Ruby::Box.new
  b.eval("class String; BOXC = 1; def self.peek2 = BOXC; end; p String.peek2")
  p String.peek
  a = Ruby::Box.new; b2 = Ruby::Box.new
  src = "module Process; class Status; def self.pk = [defined?(BOXK), (begin; BOXK; rescue Exception => e; e.class; end)]; end; end"
  a.eval(src); b2.eval(src)
  a.eval("module Process; BOXK = :in_a; end; Process::Status.pk")
  b2.eval("p Process::Status.pk")
CHILD
IO.popen({"RUBY_BOX" => "1"}, [RbConfig.ruby, "-e", child], err: File::NULL) { |io| print io.read }

# ...and without boxes: a read before and after the constant changes,
# a remove_const, a reopened scope, and a singleton class's own constant
module Outer
  module Inner
    def self.read = [defined?(K) ? K : :none, String.name]
  end
end
p Outer::Inner.read
Outer::K = 1
p Outer::Inner.read
Outer::Inner::K = 2
p Outer::Inner.read
Outer::Inner.send(:remove_const, :K)
p Outer::Inner.read
Outer.send(:remove_const, :K)
p Outer::Inner.read
module M2
  class << self
    X = 3
    def f = X
  end
end
p M2.f
d = M2.dup
p d.f

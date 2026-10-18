# Backtraces and BEGIN/END as test_backtrace and test_beginendblock ask
# (note 366): a frame of an anonymous class's method names no owner, nor one
# with a temporary name; inject(:tap) calls the method; an Enumerator over an
# Array runs its block under 'Array#map' under 'Enumerator#each'; caller(n, 0)
# is [] at any level; a Location's absolute_path; BEGIN only at the top level
# and in another BEGIN, the inner one first; END's warning in an eval at the
# eval's file and line; at_exit's $! after exit, a builtin's refusal in one,
# a signal raised in one ends the process of it; NoMethodError names an
# object with a singleton class as rb_any_to_s does.
require 'tmpdir'
RB = RbConfig.ruby
def scen(name, args, stdin = "", env = {})
  Dir.mktmpdir do |d|
    Dir.chdir(d) do
      yield d if block_given?
      o = IO.popen([env, RB, *args, err: "err.txt"], "r+") { |io|
        w = Thread.new { sleep 30; Process.kill(:KILL, io.pid) rescue nil }
        io.write(stdin) rescue nil; io.close_write; r = io.read; w.kill; r }
      st = $?
      e = File.binread("err.txt").gsub(File.realpath(d), "D").gsub(d, "D").gsub(RB, "RUBY").gsub(/^mere-ruby:/, "RUBY:")
      e = e.lines.reject { |l| l.start_with?("Exception 'LoadError' at ") && l.include?("rubygems") }.join
      puts "== #{name}"; p [o.gsub(d, "D"), e[0, 500].gsub(/0x\h+/, "0xX"), st.exitstatus, st.termsig]
    end
  end
end

def label0
  yield
rescue => e
  e.backtrace[0][/'.*'/]
end
foo = Class.new
def foo.bar = raise
p label0 { foo.bar }
c = Class.new { def baz = raise }
p label0 { c.new.baz }
foo::Bar = Class.new
def (foo::Bar).qux = raise
p label0 { foo::Bar.qux }
p label0 { [1, 2].inject(:tap) }
p [1, 2, 3].inject(:gcd), %w[a b].inject(:concat), [1, 2].inject(:+)
def lbls = caller_locations(0).map(&:label)[1..-2]
p [1].map.map { lbls }, [1].each.map { lbls }, [1].map.each { lbls }
p [1].each_with_index.map { lbls }
p caller(5, 0), caller_locations(5, 0), caller(0, 0), caller(5, 1)
o = Object.new
def o.inspect = raise("never")
begin; o.nope; rescue NoMethodError => e; p e.message.sub(/0x\h+/, "0xX"); end
['def foo; BEGIN {}; end', 'class X; BEGIN {}; end', 'if true; BEGIN {}; end',
 '[1].each { BEGIN {} }', 'eval("def foo; BEGIN {}; end")'].each do |s|
  begin
    eval(s)
    p :no_error
  rescue SyntaxError => e
    p e.message[/BEGIN is permitted only at toplevel/]
  end
end
eval("BEGIN { p :b1; BEGIN { p :b0 } }; p :main")

scen("begin_nested", ["-"], "BEGIN {\n  puts 'b2'\n  BEGIN {\n    puts 'b2-1'\n  }\n}\nputs 'main'\n")
scen("end_warn_eval", ["-"], "eval <<-EOE, nil, \"test.rb\", 0\n  def end2\n    END {}\n  end\nEOE\n")
scen("errinfo_exit", ["-"], "at_exit do\n  puts \"1:\#{$!}\"\nend\nat_exit do\n  puts \"2:\#{$!}\"\n  raise 'x' rescue nil\nend\nat_exit do\n  exit\nend\n")
scen("exitcode", ["-e", "o = Object.new; def o.inspect; raise '[Bug #8501]'; end", "-e", "at_exit{o.nope}"])
scen("builtin_fail", ["-e", "at_exit { Integer('z') }"])
scen("signaled_int", ["-"], "trap(:INT, 'DEFAULT')\nat_exit { raise Interrupt }\n")
scen("signaled_term", ["-e", "at_exit { Process.kill(:TERM, $$) }"])
scen("abs_path", ["-C", "sub", "s.rb"]) { Dir.mkdir("sub"); File.write("sub/s.rb", "loc = caller_locations(0, 1)[0]\nputs loc.absolute_path == File.realpath('s.rb'), loc.path\n") }

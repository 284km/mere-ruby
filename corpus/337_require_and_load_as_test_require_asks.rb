# require and load as test_require asks (note 361): a syntax error in a loaded
# or required file is a SyntaxError and is not recorded as loaded; a wrapped
# load keeps its constants and methods inside the wrapper; $: without "." does
# not search the working directory, and an object on $: is converted as a path
# at each require; "~" in $: is HOME at the time of the require; a feature
# recorded as "foo.so" satisfies `require "foo"`; -I through a symlink and
# require_relative from a symlinked script use the real path, and one file
# reached through a symlink loads once; a frozen $LOADED_FEATURES;
# `Zlib = 1` before `require "zlib"`; -S with names and directories past
# PATH_MAX.
require 'tmpdir'
RB = RbConfig.ruby
def t(label)
  r = begin; yield; rescue Exception => e; "#{e.class}"; end
  puts "#{label}: #{r.inspect}"
end
def scen(name, args, src = "", env = {})
  Dir.mktmpdir do |d|
    Dir.chdir(d) do
      yield d if block_given?
      o = IO.popen([env, RB, *args, err: "err.txt"], "r+") { |io| io.write(src); io.close_write; io.read }
      st = $?
      e = File.read("err.txt").gsub(File.realpath(d), "D").gsub(d, "D")
      e = e.lines.reject { |l| l =~ /^\s+from / }.map { |l| l.sub(/^.*?: /, "") }.join
      puts "== #{name}"; p [o.gsub(File.realpath(d), "D").gsub(d, "D"), e[0, 160], st.exitstatus]
    end
  end
end

Dir.mktmpdir do |d|
  Dir.chdir(d) do
    File.write("syn.rb", ",\n")
    t("load_syn") { begin; load "./syn.rb"; rescue SyntaxError => e; [e.class, e.message.include?("unexpected")]; end }
    t("req_syn") { begin; require "./syn.rb"; rescue SyntaxError => e; [e.class, (begin; require("./syn.rb"); rescue ScriptError => e2; e2.class; end)]; end }
    File.write("m.rb", "def b; 1 end\nclass Foo\n  def c; 2 end\nend\n")
    t("load_mod") { m = Module.new; load("./m.rb", m); c = Class.new { include m; public :b }; [m.private_instance_methods(false), c.new.b, m::Foo.new.c, defined?(::Foo)] }
    t("wrap_isolated") { File.write("w.rb", "WCONST = 1\ndef wmeth; end\n"); load("./w.rb", true); [defined?(WCONST), respond_to?(:wmeth, true)] }
    Dir.mkdir("x"); File.write("x/t.rb", ""); File.write("x/a.rb", "require_relative('t.rb')\n")
    t("relative") { lp = $:.dup; $:.delete("."); begin; [require('./x/t.rb'), require(File.expand_path('x/t.rb')), require('./x/a.rb'), (begin; require('x/t.rb'); rescue LoadError => e2; e2.class; end), (begin; require('x/a.rb'); rescue LoadError => e2; e2.class; end)]; ensure; $:.replace(lp); end }
    File.write("lpo.rb", "")
    t("lp_object") { lp = $:.dup; begin; $:.replace([IO::NULL]); a = Object.new; def a.to_str; "nowhere"; end; $: << a; r = [(begin; require "lpo"; rescue LoadError => e2; e2.path; end)]; d = Dir.pwd; a.define_singleton_method(:to_str) { d }; r << require("lpo") << $:.last.equal?(a); $:.replace([IO::NULL, 3]); r << (begin; require "lpo2"; rescue TypeError => e2; e2.class; end); ensure; $:.replace(lp); end }
    t("so_feature") { lp = $LOAD_PATH.dup; lf = $LOADED_FEATURES.dup; begin; $LOAD_PATH.clear; $LOADED_FEATURES.replace(["foo.so", "a/foo.rb", "b/foo.rb"]); require "foo"; ensure; $LOAD_PATH.replace(lp); $LOADED_FEATURES.replace(lf); end }
  end
end

scen("syntax_child", ["-e", "File.write('s.rb', \"1 +\\n\"); begin; load './s.rb'; rescue SyntaxError; p :syntax; end"])
scen("zlib_const", ["-e", "Zlib = 1\nbegin; require 'zlib'; rescue TypeError => e; p e.class; end"])
scen("symlink_lp", ["-I", "symlink", "-e", "require 'tsl.rb'"]) { Dir.mkdir("real"); File.symlink("real", "symlink"); File.write("real/tsl.rb", "print __FILE__") }
scen("relsym", ["b/tst.rb"]) { Dir.mkdir("a"); Dir.mkdir("b"); File.write("a/lib.rb", 'puts "a/lib.rb"'); File.write("b/lib.rb", 'puts "b/lib.rb"'); File.write("a/tst.rb", 'require_relative "lib"'); File.symlink("../a/tst.rb", "b/tst.rb") }
scen("symlink_once", ["c.rb"]) { Dir.mkdir("a"); File.write("a/a.rb", "require_relative 'b'\n"); File.write("a/b.rb", "$t += 1\n"); Dir.mkdir("b"); File.write("c.rb", "$t = 0\n$:.unshift(File.expand_path('../b', __FILE__))\nrequire 'b'\nrequire 'a'\nprint $t\n"); File.symlink("../a/a.rb", "b/a.rb"); File.symlink("../a/b.rb", "b/b.rb") }
scen("home", ["-"], "$:.replace([IO::NULL])\n$: << '~'\nENV['HOME'] = Dir.pwd\nrequire 'foo'\nENV['HOME'] = Dir.pwd + '/a'\np :ok if require 'bar'\n") { File.write("foo.rb", ""); Dir.mkdir("a"); File.write("a/bar.rb", "") }
scen("S_home", ["-S", "-w", "test_ruby_test_require"], "", {"RUBYPATH" => "~", "HOME" => "/foo" * 1024})
scen("S_home2", ["-S", "-w", "test_ruby_test_require"], "", {"RUBYPATH" => "~" + "/foo" * 1024, "HOME" => "/foo"})
scen("S_quiet", ["-S", "test_ruby_test_require"], "", {"RUBYPATH" => "~", "HOME" => "/foo" * 1024})
scen("S_long", ["-S", "-w", "foo/" * 1024 + "foo"])
scen("req_long", ["-e", "$:.replace([IO::NULL]); begin; require 'foo/' * 3000 + 'foo'; rescue LoadError => e; p e.class; end"])

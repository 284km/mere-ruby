# The command line as test_rubyoptions asks (note 362): one word read as a
# run of switches (-cw, -de, -vve, -wKe, -0e, -We, -Wx), the refusals of a
# switch with no argument and of an unknown one, --dump / -y / --parser /
# --copyright, $-W, RUBYOPT under the command line, -0 and $/ for gets, the
# shebang's -p / -s and its CR, -s names, Kernel#sub/gsub under -p, -c's
# invalid jumps, '= literal' in a condition, --backtrace-limit; and the
# rounds' regressions: IO.new's argument count, IO.write's open_args with
# binmode:, a wrapped load's self.
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
      e = File.binread("err.txt")
      e = e.gsub(RB, "RUBY").gsub(File.realpath(d), "D").gsub(d, "D").gsub(/^mere-ruby:/, "RUBY:")
      e = e.lines.reject { |l| l.start_with?("Exception 'LoadError' at ") }.join
      e = e.sub(/\A.*?-- (\S+) \(LoadError\)\n(\tfrom .*\n)*\z/m) { "LoadError -- #{$1}\n" }
      # (ruby -c reports a jump with prism's source excerpt; the line and the
      #  words are what both say)
      e = e.sub(/\ARUBY: (-e:\d+): syntax error found \(SyntaxError\)\n.*?\^~+ (Invalid \w+)\n.*\z/m) { "RUBY: #{$1}: #{$2} (SyntaxError)\n" }
      # (the platform in `ruby -v` is the build machine's -- arm64-darwin23 on
      #  the CI runner, darwin25 here -- and not what this program asks about)
      o = o.sub(/(\+PRISM) \[[^\]]+\]/, '\1 [PLATFORM]')
      puts "== #{name}"; p [o, e[0, 400], st.exitstatus]
    end
  end
end
scen("de", ["-de", "p $DEBUG"])
scen("debug-", ["--debug-", "-e", "p $DEBUG"])
scen("vve", ["-vve", ""])
scen("verbose_noscript", ["--verbose"])
scen("copyright", ["--copyright"])
scen("enable_bad", %w(--enable foobarbazqux -e) + [""])
scen("enable_missing", %w(--enable))
scen("disable_missing", %w(--disable))
scen("disable_all", %w(--disable all -e) + ["p 1"])
scen("disable_bad", %w(--disable foobarbazqux -e) + [""])
scen("kanji_wKe", ['-wKe', '-eputs"\xc2\xa1".encoding'], "", {'RUBYOPT' => nil})
scen("kanji_Ke", ['-Ke', '-eputs"\xc2\xa1".encoding'], "", {'RUBYOPT' => nil})
scen("kanji_KU_noverbose", ['-KU', '-e', 'p __ENCODING__'])
scen("W0", %w(-W0 -e) + ['p $-W'])
scen("W1", %w(-W1 -e) + ['p $-W'])
scen("Wx", %w(-Wx -e) + ['p $-W'])
scen("W", %w(-W -e) + ['p $-W'])
scen("We", %w(-We) + ['p $-W'])
scen("wW0", %w(-w -W0 -e) + ['p $-W'])
scen("Wqux", %w(-W:qux))
scen("We_cat", ["-We", "p Warning[:performance]"])
scen("parser_prism", %w(--parser=prism -e) + ["puts :hi"])
scen("parser_parsey", %w(--parser=parse.y -e) + ["puts :hi"])
scen("parser_bad", %w(--parser=notreal -e) + ["puts :hi"])
scen("parser_version", %w(--parser=prism --version))
scen("e_nocode", %w(-e))
scen("sep000", %w(-000 -e) + ["print gets"], "foo\nbar\0baz")
scen("sep0141", %w(-0141 -e) + ["print gets"], "foo\nbar\0baz")
scen("sep0e", %w(-0e) + ["print gets"], "foo\nbar\0baz")
scen("sep00", %w(-00 -e) + ["p gets, gets"], "foo\nbar\n\nbaz\nzot\n\n\n")
scen("C_none", %w(-C))
scen("C_bad", %w(-C test_ruby_test_rubyoptions_foobarbazqux))
scen("enc_missing", %w(--encoding))
scen("enc_bad", %w(--encoding test_ruby_test_rubyoptions_foobarbazqux))
scen("Ecesu", %w(-Ecesu-8), 'puts Encoding::default_external')
scen("cw_ok", %w(-cw -e a=1+1 -e !a))
scen("cw_break", %w(-cw -e break))
scen("cw_yield", %w(-cw -e begin -e yield -e end))
scen("cw_def_break", %w(-cw -e !defined?(break)))
scen("n_cw_break", %w(-n -cw -e break))
scen("inv_long", %w(--foobarbazqux))
scen("inv_cr_ok", %W(-\r -e) + [""])
scen("inv_crx", %W(-\rx))
scen("inv_x01", %W(-\x01))
scen("inv_Z", %w(-Z))
scen("rubyopt_dashes", [], "", {"RUBYOPT" => " - -"})
scen("rubyopt_e", [], "", {"RUBYOPT" => '-e "p 1"'})
scen("rubyopt_w_W1", %w(-W1), "p $VERBOSE", {"RUBYOPT" => "-w"})
scen("rubyopt_w_W0", %w(-W0), "p $VERBOSE", {"RUBYOPT" => "-w"})
scen("rubyopt_w_dep_W1", %w(-W1), "p Warning[:deprecated]", {"RUBYOPT" => "-w"})
scen("rubyopt_bare_w", %w(), "p $VERBOSE", {"RUBYOPT" => "w"})
scen("rubyopt_Wqux", %w(), "", {"RUBYOPT" => "-W:qux"})
scen("shebang_cr", [], "#!ruby -KU -Eutf-8\r\np \"あ\"\r\n", {'RUBYOPT' => nil})
scen("shebang_cr_noscript", [], "#! /test_r_u_b_y_test_r_u_b_y_options_foobarbazqux\r\np 1\r\n")
scen("shebang_bang", [], "#!")
scen("shebang_c_bang", ["-c"], "#!")
scen("flag_p_shebang", ["s.rb", "s.rb"]) { File.write("s.rb", "#!ruby -p\n") }
scen("flag_s_shebang", ["s.rb", "-abc=foo"]) { File.write("s.rb", "#!ruby -s\np $abc\n") }
scen("sflag", %w(- -abc -def=foo -ghi-jkl -- -xyz), "#!ruby -s\np [$abc, $def, $ghi_jkl, defined?($xyz)]\n")
scen("sflag_bad", %w(- -#), "#!ruby -s\n")
scen("sflag_bad2", %w(- -#=foo), "#!ruby -s\n")
scen("sflag_debug", ['-s', '-e', 'GC.start; p $DEBUG', '--', '-DEBUG=x'])
scen("missing_dump", %w(-0 --dump))
scen("missing_ext", %w(-0 --external-encoding))
scen("missing_int", %w(-0 --internal-encoding))
scen("missing_bt", %w(-0 --backtrace-limit))
scen("bt_missing", %w(--backtrace-limit))
scen("bt_eq_space", %w(--backtrace-limit= 1))
scen("bt_neg2", %w(--backtrace-limit=-2))
scen("bt_1", %w(--backtrace-limit=1), 'def f(n);n > 0 ? f(n-1) : raise;end;f(5)')
scen("bt_3", %w(--backtrace-limit=3), 'def f(n);n > 0 ? f(n-1) : raise;end;f(5)')
scen("bt_limit", %w(--backtrace-limit=1), "p Thread::Backtrace.limit")
scen("bt_limit_sp", %w(--backtrace-limit 1), "p Thread::Backtrace.limit")
scen("bt_rubyopt", [], "p Thread::Backtrace.limit", {"RUBYOPT" => "--backtrace-limit=5"})
scen("bt_rubyopt_cl", %w(--backtrace-limit=-1), "p Thread::Backtrace.limit", {"RUBYOPT" => "--backtrace-limit=5"})
scen("bt_rubyopt2", [], "p Thread::Backtrace.limit", {"RUBYOPT" => "--backtrace-limit=5 --backtrace-limit=3"})
scen("pflag_gsub", ['-p', '-e', 'gsub(/t.*/){"TEST"}'], "test")
scen("pflag_sub", ['-p', '-e', 'sub(/t.*/){"TEST"}'], "test")
scen("nflag_chop", ['-n', '-e', 'chop; print'], "abc\n")
scen("fsl_disable", ["--disable=gems", "--disable=frozen_string_literal"], 'p("foo".frozen?)', {"RUBYOPT"=>"--enable=frozen_string_literal"})
scen("fsl_enable", ["--disable=gems", "--enable=frozen-string-literal"], 'p("foo".frozen?)', {"RUBYOPT"=>"--disable=frozen-string-literal"})
scen("free_at_exit", ["-W"], "", {"RUBY_FREE_AT_EXIT"=>"1"})
scen("assign_cond", ["-w", "t.rb"]) { File.write("t.rb", "if a = 1\nend\n0.times do\n  if b = 2\n    a += b\n  end\nend\n") }
scen("assign_cond2", ["-w", "t.rb"]) { File.write("t.rb", "if a = ''; end\nif a = []; end\nif a = [1]; end\nif a = [a]; end\nif a = {}; end\nif a = {1=>2}; end\nif a = {3=>a}; end\nif a = :sym; end\n") }
scen("rflag_c", ['-r', './a.rb', '-c', '-ep']) { File.write("a.rb", "abort ':run'\n") }
scen("rflag_dump_syntax", ['-r', './a.rb', '--dump=syntax', '-ep']) { File.write("a.rb", "abort ':run'\n") }
scen("rflag_y", ['-r', './a.rb', '-y', '-ep']) { File.write("a.rb", "abort ':run'\n") }
scen("gc_dir", ["-e", "p RbConfig::CONFIG['modular_gc_dir']"])
scen("setproctitle", ["-e", "begin; Process.setproctitle(\"hello\\0\"); rescue ArgumentError => e; p e.class; end; p Process.setproctitle('x')"])
scen("notfound_r", ["-r", "./notexist.rb", "-ep"])
scen("io_new_count", ["-e", "f = File.open('x', 'w'); begin; IO.new(f.fileno, 'w', {flags: File::CREAT}); rescue ArgumentError => e; p e.message; end; begin; IO.new; rescue ArgumentError => e; p e.message; end"])
scen("io_write_open_args", ["-e", "File.write('w', ''); begin; IO.write('w', 'hi', open_args: [{encoding: Encoding::UTF_32LE, binmode: true}]); rescue IOError => e; p e.message; end; p IO.write('w', 'hi', open_args: ['w', {encoding: Encoding::UTF_32LE, binmode: true}]); p IO.write('w', 'hi', open_args: [{encoding: Encoding::UTF_32LE, binmode: true, mode: 'w'}])"])
scen("wrapped_load_self", ["-e", "load('./l.rb', true); m = Module.new; load('./l.rb', m); p [m.private_instance_methods(false), m.const_defined?(:LW, false), Object.const_defined?(:LW)]"]) { File.write("l.rb", "class LW; end\ndef lwm = :lwm\np [self.to_s, self.class, method(:lwm).owner.class, lwm]\n") }

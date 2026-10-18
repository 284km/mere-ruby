# Exceptions as test_exception asks (note 365): the uncaught report on
# $stderr (the object), END handlers' errors once each, $DEBUG's raise line,
# the circular-require warning through Warning.warn, a script's SyntaxError
# reported through a -r library's #detailed_message and #path, a redefined
# #backtrace asked at the raise; super from an exception's own #message /
# #detailed_message; #path called bare; symbol literals ruby refuses; undump
# refusing \x beside \u; Symbol#== removed and redefined.
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
      # (ruby's syntax_suggest writes its own lines before the report: the
      #  report's last line and any path= line are what both write)
      e = e.lines.select { |l| l.start_with?("path=") }.join + e.lines.last.to_s.sub(/^main.rb: /, "") if $last_line_only
      puts "== #{name}"; p [o.gsub(d, "D"), e[0, 500], st.exitstatus]
    end
  end
end
scen("debug_raise", ["-"], "begin; $DEBUG = true; raise 'boom'; rescue; end; $DEBUG = false; p 1")
scen("debug_raise2", ["-"], "class E < StandardError; end\nbegin; $DEBUG = true; raise E, 'x'; rescue E; end")
scen("end_cause", ["-"], 'END{begin; raise "inner"; rescue; raise "outer"; end}')
scen("trap_cause", ["-"], 'Signal.trap(:EXIT) {begin; raise "inner"; rescue; raise "outer"; end}')
scen("end_cause3", ["-"], %Q(END{begin; raise "middle"; rescue => e; raise "outer", cause: e; end}\nEND{raise "previous"}))
scen("stderr_redirect", ["-"], %Q($stderr = $stdout; raise "x"))
scen("warn_category", ["-W:deprecated", "-"], %Q(module Warning; def self.warn(m, category: nil) = (STDOUT.puts [m, category].inspect); end\n$; = "www"; $; = nil))
scen("eval_syntax_path", ["-e", 'begin; eval("1+", nil, "x.rb"); rescue SyntaxError => e; p e.path; end'])
scen("redefined_bt", ["-"], %Q(class Exception\n  def backtrace\n    $exc = self\n    super\n  end\nend\nbegin; raise RuntimeError, "hello"; rescue => e; p e.message; end\np $exc.equal?(e)))
scen("undef_bt", ["-"], %Q(class Exception\n  undef backtrace\nend\nbegin; raise RuntimeError, "hello"; rescue => e; p e.class; end))
$last_line_only = true
scen("syntax_detail_main", ["-r./detail", "main.rb"]) { File.write("detail.rb", "class SyntaxError\n  def detailed_message(**)\n    \"<detail.rb>\"\n  end\nend\n"); File.write("main.rb", "1 +\n") }
scen("syntax_path", ["-r./lib", "main.rb"]) { File.write("lib.rb", "class SyntaxError\n  def detailed_message(**)\n    STDERR.puts \"path=\#{path}\"\n    \"x\"\n  end\nend\n"); File.write("main.rb", "1+\n") }
$last_line_only = false
scen("circular", ["-w", "-I.", "-"], %Q(module Warning; def self.warn(m, **) = (STDOUT.puts [m[/considered harmful - .*/], m.lines.any? { |l| l =~ /^\\tfrom .*circ.rb:1:/ }].inspect); end\nrequire "circ")) { File.write("circ.rb", "require 'circ'\n") }
def t(label)
  r = begin; yield; rescue Exception => e; "#{e.class}"; end
  puts "#{label}: #{r.inspect}"
end
t("super_exc") { c = Class.new(StandardError) { def message = "<#{super}>"; def detailed_message(**) = "D#{super}" }; [c.new("m").message, c.new("m").detailed_message] }
t("message_only") { c = Class.new(StandardError) { def message = "<m2>" }; c.new("m").detailed_message }
t("path_bare") { c = Class.new(LoadError) { def x = path }; c.new("m").x }
t("sym_lex") { [":||", ":[", ":$-#", ":@@", ":~@", ":!@", ":$- ", ":$-w", ":[]="].map { |c| begin; eval(c); rescue SyntaxError; :syntax_error; end } }
t("undump_mix") { ['"\\x82\\xA0\\u3042"', '"\\u3042\\x82\\xA0"', '"\\x00\\u3042"'].map { |c| (c.dup.force_encoding("SJIS").undump.bytes rescue $!.class) } }
t("sym_eq") { IO.popen([RB, "-e", "class Symbol; remove_method :==; def ==(o) = 'foo'; end; puts :a == :a"], &:read) }

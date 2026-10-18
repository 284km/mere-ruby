# ARGF as test_argf asks (note 359): in-place editing that is switched off
# and on between files, the stdio warnings, ARGF's writers, -pi-, a shebang
# line's switches, a dup's own file list, $. and ARGF.lineno, a file that
# cannot be opened or renamed, a UTF-16 suffix and path, stdin paragraphs.
require 'tmpdir'
RB = RbConfig.ruby
def scen(name, args, src, files: true, stdin: nil)
  Dir.mktmpdir do |d|
    Dir.chdir(d) do
      File.binwrite("t1", "1\n2\n"); File.binwrite("t2", "3\n4\n"); File.binwrite("t3", "5\n6\n")
      argv = args.map { |a| a == :files ? %w[t1 t2 t3] : a }.flatten
      o = IO.popen([RB, *argv, err: "err.txt"], "r+") { |io| io.write(stdin || src); io.close_write; io.read }
      st = $?
      e = File.read("err.txt")
      e = e.lines.reject { |l| l =~ /^\s+from / }.map { |l| l.sub(/^.*?:\d+:in /, "") }.join
      res = %w[t1 t2 t3 t1.bak t2.bak t3.bak].map { |f| [f, File.exist?(f) ? File.binread(f) : nil] }.to_h
      puts "== #{name}"; p [o, e, st.exitstatus, res]
    end
  end
end
scen("inplace", ["-", :files], "ARGF.inplace_mode = '.bak'\nwhile line = ARGF.gets\n  puts line.chomp + '.new'\nend\n")
scen("inplace2", ["-", :files], <<'S')
ARGF.inplace_mode = '.bak'
puts ARGF.gets.chomp + '.new'
puts ARGF.gets.chomp + '.new'
p ARGF.inplace_mode
ARGF.inplace_mode = nil
puts ARGF.gets.chomp + '.new'
puts ARGF.gets.chomp + '.new'
p ARGF.inplace_mode
ARGF.inplace_mode = '.bak'
puts ARGF.gets.chomp + '.new'
p ARGF.inplace_mode
ARGF.inplace_mode = nil
puts ARGF.gets.chomp + '.new'
S
scen("inplace3", ["-i.bak", "-", :files], <<'S')
puts ARGF.gets.chomp + '.new'
puts ARGF.gets.chomp + '.new'
p $-i
$-i = nil
puts ARGF.gets.chomp + '.new'
puts ARGF.gets.chomp + '.new'
p $-i
$-i = '.bak'
puts ARGF.gets.chomp + '.new'
p $-i
$-i = nil
puts ARGF.gets.chomp + '.new'
S
scen("dup", ["-", "t1"], "ARGF.inplace_mode = '.bak'\nf = ARGF.dup\nwhile line = f.gets\n  puts line.chomp + '.new'\nend\n")
scen("stdin", ["-", "-"], "ARGF.inplace_mode = '.bak'\nf = ARGF.dup\nwhile line = f.gets\n  puts line.chomp + '.new'\nend\n")
scen("stdin2", ["-"], "ARGF.inplace_mode = '.bak'\nwhile line = ARGF.gets\n  puts line.chomp + '.new'\nend\n")
scen("putc", ["-pi-", "-e", "print ARGF.putc('x')", "t1"], "")
scen("puts", ["-pi-", "-e", "print ARGF.puts('foo')", "t1"], "")
scen("print", ["-pi-", "-e", "print ARGF.print('foo')", "t1"], "")
scen("printf", ["-pi-", "-e", "print ARGF.printf('%s', 'foo')", "t1"], "")
scen("17117", ["-", "t1"], "#!/usr/bin/ruby -pi.bak\nBEGIN {\n  GC.start\n}\nputs \"hello\"\n")
scen("lineno", ["-e", "a = ARGF; a.gets; p $.; a.gets; p $.; a.gets; p $.; a.rewind; p $.; a.gets; p $.; a.gets; p a.lineno; a.lineno = 100; a.gets; p $.", :files], "")
scen("lineno2", ["-e", "a = ARGF.dup; a.gets; p $.; a.gets; p $.; a.gets; p $.; a.rewind; p $.; a.gets; p $.", :files], "")
scen("argf", ["-e", "a = ARGF; b = a.dup; p [a.gets.chomp, a.lineno, b.gets.chomp, b.lineno]; p [a.gets.chomp, a.lineno, b.gets.chomp, b.lineno]; p [a.gets.chomp, a.lineno, b.gets.chomp, b.lineno]", :files], "")
scen("lineno_global", ["-", :files], File.read(__FILE__)[/^=begin L1\n(.*?)^=end/m, 1])
scen("lineno_dup", ["-", :files], File.read(__FILE__)[/^=begin L1\n(.*?)^=end/m, 1].sub("a = ARGF\n", "a = ARGF.dup\n"))
scen("stdin_para", ["-e", "ARGF.each_line('') { |l| p l }"], nil, stdin: "a\n\nb\n")
=begin L1
a = ARGF
a.gets; p($.)
a.gets; p($.)
a.gets; p($.)
a.rewind; p($.)
a.gets; p($.)
a.gets; p($.)
a.rewind; p($.)
a.gets; p($.)
a.lineno = 1000; p($.)
a.gets; p($.)
a.gets; p($.)
$. = 2000
a.gets; p($.)
a.gets; p($.)
=end
def t(label)
  r = begin; yield; rescue Exception => e; "#{e.class}: #{e.message.sub(/\/.*\//, '/D/')}"; end
  puts "#{label}: #{r.inspect}"
end
require "tmpdir"; Dir.chdir(Dir.mktmpdir)
File.write("t1", "1\n2\n")
t("enc") { a = ARGF.class.new("t1"); [a.external_encoding.is_a?(Encoding), a.internal_encoding.is_a?(Encoding), (a.gets; a.external_encoding.is_a?(Encoding)), a.internal_encoding] }
t("unreadable") { a = ARGF.class.new("nx1", "nx2"); r = []; 2.times { r << (begin; a.gets; rescue => e; [e.class, e.message]; end) }; r << a.gets; r }
t("u16path") { File.write("argf-\u{30c6}", "foo"); a = ARGF.class.new("argf-\u{30c6}".encode("UTF-16LE")); a.gets }
t("u16suffix") { File.write("sx", "foo"); a = ARGF.class.new("sx"); a.inplace_mode = "-bak".encode("UTF-16LE"); o = $stdout; begin; a.each { |s| puts "+" + s }; ensure; $stdout.close unless $stdout == o; $stdout = o; end; [File.read("sx"), File.exist?("sx-bak")] }

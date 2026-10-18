# IO as test_io asks for it (note 357): display, the nonblock exception:
# flag, an uninitialized IO, copy_stream's conversions, ungetc's capacity and
# write position, reopen's shared position, a dup of a read-write popen, and
# a close that finds its descriptor already gone.
require 'tmpdir'; require 'stringio'; require 'tempfile'
Dir.chdir(Dir.mktmpdir)
def t(label)
  r = begin; yield; rescue Exception => e; "#{e.class}: #{e.message}"; end
  puts "#{label}: #{r.inspect}"
end
File.write("a.txt", "x")
t("display") { r, w = IO.pipe; "foo".display(w); 12.display(w); w.close; r.read }
t("rnb_zero") { File.open(IO::NULL) { |r| s = +"01234567"; [r.read_nonblock(0, s), s] } }
t("rnb_exc") { r, w = IO.pipe; r.read_nonblock(4096, exception: 1) }
t("wnb_exc") { r, w = IO.pipe; w.write_nonblock("x", exception: 1) }
t("uninit_print") { IO.allocate.print "" }
t("uninit_close") { IO.allocate.close }
t("reinit") { f = File.open("a.txt"); f.instance_eval { initialize } }
t("explicit_path") { io = IO.for_fd(0, path: "Fake Path", autoclose: false); [io.inspect, io.path] }
t("advise") { File.open("a.txt") { |f| f.advise(:normal, 0, 9999e99) } }
t("to_int_big") { [1e20.to_int, -1e20.to_int] }
t("binwrite_neg") { [(File.binwrite('nonexisting', 'string', -2) rescue $!.class), File.exist?('nonexisting')] }
t("write_enc") { File.write("e.txt", "\u{3042}", mode: "w", encoding: "EUC-JP"); File.binread("e.txt") }
t("write_enc2") { File.write("e2.txt", "\u{3042}", mode: "w:EUC-JP"); File.binread("e2.txt") }
t("set_stdout") { $> = Object.new }
t("ungetc_w") { r, w = IO.pipe; w.close; s = "a" * 1000; 200.times { r.ungetc s }; :no }
t("ungetc_write") { File.open("g", "w+b") { |f| f.write "abcd\n"; f.rewind; f.read(3); f.ungetc "c"; f.write "Z" }; File.read("g") }
t("rl_rs") { File.write("u.txt", "ab\ncd\n"); File.open("u.txt", encoding: "utf-8:utf-32le") { |f| [f.readline.encoding, (f.readline("\0") rescue $!.class)] } }
t("rl_limit") { File.open("t2", "w+b:utf-32le") { |f| f.write("0123456789"); f.rewind; [f.readline(4).bytesize, f.readline(3).bytesize] } }
t("rl_limit_conv") { File.open("t3", "w+:utf-8:utf-32le") { |f| f.write("0123456789"); f.rewind; [f.readline(4).bytesize, f.readline(3).bytesize] } }
t("fcntl_dupfd") { require 'fcntl'; File.open("a.txt") { |f| fd = f.fcntl(Fcntl::F_DUPFD, 10); x = fd >= 10; IO.for_fd(fd).close; x } }
t("binmode_pipe") { a = IO.pipe(binmode: true); b = IO.pipe("UTF-8:UTF-8", binmode: true); [a.map(&:binmode?), a[0].external_encoding, b.map(&:binmode?), b[0].external_encoding] }
t("autoclose") { f = File.open("a.txt"); g = IO.for_fd(f.fileno, autoclose: true); g.close; begin; f.close; rescue => e; e.class; end }
t("exc_at_close") { IO.pipe { |r, w| IO.open(w.fileno) {} } }
class Rot13IO
  def initialize(io) = @io = io
  def readpartial(*a) = @io.readpartial(*a).tr!('a-zA-Z', 'n-za-mN-ZA-M')
  def write(s) = @io.write(s.tr('a-zA-Z', 'n-za-mN-ZA-M'))
  def to_io = @io
end
File.write("src", "abcdef")
t("cs_rot_dst") { File.open("src") { |s| File.open("d1", "w") { |d| IO.copy_stream(s, Rot13IO.new(d), 3) } }; File.read("d1") }
t("cs_rot_src") { File.open("src") { |s| File.open("d2", "w") { |d| IO.copy_stream(Rot13IO.new(s), d, 4) } }; File.read("d2") }
t("cs_zero") { File.write("d3", "foobar"); [IO.copy_stream("src", "d3", 0), File.read("d3")] }
t("cs_zero_noent") { IO.copy_stream("nonexist", "d4", 0) }
t("cs_strio_off") { r, w = IO.pipe; IO.copy_stream(StringIO.new("abcd"), w, 3, 1) }
t("cs_rbuf") { r, w = IO.pipe; w << "xyz"; w.close; File.open("fom", "w+b") { |f| f.write "abcd\n"; f.rewind; f.read(3); f.ungetc "c"; IO.copy_stream(r, f) }; File.read("fom") }
t("tmp_bin") { b = Tempfile.new("x", binmode: true); b.write("\xff\xfe"); b.rewind; r = [b.binmode?, b.read.encoding]; b.close!; r }
t("open_pipe_path") { open("|echo foo", "r+") }
t("open_r+_missing") { File.open("nonexist", "r+") }
File.write("t", "foo\nbar\nbaz\n")
t("reopen_twice") { File.open("a.txt") { |f| f2 = File.open("t"); f.reopen(f2); a = [f.gets, f.gets]; f.reopen(f2); a << f.gets; f2.close; a } }
t("reopen_bin") { f1 = File.open("a.txt"); f2 = File.open("a.txt"); f1.binmode; f1.reopen(f2); f1.binmode? }
t("reopen_enc") { File.open("a.txt") { |f| f.reopen("t", encoding: "ASCII-8BIT"); f.gets.encoding } }
t("reopen_stdin") { f = File.open(IO::NULL); f.instance_variable_set(:@foo, 42); f.reopen(STDIN); f.instance_variable_get(:@foo) }
t("popen_opts") { f = IO.popen(["echo", "hi"], "r", {}); [f.pid.class, f.read].tap { f.close } }
t("dup_rw") { f = IO.popen(["cat"], "r+"); f2 = f.dup; f.puts "foo"; f2.puts "bar"; f.close_write; f2.close_write; r = [f.read, f2.read]; f2.close; f.close; r }
t("str_stdout") { c = String.new; def c.write(s) = self << s; o = $stdout; $stdout = c; puts "hey"; $stdout = o; [c, c.method(:write).arity] }
t("data_stdin") { IO.popen([RbConfig.ruby, "-"], "r+") { |io| io.write("p DATA.read\np DATA.binmode?\n__END__\nhi\n"); io.close_write; io.read } }

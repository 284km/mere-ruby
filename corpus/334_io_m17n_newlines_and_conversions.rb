# test_io_m17n as it asks (note 358): text mode reads CRLF and CR as LF (in
# the code units of the external encoding, and a later binmode reads on from
# the right byte); invalid:/undef:/replace: reach the File's conversions;
# validate_enc_binmode; a pipe's universal_newline; BOM| with an internal
# encoding and in encoding:.
def t(label)
  r = begin; yield; rescue Exception => e; "#{e.class}: #{e.message}"; end
  puts "#{label}: #{r.inspect}"
end
require 'tmpdir'; Dir.chdir(Dir.mktmpdir)
File.binwrite("crlf", "a\r\nb\r\nc\r\n"); File.binwrite("cr", "a\rb\rc\r"); File.binwrite("lf", "a\nb\nc\n")
%w[crlf cr lf].each do |n|
  t("read_#{n}") { [File.read(n, mode: "rt"), File.read(n, mode: "rt:euc-jp:utf-8"), File.open(n, "rt", &:read), File.open(n, "r", textmode: true, &:read)] }
  t("gets_#{n}") { File.open(n, "rt") { |f| [f.gets, f.gets, f.gets, f.gets] } }
  t("getc_#{n}") { File.open(n, "rt") { |f| a = []; while (c = f.getc); a << c; end; a } }
  t("univ_#{n}") { File.open(n, "r", newline: :universal) { |f| [f.gets, f.gets, f.read] } }
  t("rl_#{n}") { File.open(n, "rt", &:readlines) }
end
t("univ_off") { File.open("crlf", "r", textmode: true, universal_newline: false, &:read) }
t("binmode_mid") { File.open("crlf", "rt") { |f| a = [f.getc, f.getc]; f.binmode; 7.times { a << f.getc }; a } }
t("binmode_mid2") { File.open("crlf", "rt:euc-jp:utf-8") { |f| a = [f.getc, f.getc]; f.binmode; 7.times { a << f.getc }; a } }
File.binwrite("u16be", "\0a\0\r\0\n\0b\0\r\0\n\0c\0\r\0\n"); File.binwrite("u16le", "a\0\r\0\n\0b\0\r\0\n\0c\0\r\0\n\0")
t("u16") { [File.read("u16be", mode: "rt:utf-16be:utf-8"), File.read("u16le", mode: "rt:utf-16le:utf-8")] }
File.binwrite("t", "a\rb\r\nc\n\xc2\xa2")
t("read_mode") { [File.open("t", "rt", &:read), File.open("t", "rb", &:read), File.open("t", "rt:euc-jp:utf-8", &:read)] }
t("para") { File.binwrite("p", "a\r\n\r\n\r\nc\r\n"); File.open("p", "rt") { |f| [f.gets(""), f.gets("")] } }
t("pos") { File.open("crlf", "rt") { |f| f.gets; f.pos } }
t("eof") { File.open("crlf", "rt") { |f| f.read; f.eof? } }
File.binwrite("inv", "a\x80b"); File.write("und", "a�b"); File.write("e", "")
t("inv_r") { open("inv", "r:utf-8:euc-jp", invalid: :replace, &:read) }
t("inv_r2") { open("inv", "r:utf-8:euc-jp", invalid: :replace, replace: "", &:read) }
t("inv_r3") { open("inv", "r:utf-8:euc-jp", undef: :replace) { |f| [(f.read rescue $!.class), f.read] } }
t("und_r") { open("und", "r:utf-8:euc-jp", undef: :replace, &:read) }
t("und_r3") { open("und", "r:utf-8:euc-jp", invalid: :replace) { |f| [(f.read rescue $!.class), f.read] } }
t("inv_w") { open("o1", "w:euc-jp", invalid: :replace) { |f| f.write "a\x80b".force_encoding("utf-8") }; File.binread("o1") }
t("inv_w2") { open("o2", "w:euc-jp", invalid: :replace, replace: "") { |f| f.write "a\x80b".force_encoding("utf-8") }; File.binread("o2") }
t("inv_w3") { open("o3", "w:euc-jp", undef: :replace) { |f| f.write "a\x80b".force_encoding("utf-8") } }
t("und_w") { open("o4", "w:euc-jp:utf-8", undef: :replace) { |f| f.write "a�b" }; File.binread("o4") }
t("und_w_st") { open("o5", "w:iso-2022-jp:utf-8", undef: :replace) { |f| f.write "a�b" }; File.binread("o5") }
t("rb_univ") { open("e", "rb", newline: :universal) {} }
t("rt_u16") { open("e", "rt:utf-16be") {} }
t("r_u16") { open("e", "r:utf-16be") {} }
t("rb_u16") { open("e", "rb:utf-16be") { :ok } }
t("rt_2022") { open("e", "rt:iso-2022-jp") {} }
t("rb_2022") { open("e", "rb:iso-2022-jp") { :ok } }
t("set_enc_rt") { open("e", "rt") { |f| f.set_encoding("iso-2022-jp") } }
t("set_enc_r") { open("e", "r") { |f| f.set_encoding("iso-2022-jp") } }
t("set_enc_rb") { open("e", "rb") { |f| f.set_encoding("iso-2022-jp"); :ok } }
t("w_u16") { open("o6", "w:utf-16be") { |f| f.write "a" }; File.binread("o6") }
def pp_(data, *a, **o)
  r, w = IO.pipe(*a, **o); w << data; w.close; x = yield r; r.close; x
end
t("pipe_univ_gets") { pp_("a\r\n\r\n\r\nc", "US-ASCII:UTF-8", universal_newline: true) { |r| [r.gets(""), r.gets("")] } }
t("pipe_univ_read") { pp_("a\r\nb\rc\n", "US-ASCII:UTF-8", universal_newline: true) { |r| r.read } }
t("pipe_univ_getc") { pp_("a\r\nb", "US-ASCII:UTF-8", universal_newline: true) { |r| [r.getc, r.getc, r.getc, r.getc] } }
t("pipe_univ_bin") { pp_("a\r\n\r\n\r\ncdefgh", "US-ASCII:UTF-8", universal_newline: true) { |r| [r.gets(""), r.read(3)] } }
t("pipe_plain") { pp_("a\r\nb") { |r| r.read } }
%w/UTF-8 UTF-16BE UTF-16LE UTF-32BE UTF-32LE/.each do |name|
  c = "﻿Āa".encode(name); File.binwrite("#{name}.txt", c)
  t("bom1_#{name}") { r = File.read("#{name}.txt", mode: 'rb:BOM|UTF-8'); [r.encoding, r.b == c[1..-1].b] }
  %w[rb rt r].each { |m| t("bom2_#{name}_#{m}") { r = File.read("#{name}.txt", mode: "#{m}:BOM|UTF-8:UTF-8"); [r.encoding, r] } }
  t("sebb_#{name}") { File.open("#{name}.txt", "rb") { |f| f.set_encoding_by_bom } }
end
File.binwrite("u8", "﻿a".b)
t("noconv") { File.read("u8", encoding: 'BOM|UTF-8').b }
File.binwrite("u8i", "﻿a\xff".b)
t("inv") { r = File.read("u8i", encoding: 'BOM|UTF-8'); [r, r.valid_encoding?] }
t("inv2") { r = File.read("u8i", encoding: 'BOM|UTF-8:UTF-8'); [r, r.valid_encoding?] }

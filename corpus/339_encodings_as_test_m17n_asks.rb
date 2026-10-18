# coding: US-ASCII
# Encodings as test_m17n asks (note 363): a regexp literal in a non-UTF-8
# source is in the source's encoding (BINARY for US-ASCII and BINARY
# sources) and fixed to it; Regexp.new of an escaped non-ASCII pattern takes
# its string's encoding; the regexp checks (mixed \u, surrogates); String#index
# refuses an incompatible regexp; %s width and %c in the string's encoding;
# String(10) is US-ASCII; inspect writes in default_internal/external, other
# encodings' characters escaped; interpolated literals take their pieces'
# encodings as rb_str_concat_literals does; "internal" names default_internal.
def t(label)
  r = begin; yield; rescue Exception => e; "#{e.class}"; end
  puts "#{label}: #{r.inspect}"
end
def a(str) str.b end
def e(str) str.dup.force_encoding("EUC-JP") end
def s(str) str.dup.force_encoding("Windows-31J") end
def u(str) str.dup.force_encoding("UTF-8") end
t("re_e") { r = /a/e; [r.encoding, r.fixed_encoding?] }
t("re_e2") { r = /\xc2\xa1/e; [r.encoding, r.fixed_encoding?] }
t("re_eval_e") { r = eval(e(%{/\xc2\xa1/})); [r.encoding, r.fixed_encoding?] }
t("re_eval_eq") { r = eval(e(%q{/\xc2\xa1/})); [r.encoding, r.fixed_encoding?] }
t("re_s") { r = /a/s; [r.encoding, r.fixed_encoding?] }
t("re_n") { r = /\xc2\xa1/n; [r.encoding, r.fixed_encoding?] }
t("re_eval_a") { r = eval(a(%{/\xc2\xa1/})); [r.encoding, r.fixed_encoding?] }
t("re_e_match") { r = /a/e; [r =~ a("a"), r =~ e("a"), r =~ u("a"), (r =~ a("\xc2\xa1") rescue $!.class), r =~ e("\xc2\xa1"), (r =~ s("\xc2\xa1") rescue $!.class)] }
t("re_e2_match") { r = /\xc2\xa1/e; [r =~ a("a"), r =~ e("\xc2\xa1"), (r =~ u("\xc2\xa1") rescue $!.class)] }
t("re_n_match") { r = /\xc2\xa1/n; [r =~ a("\xc2\xa1"), (r =~ e("\xc2\xa1") rescue $!.class)] }
t("re_dyn_e") { r = /#{ }\xc2\xa1/e; [r.encoding, r.fixed_encoding?] }
t("re_dyn_e_bad") { eval('/\xc2#{ }/e'); :ok }
t("re_mixed_u") { eval(u(%{/\xc2\xa1\\u{6666}/})); :ok }
t("re_short") { eval('/\xc2/u'); :ok }
t("re_prop_lit") { r = /\p{Hiragana}/e; [r.encoding, r.fixed_encoding?] }
t("index") { e("\xa1\xa2a\xa3\xa4").index(Regexp.new(a("\xc2\xa1"))) }
t("sprintf_s") { r = "%10s" % a("\xc2\xa1"); [r, r.encoding] }
t("sprintf_c") { r = e("%c") % 0xc2a1; [r.bytes, r.encoding] }
t("sprintf_c2") { e("%c") % 0xc2 }
t("sprintf_c3") { r = s("%c") % 0xc2; [r.bytes, r.encoding] }
t("sprintf_c4") { "%c" % "\u3042\u3044".encode('Windows-31J') == "\u3042".encode('Windows-31J') }
t("sprintf_p") { r = "%p".force_encoding("ASCII-8BIT") % ""; [r, r.encoding] }
t("sprintf_p2") { r = "%p".force_encoding("EUC-JP") % "a"; [r, r.encoding] }
t("str_dump") { x = e("\xfe"); d = x.dump; [eval(d).encoding, eval("# frozen-string-literal: true\n#{d}").encoding] }
t("inspect_inv") { [e("\xfe ").inspect, e("\x8e ").inspect, e("\x8f\xa1 ").inspect, u("\xe0\x80 ").inspect, s("\x81.").inspect] }
t("inspect_enc") { str = e("\xa1\x8f\xa1\xa1"); str.inspect }
t("setbyte") { x = "a"; [x.setbyte(0, 256), x, (x.setbyte(0, -1); x.bytes)] }
t("String10") { String(10).encoding }
t("defint_names") { Encoding.default_internal = "UTF-8"; r = Encoding.default_internal.names.include?("internal"); Encoding.default_internal = nil; r }
t("re_surr") { eval '/\u{D800}/u'; :ok }
t("re_mixed") { eval(e(%{/\xc2\xa1\\u{6666}/})); :ok }
t("re_prop_enc") { r = Regexp.new('\p{Hiragana}'.force_encoding("euc-jp")); [r.encoding, r.fixed_encoding?] }
t("re_opts") { [eval('/\x80/'.force_encoding("US-ASCII")).options, eval(e('/\xc2\xa1/')).inspect] }
t("rx_new") { [Regexp.new('\xc2\xa1'.force_encoding("EUC-JP")).encoding, Regexp.new('\xc2\xa1'.b).encoding, Regexp.new('a'.force_encoding("EUC-JP")).encoding] }
t("interp") { d = e("abc"); d2 = e("\xa1\xa1"); ["x#{d}".encoding, "#{d}".encoding, "x#{d2}".encoding, "x#{u("b")}".encoding, "x#{1}".encoding] }
t("interp_bin") { eval("# encoding: ASCII-8BIT\nx = \"\#{1}\\n\#{2}\"; x.encoding") }
t("p_fmt") { %w[US-ASCII ASCII-8BIT EUC-JP ISO-8859-1 Big5-HKSCS CP850 UTF8-MAC].map { |en| x = "\xC2\xA1".dup.force_encoding(en); [x.inspect, ("%p".dup.force_encoding(en) % x).encoding] } }
t("inspect_misc") { ["\u3042".dup.force_encoding("UTF8-MAC").inspect, e("\xa1\x8f\xa1\xa1").inspect, e("\x8f\xa1 ").inspect] }

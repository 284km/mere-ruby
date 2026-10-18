# coding: US-ASCII
# Regexps as test_regexp asks (note 364): to_s of a UTF-16/32 regexp in its
# encoding, quote of a broken wide string, MatchData has no allocate, $=
# warns, a dynamic regexp's raw non-ASCII beside \u (and /n's refusals),
# control/meta escapes as bytes (and their #source), comments left alone
# under /x, the '-' before && and duplicated-range warnings, \p with no
# brace, case folds that change length (ss / sharp s, st / ligatures).
require 'stringio'
def t(label)
  r = begin; yield; rescue Exception => e; "#{e.class}: #{e.message[0, 70]}"; end
  puts "#{label}: #{r.inspect}"
end
def warns
  o = $stderr; $stderr = StringIO.new; v = $VERBOSE; $VERBOSE = true
  begin; yield; $stderr.string.gsub(/^.*?:\d+: /, ""); ensure; $stderr = o; $VERBOSE = v; end
end
t("to_s") { %w[UTF-16BE UTF-16LE UTF-32BE UTF-32LE].map { |e| rs = Regexp.new("abcd\u3042".encode(e)).to_s; [rs.encoding.to_s, rs == "(?-mix:abcd\u3042)".encode(e)] } }
t("to_s_nul") { Regexp.new("\0").to_s }
t("quote") { s = "\x00".force_encoding("UTF-16BE"); [Regexp.quote(s) == s, Regexp.quote("\u3042\t").bytes, Regexp.quote("\t" + [0xff].pack("C")).bytes] }
t("md_alloc") { [MatchData.respond_to?(:allocate), Rational.respond_to?(:allocate), Regexp.respond_to?(:allocate)] }
t("dollar_eq") { Warning[:deprecated] = true; w = warns { $=; $= = nil }; Warning[:deprecated] = false; w }
t("u_mix") { [(s = "\xff" + '\u3042'; /#{s}/ rescue $!.message), (s = '\u3042' + [0xff].pack("C"); /#{s}/ rescue $!.message)] }
t("n_dyn") { [(s = "\u3042"; eval(%q(/#{s}/n)) rescue $!.message), (s = "a"; eval(%q(/\u3042#{s}/n)) rescue $!.class)] }
t("ctrl_meta") { [/\c\xFF/ =~ "\c\xFF", /\c\M-\xFF/ =~ "\c\M-\xFF", /\C-\xFF/ =~ "\C-\xFF", /\M-a/ =~ "\M-a", /\M-\C-a/ =~ "\M-\C-a", /[\M-a]/ =~ "\M-a"] }
t("cm_source") { [/\cA/.source, /\c?/.source, /\M-\C-a/.source, %r{\cA\M-b}.source, /\ca/.source] }
t("x_comment") { re = /
  foo  # \M-ca
  bar
/x; [re =~ "foobar", (/f(?# \M-ca)oo/ =~ "foo")] }
t("dash_amp") { r = nil; w = warns { r = eval('/\A[a-&&\w]\z/') }; [w, r =~ "a", r =~ "-"] }
t("posix_dup") { warns { eval('/\A[[:^alpha:]0]\z/'); eval('/\A[[:alpha\:]]\z/'); /[\w_]/; /[\d0-9]/ } }
t("p_brace") { r = nil; [warns { r = eval('/\p%s/') }, r =~ "p%s"] }
def m(re, s) = (re =~ s) && [$~.begin(0), $~.end(0)]
t("fold") { [m(/^\ufb05$/i, "\ufb06"), m(/^\ufb05$/i, "st"), m(/(?i:ss)/, "\u00df"), m(/(?i:ss)/, "\u1e9e"), m(/(?i:xssy)/, "x\u00dfy"), m(/(?i:\u00df)/, "SS"), m(/(?i:[\u00df])/, "ss"), m(/st/i, "\ufb06"), m(/(?i)(?<!ss)\u2728/, "qq\u2728")] }
t("fold_plain") { [m(/abc/i, "ABC"), "STRASSE".match?(/stra\u00dfe/i), m(/(?-i:ss)/, "\u00df")] }

# Regexps as test_regexp asks them (note 348).
def t(name)
  r = begin; yield.inspect; rescue Exception => e; "#{e.class}: #{e.message[0, 60]}"; end
  puts "#{name}: #{r}"
end

# case folding beyond ASCII
t(:fold_ss) { [/ss/i =~ "ß", /ß/i =~ "SS", /(?i:ss)/ =~ "ſS", /s/i =~ "ſ", /k/i =~ "\u212A", /ß/i =~ "ẞ", /^\u00df$/i =~ "ss"] }
t(:fold_class) { [/[xó]/i =~ "abcÓ", /[a-z]/i =~ "\u212A", /[é]/i =~ "É", /[^a-z]/i =~ "\u212A"] }
t(:fold_extra) { [/^\u00c5$/i =~ "\u212B", /ω/i =~ "\u2126", /^\u0149$/i =~ "\u02bcN"] }
t(:fold_ref) { [/^(\u00c5)\1\1$/i =~ "\u00c5\u00e5\u212b", /(s)\1/i =~ "sſ"] }
t(:fold_quant) { [/s*/i =~ "ss", /ss+/i =~ "sss", "Mississippi" =~ /SS/i] }
e = Encoding::ISO_8859_1
t(:latin1) { lo = "\u00F3".encode(e); up = "\u00D3".encode(e); [/[x#{lo}]/i =~ "abc#{up}", /[x#{lo}]/ =~ "abc#{up}"] }
r = Regexp.new("(?i:ss)".encode("US-ASCII"))
t(:ascii_then_utf8) { [r.match("ss".encode("US-ASCII")).to_s, r.match("\u017fS").to_s, Regexp.new("(?i:\u00df)").match("ss".encode("US-ASCII")).to_s] }

# named captures do not bind reserved words, unless they are locals already
t(:cap_nil) { /(?<nil>.)/ =~ "a"; local_variables.include?(:nil) }
def cap_kw(s, nil: :ng) = (/(?<nil>.)/ =~ s; binding.local_variable_get(:nil))
t(:cap_kw) { cap_kw("b") }

# an allocated Regexp with no pattern
a = Regexp.allocate
t(:uninit) { [(a == Regexp.allocate rescue $!.class), a == a, a.eql?(a), (a =~ "" rescue $!.class), a === a, ~a, (a.to_s rescue $!.class), a.encoding, a.fixed_encoding?] }
t(:dup_init) { //.dup.instance_eval { initialize_copy(nil) } }

# linear_time? and lookarounds that capture
t(:linear) { [/a/, /(a)\1/, /(?=(a))/, /(?!(a))/, /(?=a)(b)/, /(?<n>x)(?=y)/, /.(?<=(a))/, /x+(?=(a))/].map { |x| Regexp.linear_time?(x) } }
t(:linear_bad) { [(Regexp.linear_time?(nil) rescue $!.class), (Regexp.linear_time?(a) rescue $!.class)] }

# quote keeps an encoding that is not ASCII-compatible
t(:quote16) { q = Regexp.quote("a.b".encode("UTF-16BE")); [q.encoding, q == "a\\.b".encode("UTF-16BE")] }

# \u must be well-formed, in a class too, but not in a comment
t(:u_class) { begin; eval("/[\\users]/x"); :no; rescue SyntaxError; :se; end }
t(:u_comment) { [eval("/ C:\\\\\\\\[a-z]{5} # e.g. C:\\\\users /x").source.size > 0, eval("/f(?# \\\\users)o/") =~ "fo"] }

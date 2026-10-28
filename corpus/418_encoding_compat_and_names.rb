# Strings in an encoding ASCII does not fit, and names in encodings that are
# not UTF-8 (note 444).

def t(name)
  r = begin
        v = yield
        "ok #{v.inspect}"
      rescue Exception => e
        "#{e.class}: #{e.message.sub(/0x\h+/, "0x")}"
      end
  p [name, r]
end

u16 = "a".encode("UTF-16LE")
t(:basename) { File.basename(u16) }
t(:basename_suffix) { File.basename("a/b", u16) }
t(:expand_path) { File.expand_path(u16) }
t(:join) { File.join("a", u16) }
t(:float) { Float(u16) }
t(:float_quiet) { Float(u16, exception: false) }
t(:pack) { [1].pack(u16) }

# File.join answers in its first part's encoding when all of it is ASCII
t(:join_ascii) { File.join("a".force_encoding("US-ASCII"), "b".force_encoding("US-ASCII")).encoding }
t(:join_binary) { File.join("a".b, "b").encoding }
t(:join_none) { File.join.encoding }
t(:join_utf8) { File.join("a", "é").encoding }

# a source string is read in its own encoding
n = "\u{00de}".encode("iso-8859-15")
m = Module.new
t(:module_eval_latin) { m.module_eval("#{n} = 2; #{n}") }
t(:instance_eval_latin) { Object.new.instance_eval("#{n} = 3; #{n}") }

# a constant name is read in its own encoding
e = "\u{391}".encode("euc-jp")
t(:const_set_euc) { m.const_set(e, 4) }
t(:const_get_euc) { m.const_get(e) }
t(:const_defined_euc) { m.const_defined?(e) }
f = "\u{ff21}".encode("cp932")
t(:const_set_cp932) { m.const_set(f, 5) }
t(:not_a_constant) { m.const_set("\u{3042}".encode("euc-jp"), 6) }

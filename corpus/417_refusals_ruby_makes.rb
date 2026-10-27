# Places ruby refuses an input, and what it says (note 443).

def t(name)
  r = begin
        v = yield
        "ok #{v.inspect}"
      rescue Exception => e
        "#{e.class}: #{e.message.sub(/0x\h+/, "0x")}"
      end
  p [name, r]
end

# a builtin reached through send counts its arguments
t(:send_splat) { send(:object_id, *Array.new(200, 1)) }
t(:object_id_arg) { Object.new.object_id(1) }

# a BasicObject has no === for a `when`
bo = Class.new(BasicObject) { }.new
t(:case_basic_object) { case 1; when bo; :hit; end }

# a superclass that is no class, and a reopening with another one
M417 = 1
t(:superclass_const) { eval("class C417 < M417; end") }
m = Module.new
m.module_eval "class K417; end"
t(:superclass_mismatch) { m.module_eval "class K417 < Class.new; end" }

# zero to a negative exact fraction
t(:zero_pow_rational) { 0 ** Rational(-2, 3) }
t(:zero_pow_positive) { 0 ** Rational(2, 3) }

# a NUL in a pattern or a path name
t(:fnmatch_pattern) { File.fnmatch("a\0z", "a") }
t(:fnmatch_path) { File.fnmatch("a", "a\0z") }

# what a KeyError was never given
t(:key_error_key) { KeyError.new.key }
t(:key_error_receiver) { KeyError.new.receiver }
t(:key_error_given) { e = KeyError.new(receiver: 1, key: :k); [e.receiver, e.key] }

# an immediate's absent singleton class takes no undef
t(:undef_on_integer) { 1.instance_eval { undef to_s } }

# a frozen ThreadGroup
t(:frozen_group_add) { g = ThreadGroup.new; g.freeze; g.add(Thread.current) }
t(:frozen_group_new_thread) do
  g = ThreadGroup.new
  r = nil
  Thread.new {
    g.add(Thread.current)
    g.freeze
    r = (Thread.new { 1 }.join rescue $!.class)
  }.join
  r
end

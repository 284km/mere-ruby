# A hash pattern that does not match by a key raises
# NoMatchingPatternKeyError, and the message names the key as Symbol#inspect
# writes it: `:name` for a name ruby writes bare, `:"..."` for any other,
# escaped as a String is.
#
# The message is made when the pattern is compiled. The native ISeq compiler
# made it only for a plain identifier and declined every file with any other
# key (`in {"a-b": x}`), which the Ruby compiler then compiled, at many times
# the cost.
def missing(pattern_source, h = {})
  eval("h => #{pattern_source}; :matched")
rescue NoMatchingPatternKeyError => e
  [e.message, e.key]
end

# bare: identifiers, with `?`, `!` and `=`; a constant's; variables'; the
# operators a method can be named
%w[a _x a1 a? a! a= A A? A= あ nil if].each { |k| p missing("{#{k.inspect}: 1}") }
%w[@a @@a $a $1 $-w].each { |k| p missing("{#{k.inspect}: 1}") }
%w[+ - * / % ** == != === =~ !~ < <= > >= <=> << >> & | ^ ~ ! [] []= +@ -@ `].each { |k| p missing("{#{k.inspect}: 1}") }
# quoted: everything else
["a-b", "a b", "9a", "", "a?b", "a?=", "a!=", "=", "!@", "@", "@1", "@@", "$", "$-", "a.b", "a::b", "[", "&&", "..", "A-"].each { |k| p missing("{#{k.inspect}: 1}") }
# ...and escaped as a String's inspect escapes
["q\"r", "b\\s", "h\#{x}", "h\#$x", "h\#@x", "a#b", "n\nl", "t\tb", "e\e", "c\x01", "d\x7f", "z\0"].each { |k| p missing("{#{k.inspect}: 1}") }

# the first key that is missing is the one named, and the value is shown
p missing('{"a-b": 1, "c d": 2}', {"a-b": 1})
p missing('{ok: 1, "x y": Integer => v}', {ok: 1, "x-y": 2})
p missing('{"a-b": {"c-d": 1}}', {"a-b": {}})

# in a `case`, with no branch taken, the error is the case's own
def pick(h)
  case h
  in {a?: true, "a-b": 1, "_x": x} then [:one, x]
  in {"a b": Integer => y} then [:two, y]
  in {"+": z} then [:three, z]
  end
rescue NoMatchingPatternError => e
  [e.class, e.message]
end
p pick({a?: true, "a-b": 1, _x: 9}), pick({"a b": 2}), pick({"+": 3}), pick({"a b": "s"})

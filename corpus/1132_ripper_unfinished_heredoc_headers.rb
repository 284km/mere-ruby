require 'ripper'
require 'prism'

sources = [
  "foo=1\n<<A+foo\n\#{\n",
  "foo=1\nfoo(<<A+foo)\n\#{[\n",
  "def f(foo); <<A+foo\n\#{\n",
  "<<A+1\n\#{\n",
  "foo(<<A+1)\n\#{\n",
  "<<A+foo\n\#{\n",
  "a=<<A+1\n\#{[\n",
  "<<-A+1\n\#{\n",
  "<<~A+1\n\#{\n"
]
sources.each do |source|
  p Ripper.lex(source).map { |position, event, text, state| [position, event, text, state.to_i] }
end

# Existing heredoc-end state differences are separate from header recovery.
# Check all actual positions/text, including nested and valid heredocs.
controls = [
  "<<A+1\n\#{<<B+2}\n\#{\n",
  "<<A+1\nbody\nA\n",
  "a=<<A+1\n\#{1}\nA\n"
]
controls.each do |source|
  p Ripper.lex(source).map { |position, event, text, _state| [position, event, text] }
end

# The ordinary public Prism stream must retain its original parser tokens,
# diagnostics and locations, independent of Ripper's deferred continuation.
(sources + controls).each do |source|
  result = Prism.lex(source)
  p [result.value.map { |token, state|
    [token.type, token.location.start_offset, token.location.length, token.value, state]
  }, result.errors.map { |error| [error.type, error.location.start_offset, error.location.length] }]
end

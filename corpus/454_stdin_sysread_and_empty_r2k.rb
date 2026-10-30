# An empty Hash flagged by ruby2_keywords, splatted last, is no keywords at
# all -- for a builtin too ([ruby-core:46163] Bug #4040's test).
a = [1, 2]
e = Hash.ruby2_keywords_hash({})
p [].push(*(a + [e]))
p [].push(*(a + [Hash.ruby2_keywords_hash({x: 1})]))
def kw454(*r, **k) = [r, k]
p kw454(*(a + [e]))
p [3].concat(*([[4]] + [e]))

# Standard input has an unbuffered read too: sysread / readpartial.
r, w = IO.pipe
pid = fork do
  w.close
  STDIN.reopen(r)
  out = []
  out << STDIN.sysread(3)
  out << STDIN.readpartial(100)
  begin
    STDIN.sysread(1)
  rescue EOFError => ex
    out << ex.class
  end
  puts out.inspect
  $stdout.flush
  exit!(0)
end
r.close
w.write("hello")
w.close
Process.wait(pid)

# Syntax corners: a return in an eval's BEGIN, a range operator after
# `.[]=` / `.[]` at the end of a line, a rescue modifier on a scoped
# constant's op-assign, an eval'd return in a class body, a byte escape beside
# a \u in a non-UTF-8 source, and a bad byte interpolated into a pattern.

def show(label, pat = nil)
  r = yield
  puts "#{label}: #{r.inspect}"
rescue Exception => e
  puts "#{label}: #{e.class}#{pat ? " #{e.message.match?(pat)}" : ": #{e.message}"}"
end

# `return` in an eval's BEGIN leaves the method, nothing after it run
def begin_return
  eval("BEGIN { return :ok }; raise 'not reached'")
  :no
end
show("BEGIN return") { begin_return }

# `foo.[]= ...` / `foo.[] ...` at the end of a line: the call, then an endless range
show(".[]= ...") { $VERBOSE = nil; r = eval("o = Object.new; def o.[]=(*a); 7; end; o.[]= ...\n"); $VERBOSE = false; r }
show(".[] ...") { $VERBOSE = nil; r = eval("o = Object.new; def o.[](*a); 8; end; o.[] ...\n"); $VERBOSE = false; r }

# the rescue modifier of `v::C op= x rescue y` is the value's
show("::C ||= rescue") { v = Class.new; v::C ||= raise("x") rescue 1; v::C }
show("::C += rescue") { v = Class.new; v.const_set(:C, 1); $VERBOSE = nil; v::C += raise("x") rescue 5; $VERBOSE = false; v::C }

# an eval'd return in a class body: its value is made, then LocalJumpError
$corpus_out = []
class CorpusEvalReturn
  begin
    eval("return $corpus_out << :made")
  rescue LocalJumpError => e
    $corpus_out << e.message
  end
end
show("class eval return") { $corpus_out }
show("return in defined? in a class", /Invalid return/) { eval("class CorpusX; nil&defined?0--begin return end; end") }

# a byte escape past ASCII beside a non-ASCII \u, in a CP932 source
show("mixed escapes", /UTF-8 mixed within Windows-31J source/) { eval("# encoding: cp932\n\"\\xe9\\x9d\\u1234\"") }
show("mixed heredoc", /UTF-8 mixed within Windows-31J source/) { eval("# encoding: cp932\n<<-T\n\\xe9\\x9d\\u1234\nT\n") }
show("ascii escapes") { eval("# encoding: cp932\n\"\\x41\\u1234\"").encoding }

# a string literal interpolated into a UTF-8 pattern is part of its source
show("bad byte in pattern", /invalid multibyte character/) { eval('/#{"\xcd"}/') }

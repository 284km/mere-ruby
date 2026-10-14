# Exceptions at the end of a program as CRuby's test_exception asks them (note
# 341): END and at_exit handlers report what they raise with their own frame
# only, each once, and trap(:EXIT) runs before them, its error reported last; a `return` out of one is
# "unexpected return"; a bare raise keeps the backtrace $@ gave; a report
# survives a message that raises; Exception#exception keeps the backtrace;
# warn needs Warning#warn; $; is a :deprecated warning.
rb = RbConfig.ruby
run = ->(src) {
  out = IO.popen([rb, "-e", src, err: [:child, :out]], &:read)
  [out.lines.map(&:chomp).reject(&:empty?), $?.exitstatus]
}
p run.('Signal.trap(:EXIT) {raise "EXIT"}; END{raise "END1"}; END{raise "END2"}; END{raise "END3"}')
p run.('at_exit {print 1}; Signal.trap(:EXIT, proc {print 2}); at_exit {print 3}')
p run.('END{begin; raise "inner"; rescue; raise "outer"; end}')
p run.('Signal.trap(:EXIT) {begin; raise "inner"; rescue; raise "outer"; end}')
p run.('at_exit { p [:second, $!]; raise "A" }; at_exit { p [:first, $!]; raise "B" }')
p run.('at_exit { raise "A" }; raise "main"')
p run.('END{return}')
p run.('at_exit { exit 5 }; at_exit { return }')
p run.('begin; raise; rescue; $@ = %w(foo bar baz); raise; end')
p run.('class E319 < StandardError; def to_s = raise("boom"); end; raise E319')
p run.('exc = Class.new(StandardError) { def initialize(o, c) = (super(o); @c = c); def to_s = (@c -= 1) >= 0 ? raise("x") : super }.new("ok", 5); raise "outer", cause: exc')
begin; line = __LINE__; raise "foo"; rescue => e; end
e2 = e.exception("bar")
p [e2.message, e.backtrace == e2.backtrace, e2.backtrace_locations[0].lineno == line]
p run.('Warning.undef_method(:warn); begin; warn ""; rescue NoMethodError => e; p e.message; end')
module Warning
  def self.warn(m, category: nil) = (puts "#{m.sub(/\A.*?: /, "")}".chomp + " #{category.inspect}")
end
$VERBOSE = true
Warning[:deprecated] = true
$; = "www"
$; = nil
$VERBOSE = false

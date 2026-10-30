require "tmpdir"

# Without parentheses, defined? takes the whole expression up to `and` /
# `or`: `defined?0--x` is `defined?(0 - -x)`, whose receiver is evaluated
# (an exception there is a nil answer).
x = 1
p(defined? x ? 1 : 2)
p(defined?0--1)
p(nil&defined?0--begin e=no_such_method452(); 0;end)
p [defined? x, 2]
p(defined? x && y)

Dir.mktmpdir do |dir|
  # A BEGIN at a required file's top level runs first, as the main script's
  # does, and a return in it ends the file there.
  File.write(File.join(dir, "begin_return.rb"), "BEGIN { $begin_ran = true; eval \"return\" }\n$after_begin = true\n")
  require File.join(dir, "begin_return.rb")
  p [$begin_ran, $after_begin]

  # A required file that does not parse is a SyntaxError whose message is
  # eval's: the place, prism's frame, and the reason.
  File.write(File.join(dir, "begin_in_class.rb"), "class X452; BEGIN {eval \"return\"}; end\n")
  begin
    require File.join(dir, "begin_in_class.rb")
  rescue SyntaxError => e
    puts e.message.sub(dir, "DIR")
    p e.path == File.join(dir, "begin_in_class.rb")
  end

  # An END block in a class body is the class body's for `return`.
  File.write(File.join(dir, "end_return.rb"), "class Y452; END {return if false}; end\n")
  begin
    require File.join(dir, "end_return.rb")
  rescue SyntaxError => e
    puts e.message.sub(dir, "DIR").lines.first
    puts e.message.include?("Invalid return in class/module body")
  end
end

# ...and eval's report of a class body's return is prism's frame, marked at
# the word.
begin
  eval("class Z452; return; end")
rescue SyntaxError => e
  puts e.message.sub(/\A\(eval at [^)]*\)/, "(eval)")
end

# An exception out of an external enumerator's source: its fiber's bottom
# frame is the source's #each, named with the path above it and no line.
def foo452
  return to_enum(__method__) unless block_given?
  raise "in the source"
  yield 1
end
begin
  foo452.next
rescue => e
  puts e.backtrace.map { |l| l.sub(/\A.*\//, "") }
end

# A `break` out of a fork's block ends the child with "unexpected break"
# (status 1); it does not leave fork and run the parent's code.
error, _, status = IO.pipe do |r, w|
  pid = fork do
    r.close
    STDERR.reopen(w)
    at_exit { $!.class }
    break
  end
  w.close
  [r.read, *Process.wait2(pid)]
end
puts error.sub(/\A.*\//, "")
p status.success?, status.signaled?, status.exitstatus

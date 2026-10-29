# A script that does not parse is reported as ruby reports it: the place and
# "syntax error(s) found" with the class, then prism's frame -- the line and
# a mark under what is wrong (a BEGIN not at the top, with a `return` in it a
# second mark). eval's report names the line the source ends on.

def child(src)
  r, w = IO.pipe
  pid = spawn(RbConfig.ruby, "-W0", "-e", src, err: w, out: File::NULL)
  w.close
  Process.wait(pid)
  [$?.exitstatus, r.read]
end

# (the whole report where one error is all ruby finds)
["class X; BEGIN {}; end", "class X; BEGIN {return}; end", "class X; BEGIN {eval \"return\"}; end"].each do |src|
  st, err = child(src)
  puts "#{src.inspect}: exit #{st}"
  puts err.lines.map { |l| "  " + l }.join
end
# (...and its head, the line and the first mark, where prism finds more)
["x = (1", "p 1 +"].each do |src|
  st, err = child(src)
  puts "#{src.inspect}: exit #{st} #{err.lines.first[/\A-e: -e:\d+: syntax errors? found \(SyntaxError\)/] ? "framed" : err.lines.first.inspect}"
  puts err.lines[1, 2].map { |l| "  " + l }.join
end

begin
  eval("puts 1\nx = [1,\n", nil, "f.rb", 1)
rescue SyntaxError => e
  puts e.message[/\Af\.rb:\d+/]
end

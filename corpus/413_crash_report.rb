# SEGV, BUS and ILL sent to the process itself are ruby's [BUG] (note 437):
# a report on stderr -- the place, the description, the frames, the Ruby
# level backtrace -- or in the file RUBY_CRASH_REPORT names, and then the
# process ends of that signal. Each case runs the same interpreter as a child.
require "rbconfig"
require "tmpdir"
ruby = RbConfig.ruby

out = IO.popen([ruby, "-e", "Process.kill :SEGV, $$"], err: [:child, :out], &:read)
st = $?
puts out.lines[0]
p out.lines[1] == RUBY_DESCRIPTION + "\n"
p out.include?("\n-- Control frame information ---")
puts out[/-- Ruby level backtrace information -+\n(.*?)\n\n/m, 1]
p [st.signaled?, st.termsig == Signal.list["SEGV"]]


%w[BUS ILL].each do |s|
  o = IO.popen([ruby, "-e", "Process.kill :#{s}, $$"], err: [:child, :out], &:read)
  puts o.lines[0][/\A.*\[BUG\] [A-Za-z ]+/]
  p $?.termsig == Signal.list[s]
end

# a report file named from %e (the executable), %f (the script) and %p
Dir.mktmpdir do |d|
  File.write(File.join(d, "bug.rb"), "Process.kill :SEGV, $$\n")
  pid = spawn({ "RUBY_CRASH_REPORT" => "%e.%f.%p.log" }, ruby, "bug.rb", chdir: d, err: File::NULL)
  Process.wait(pid)
  files = Dir.children(d).sort - ["bug.rb"]
  p files == ["#{File.basename(ruby)}.bug.rb.#{pid}.log"]
  puts File.read(File.join(d, files[0])).lines[0] unless files.empty?
end

# trapping one of them is refused
begin
  trap(:SEGV) { }
rescue ArgumentError => e
  puts e.message
end

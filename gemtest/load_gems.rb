# Require each gem named in gems.txt and report which ones load.
#
# Reads the gem tree and the rubygems checkout from the environment so the
# harness carries no paths of its own:
#
#   GEM_HOME=... GEM_PATH=... RUBYGEMS_LIB=... mere-ruby [-I<stdlib>] load_gems.rb
#
# Every failure is reported with its class and message: the point of the
# measurement is that each one is a NAMED gap, not that the count is high.
rubygems_lib = ENV["RUBYGEMS_LIB"]
$LOAD_PATH.unshift(rubygems_lib) if rubygems_lib && !rubygems_lib.empty?
require "rubygems"

list = ENV["GEMLIST"] || File.join(File.dirname(__FILE__), "gems.txt")
ok = 0
bad = 0
File.readlines(list).each do |line|
  g = line.strip
  next if g.empty? || g.start_with?("#")
  begin
    require g
    ok += 1
    puts "OK   #{g}"
  rescue Exception => e
    bad += 1
    puts "FAIL #{g}  #{e.class}: #{e.message.to_s[0, 70]}"
  end
end
puts "TOTAL ok=#{ok} fail=#{bad}"

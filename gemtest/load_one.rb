# Require ONE gem and report how it went. One gem per process: a gem that
# crashes the interpreter (a native signal, not a Ruby exception) must not
# take the rest of the measurement with it -- that is what a gate is for.
#
#   GEM_HOME=... GEM_PATH=... RUBYGEMS_LIB=... mere-ruby [-I<stdlib>] load_one.rb <gem>
rubygems_lib = ENV["RUBYGEMS_LIB"]
$LOAD_PATH.unshift(rubygems_lib) if rubygems_lib && !rubygems_lib.empty?
require "rubygems"

g = ARGV[0].to_s.strip
begin
  require g
  puts "OK   #{g}"
rescue Exception => e
  puts "FAIL #{g}  #{e.class}: #{e.message.to_s[0, 70]}"
end

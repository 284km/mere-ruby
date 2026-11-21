require "rbconfig"
puts "rubyhdrdir_present=#{!RbConfig::CONFIG['rubyhdrdir'].nil?}"
require "mkmf"
puts "mkmf-loaded"

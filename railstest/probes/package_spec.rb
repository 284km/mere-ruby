require "rubygems"
require "rubygems/package"
require "digest"
puts "sha-start"
STDOUT.flush
puts Digest::SHA256.file(ARGV.fetch(0)).hexdigest
puts "sha-done"
puts "spec-start"
STDOUT.flush
spec = Gem::Package.new(ARGV.fetch(0)).spec
puts spec.full_name
puts spec.files.length
puts "spec-done"

# The shipped tmpdir also works without an external Ruby installation.
$LOAD_PATH.clear
require 'tmpdir'
directory = nil
result = Dir.mktmpdir('standalone-tmpdir') do |root|
  directory = root
  Dir.mkdir(File.join(root, 'nested'))
  File.write(File.join(root, 'nested', 'file'), 'contents')
  :block_result
end
raise 'mktmpdir return value' unless result == :block_result
raise 'mktmpdir leaked its contents' if File.exist?(directory)
puts 'standalone tmpdir still creates and cleans up directories'

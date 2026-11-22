# Run each algorithm and entry point in its own bounded process, comparing
# stdout with Ruby 4.0.9. The payload exceeds the provider wire budget.
# Usage: /path/to/ruby unittest/digest_provider_large.rb 256 direct
# Algorithms: 256, 384, 512. Entry points: direct, incremental, file.
# Use the existing 600-second / 2-GiB process-family bounds on each run.
require "digest"
require "openssl"
require "tmpdir"

algorithm = { "256" => Digest::SHA256, "384" => Digest::SHA384,
              "512" => Digest::SHA512 }.fetch(ARGV.fetch(0))
mode = ARGV.fetch(1)
data = ("a" * (64 * 1024 * 1024) + "\0\x80\xff".b).b
result = case mode
         when "direct"
           algorithm.hexdigest(data)
         when "incremental"
           digest = algorithm.new
           digest.update(data.byteslice(0, 37))
           digest.update(data.byteslice(37, data.bytesize - 37))
           digest.hexdigest
         when "file"
           Dir.mktmpdir("digest-large") do |directory|
             path = File.join(directory, "input.bin")
             File.binwrite(path, data)
             algorithm.file(path).hexdigest
           end
         else
           raise ArgumentError, "unknown mode"
         end
puts "#{algorithm.name} #{mode} #{data.bytesize} #{result}"

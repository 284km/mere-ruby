require "bundler/setup"
require "json"
puts JSON.generate({"b" => 2, "a" => 1}, sort_keys: true)
p JSON.parse('{"a":1}')

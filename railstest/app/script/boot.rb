require_relative "../config/environment"
abort "wrong Rails" unless Rails.version == "8.1.4.1"
abort "model not autoloaded" unless Note < ActiveRecord::Base
require "json"
lock = JSON.parse(File.read(ENV.fetch("RAILS_SMOKE_LOCK")))
home = File.realpath(ENV.fetch("RAILS_SMOKE_GEM_HOME"))
lock.fetch("packages").each do |package|
  name = package.fetch("name")
  version = package.fetch("version")
  spec = Gem.loaded_specs.fetch(name)
  abort "wrong gem version: #{name}" unless spec.version.to_s == version
  expected = File.realpath(File.join(home, "gems", "#{name}-#{version}"))
  abort "gem from another runtime: #{name}" unless File.realpath(spec.full_gem_path) == expected
end
puts "locked-gem-sources-ok"
puts "rails-boot-ok"

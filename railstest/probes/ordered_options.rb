require File.expand_path("config/boot", Dir.pwd)
require "active_support/ordered_options"
options = ActiveSupport::OrderedOptions.new
p [:allocated, options.class, options.method(:method_missing).owner]
options.railties_load_path = []
p [:written, options.railties_load_path]
box = { i18n: options }
p [:stored, box[:i18n].class]
puts "ordered-options-ok"

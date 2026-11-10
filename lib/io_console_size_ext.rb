# lib/io_console_size_ext.rb -- ruby's own io/console/size.rb (ruby 4.0.9's
# ext/io/console/lib/console/size.rb; Ruby's license / BSD-2-Clause), unchanged.
# Shipped by tools/gen_pathname_lib.rb as `io/console/size`.
# frozen_string_literal: false
# fallback to console window size
def IO.default_console_size
  [
    ENV["LINES"].to_i.nonzero? || 25,
    ENV["COLUMNS"].to_i.nonzero? || 80,
  ]
end

begin
  require 'io/console'
rescue LoadError
  class << IO
    alias console_size default_console_size
  end
else
  # returns console window size
  def IO.console_size
    console.winsize
  rescue NoMethodError
    default_console_size
  end
end

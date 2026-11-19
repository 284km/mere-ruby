# Keep each interpreter's own libraries and activated gems ahead of fallback.
require "rbconfig"
fallback = ENV.fetch("RAILS_SMOKE_RUBY_LIB")
# RubyGems passes its source directory to extension children through -I.
# That directory is still only our declared reference fallback on Mere.
unless fallback == RbConfig::CONFIG.fetch("rubylibdir")
  $LOAD_PATH.delete(fallback)
  $LOAD_PATH << fallback
end
# RUBYOPT disables automatic RubyGems startup until that order is restored.
# Load the unchanged RubyGems source here for both interpreters and children.
require "rubygems"

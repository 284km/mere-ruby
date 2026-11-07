# frozen_string_literal: true
#
# cgi and cgi/util, as mere-ruby answers `require "cgi"` and `require
# "cgi/util"`: ruby 4.0.9's lib/cgi.rb and lib/cgi/util.rb are each this --
# the escape library plus a warning under $VERBOSE that the rest of the CGI
# library is a gem since 4.0. Shipped through tools/gen_pathname_lib.rb.
require "cgi/escape"
if $VERBOSE
  warn <<-WARNING, uplevel: (defined?(Gem::BUNDLED_GEMS) ? Gem::BUNDLED_GEMS.uplevel : 1)
CGI library is removed from Ruby 4.0. Please use cgi/escape instead for CGI.escape and CGI.unescape features.
If you need to use the full features of CGI library, Please install cgi gem.
  WARNING
end

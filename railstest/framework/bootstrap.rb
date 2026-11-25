# Restore Ruby's normal startup libraries after the common bootstrap has
# established each interpreter's isolated gem home and fallback load path.
# --disable-gems also suppresses these libraries; Action Pack tests their
# actual exception suggestions and highlighted source locations.
require_relative "../bootstrap"
require "bundled_gems"
require "did_you_mean"
require "error_highlight"

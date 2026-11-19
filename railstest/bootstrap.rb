# Keep each interpreter's own libraries and activated gems ahead of fallback.
fallback = ENV.fetch("RAILS_SMOKE_RUBY_LIB")
$LOAD_PATH << fallback unless $LOAD_PATH.include?(fallback)

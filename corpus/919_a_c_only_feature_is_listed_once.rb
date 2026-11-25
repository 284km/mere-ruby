# A library that is a C extension alone in ruby's build is listed in
# $LOADED_FEATURES as that extension and nothing else -- one entry, not the
# extension and a .rb of the same name beside it -- and so is one asked for
# with .so. Asking again by either name loads nothing.
names = %w[etc stringio io/wait io/nonblock fcntl pty rbconfig/sizeof erb/escape]
names.each { |n| p [n, require(n), require(n)] }
count = ->(n) {
  rb = $LOADED_FEATURES.count { |f| f.end_with?("/#{n}.rb") }
  ext = $LOADED_FEATURES.count { |f| f.end_with?("/#{n}.bundle", "/#{n}.so") }
  [n, rb, ext]
}
names.each { |n| p count.(n) }
p require('stringio.so')
p require('etc.so')
p count.('stringio')
p count.('stringio.so')
p $LOAD_PATH.resolve_feature_path('etc')&.first
p $LOAD_PATH.resolve_feature_path('stringio.so')&.first
# ...and its methods are C: no source location
p StringIO.instance_method(:read).source_location
p Etc.method(:getlogin).source_location

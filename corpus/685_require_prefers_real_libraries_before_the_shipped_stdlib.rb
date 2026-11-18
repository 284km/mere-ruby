require 'tmpdir'

Dir.mktmpdir('mere-ruby-source-order') do |directory|
  File.write(File.join(directory, 'base64.rb'), '$gem_source_order = :load_path')
  File.write(File.join(directory, 'logger.rb'), '$gem_source_relative = :relative')
  $LOAD_PATH.unshift(directory)
  begin
    kind, path = $LOAD_PATH.resolve_feature_path('base64')
    p [kind, File.realpath(path) == File.realpath(File.join(directory, 'base64.rb'))]
    p [require('base64'), $gem_source_order]
    p require('base64')
    p $LOADED_FEATURES.any? { |feature| feature == File.realpath(File.join(directory, 'base64.rb')) }
  ensure
    $LOAD_PATH.delete(directory)
  end

  # A relative Ruby file keeps its source even when its name is also shipped.
  File.write(File.join(directory, 'driver.rb'), "require_relative 'logger'\n")
  load File.join(directory, 'driver.rb')
  p $gem_source_relative
  p require(File.join(directory, 'logger.rb'))

  # Non-string load-path entries retain their ordinary path conversion.
  path_entry = Object.new
  path_entry.define_singleton_method(:to_path) { directory }
  $LOAD_PATH.unshift(path_entry)
  begin
    File.write(File.join(directory, 'suite_order_probe.rb'), '$gem_source_object = :converted')
    p [require('suite_order_probe'), $gem_source_object]
  ensure
    $LOAD_PATH.delete(path_entry)
  end
end

# The core API remains usable after the program removes Ruby library paths.
saved_load_path = $LOAD_PATH.dup
begin
  $LOAD_PATH.clear
  p Marshal.load(Marshal.dump([:provided, 1]))
ensure
  $LOAD_PATH.replace(saved_load_path)
end

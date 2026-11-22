# Append the pinned Ruby source fallback after the interpreter's own stdlib.
# Locked gem libraries remain the explicit -I entries before both.
fallback = ENV.fetch('MERE_SUITE_RUBY_LIB')
$LOAD_PATH << fallback unless $LOAD_PATH.include?(fallback)
source_root = File.realpath(ENV.fetch('MERE_SUITE_SOURCE_ROOT'))
record = ENV.fetch('MERE_SUITE_SOURCE_RECORD')

# Registered before the upstream autorunner, so this checks after its tests.
# A passing test summary is insufficient if require selected another library.
at_exit do
  files = $LOADED_FEATURES.map do |feature|
    begin
      path = File.realpath(feature)
      path.delete_prefix(source_root + '/') if path.start_with?(source_root + '/lib/')
    rescue SystemCallError
      nil
    end
  end.compact.uniq.sort
  File.write(record, files.join("\n") + "\n")
  abort 'suite source audit: no library from the locked gem source was loaded' if files.empty?
end

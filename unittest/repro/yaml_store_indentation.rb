require 'yaml/store'
require 'tmpdir'

# Check the real store library, reopening the file rather than reusing its cache.
Dir.mktmpdir('yaml-store-roundtrip') do |directory|
  [2, 3, 4, 9].each do |width|
    path = File.join(directory, "store-#{width}.yml")
    expected = [[nil, {'a' => 1}], {'nested' => [[nil, {'b' => [1, 2]}]]}]
    store = YAML::Store.new(path, true, indentation: width)
    store.transaction { store['data'] = expected }
    reopened = YAML::Store.new(path, true, indentation: width)
    reopened.transaction(true) do
      actual = reopened['data']
      raise 'YAML::Store changed persisted data' unless actual == expected
      p [width, actual]
    end
  end
end

require 'tmpdir'
raise 'tmpdir did not load FileUtils' unless defined?(FileUtils)
names = [:mkdir_p, :mkpath, :makedirs, :rm_rf, :remove_entry, :remove_entry_secure]
original = names.map { |name| FileUtils.method(name).parameters }
require 'fileutils'
current = names.map { |name| FileUtils.method(name).parameters }
raise 'loading FileUtils replaced tmpdir fallbacks' unless current == original
require_relative 'tmpdir_fileutils_contract'

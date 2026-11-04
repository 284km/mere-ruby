require 'fileutils'
names = [:mkdir_p, :mkpath, :makedirs, :rm_rf, :remove_entry, :remove_entry_secure]
original = names.map { |name| FileUtils.method(name).parameters }
require 'tmpdir'
current = names.map { |name| FileUtils.method(name).parameters }
raise 'tmpdir replaced FileUtils methods' unless current == original
require_relative 'tmpdir_fileutils_contract'

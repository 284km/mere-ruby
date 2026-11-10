#!/usr/bin/env ruby
# Restore source packages into a task-owned gem home, never the user's Ruby.
require 'rubygems/package'
require 'json'
require 'digest'
require 'fileutils'
require 'net/http'
require 'optparse'

abort 'reference Ruby4.0.9 is required' unless RUBY_VERSION == '4.0.9'
options = {}
OptionParser.new do |parser|
  parser.on('--inventory PATH') { |value| options[:inventory] = value }
  parser.on('--lock PATH') { |value| options[:lock] = value }
  parser.on('--output PATH') { |value| options[:output] = File.expand_path(value) }
  parser.on('--cache PATH') { |value| options[:cache] = File.expand_path(value) }
  parser.on('--private-archive PATH') { |value| options[:private_archive] = File.expand_path(value) }
end.parse!
abort 'provide --output and either --inventory or --lock' unless options[:output] && (options[:inventory] || options[:lock])
abort 'choose either --inventory or --lock' if options[:inventory] && options[:lock]
abort 'adding a private archive requires regenerating the lock from inventory' if options[:lock] && options[:private_archive]
abort 'use a fresh output directory' if File.exist?(options[:output])
abort 'output must be separate from the current gem home' if File.expand_path(Gem.dir) == options[:output]
root = File.expand_path('..', __dir__)
output = options[:output]
cache = options[:cache] || File.join(File.dirname(output), 'package-cache')
FileUtils.mkdir_p([output, cache, File.join(output,'gems'), File.join(output,'specifications')])
requested = File.readlines(File.join(root,'gemtest/gems.txt'),chomp:true).reject { |line| line.empty? || line.start_with?('#') }
lock = options[:lock] && JSON.parse(File.read(options[:lock]))
inventory = options[:inventory] && JSON.parse(File.read(options[:inventory])).fetch('gemspec_sha256')
def source_tree_digest(folder)
  digest=Digest::SHA256.new
  Dir.glob(File.join(folder,'**','*'),File::FNM_DOTMATCH).sort.each do |file|
    relative=file.delete_prefix(folder+'/')
    next if ['.','..'].include?(File.basename(relative))
    if File.symlink?(file)
      digest.update("L\0"+relative+"\0"+File.readlink(file)+"\0")
    elsif File.file?(file)
      digest.update("F\0"+relative+"\0"+Digest::SHA256.file(file).hexdigest+"\0")
    end
  end
  digest.hexdigest
end

packages = []
unavailable = []
missing_dependencies = []
queue = []
seen = {}

candidates = lambda do |name, requirement|
  result = inventory.keys.filter_map do |filename|
    prefix = name + '-'
    next unless filename.start_with?(prefix)
    rest = filename.delete_prefix(prefix).delete_suffix('.gemspec')
    version_text, platform_text = rest.split(/-(?=[A-Za-z])/,2)
    next unless Gem::Version.correct?(version_text)
    version = Gem::Version.new(version_text)
    next unless requirement.satisfied_by?(version)
    platform = platform_text ? Gem::Platform.new(platform_text) : Gem::Platform::RUBY
    next unless platform == Gem::Platform::RUBY || platform === Gem::Platform.local
    {'name'=>name,'version'=>version.to_s,'file'=>filename.delete_suffix('.gemspec')+'.gem','origin'=>'original installed-version inventory'}
  end
  if result.empty?
    spec = Gem::Specification.find_all_by_name(name,requirement).select { |spec| spec.default_gem? || spec.full_gem_path.start_with?(File.join(Gem.default_dir,'gems')+'/') }.max_by(&:version)
    result << {'name'=>name,'version'=>spec.version.to_s,'file'=>spec.file_name,'origin'=>'pinned Ruby4.0.9 default gem'} if spec
  end
  result.sort_by { |item| [Gem::Version.new(item.fetch('version')),item.fetch('file')] }.reverse
end

if lock
  abort 'snapshot format/reference changed' unless lock.fetch('format') == 1 && lock.fetch('reference_ruby') == '4.0.9'
  abort 'requested gem list changed' unless lock.fetch('requested') == requested
  queue = lock.fetch('packages').dup
  unavailable = lock.fetch('unavailable').dup
else
  stdlib = Gem::Specification.select { |spec| spec.default_gem? || spec.full_gem_path.start_with?(File.join(Gem.default_dir,'gems')+'/') }.map(&:name).uniq.sort
  supplemental = stdlib - requested
  (requested + supplemental).each do |name|
    matches = candidates.call(name,Gem::Requirement.default)
    if matches.empty?
      unavailable << {'name'=>name,'reason'=>'not in source inventory'}
    else
      # Match RubyGems' highest installed root version; dependency versions below
      # are retained when their constraints select them.
      queue << matches.first
    end
  end
end

until queue.empty?
  item = queue.shift
  filename = item.fetch('file')
  abort 'invalid package filename' unless /\A[A-Za-z0-9_.-]+\.gem\z/.match?(filename)
  next if seen[filename]
  seen[filename] = true
  path = File.join(cache,filename)
  if item.fetch('name') == 'sidekiq-pro'
    if options[:private_archive] && File.basename(options[:private_archive]) == filename
      FileUtils.cp(options[:private_archive],path) unless File.expand_path(options[:private_archive]) == path
    end
    unless File.file?(path)
      unavailable << item.merge('reason'=>'private archive not provided; no replacement package installed')
      next
    end
  elsif !File.file?(path)
    uri = URI('https://rubygems.org/gems/'+filename)
    response = Net::HTTP.start(uri.host,uri.port,nil,use_ssl:true,open_timeout:15,read_timeout:60) { |http| http.get(uri.request_uri) }
    abort "locked package unavailable: #{filename}" if lock && response.code == '404'
    if response.code == '404'
      unavailable << item.merge('reason'=>'pinned public archive returned404')
      next
    end
    abort "package download failed: #{filename} HTTP #{response.code}" unless response.code == '200'
    File.binwrite(path+'.part',response.body)
    File.rename(path+'.part',path)
  end
  sha = Digest::SHA256.file(path).hexdigest
  abort "package digest changed: #{filename}" if item['sha256'] && item['sha256'] != sha
  package = Gem::Package.new(path)
  package.verify
  spec = package.spec
  abort "package identity changed: #{filename}" unless spec.name == item.fetch('name') && spec.version.to_s == item.fetch('version') && spec.file_name == filename
  folder=File.join(output,'gems',spec.full_name)
  package.extract_files(folder)
  tree=source_tree_digest(folder)
  abort "source tree changed: #{filename}" if item['source_tree_sha256'] && item['source_tree_sha256'] != tree
  File.write(File.join(output,'specifications',spec.full_name+'.gemspec'),spec.to_ruby_for_cache)
  entry = item.merge('sha256'=>sha,'source_tree_sha256'=>tree,'native_extensions'=>spec.extensions,'dependencies'=>spec.runtime_dependencies.map { |dependency| {'name'=>dependency.name,'requirement'=>dependency.requirement.to_s} })
  packages << entry
  puts "restored #{filename}"
  unless lock
    spec.runtime_dependencies.sort_by(&:name).each do |dependency|
      matches = candidates.call(dependency.name,dependency.requirement)
      if matches.empty?
        missing_dependencies << {'name'=>dependency.name,'requirement'=>dependency.requirement.to_s,'requested_by'=>spec.full_name}
      else
        # Keep every originally installed candidate satisfying this edge, so
        # independent root processes can resolve different historical versions.
        queue.concat(matches)
      end
    end
  end
end
report = {'format'=>1,'reference_ruby'=>'4.0.9','requested'=>requested,'packages'=>packages.sort_by { |item| item.fetch('file') },
          'supplemental_stdlib_roots'=>(lock ? lock.fetch('supplemental_stdlib_roots',[]) : supplemental),'unavailable'=>unavailable.uniq,'missing_dependencies'=>missing_dependencies.uniq,
          'native_extension_policy'=>'Source packages are restored without rebuilding native extensions, matching the previous load-only measurement boundary. This does not claim native extension functionality.'}
File.write(File.join(output,'snapshot.lock.json'),JSON.pretty_generate(report)+"\n")
abort 'no source packages restored' if packages.empty?
puts "snapshot complete: #{packages.size} packages, #{unavailable.size} unavailable roots/packages, #{missing_dependencies.size} missing dependency constraints"

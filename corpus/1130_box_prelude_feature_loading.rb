require 'tmpdir'

Dir.mktmpdir('prelude1130') do |directory|
  {
    'rubygems.rb' => "module Gem; BOOT1130 = :rubygems; end\n",
    'bundled_gems.rb' => "raise 'bundled before rubygems' unless defined?(Gem::BOOT1130); module BundledPrelude1130; VALUE = :bundled_gems; end\n",
    'error_highlight.rb' => "raise 'highlight before bundled' if defined?(Gem::BOOT1130) && !defined?(BundledPrelude1130::VALUE); module ErrorHighlight; BOOT1130 = :error_highlight; end\n"
  }.each { |file, source| File.write(File.join(directory, file), source) }
  observer = File.join(directory, 'observer.rb')
  File.write(observer, "p [:preload, %w[rubygems.rb bundled_gems.rb error_highlight.rb].map { |name| $LOADED_FEATURES.any? { |file| File.basename(file) == name } }]\n")
  program = <<~'RUBY'
    features = -> { %w[rubygems.rb bundled_gems.rb error_highlight.rb].map { |name| $LOADED_FEATURES.any? { |file| File.basename(file) == name } } }
    bodies = -> { [defined?(Gem::BOOT1130) && Gem::BOOT1130, defined?(BundledPrelude1130::VALUE) && BundledPrelude1130::VALUE, defined?(ErrorHighlight::BOOT1130) && ErrorHighlight::BOOT1130] }
    p [:before, features.call, bodies.call]
    require 'error_highlight'
    p [:after, features.call, bodies.call]
    box = Ruby::Box.new
    p [:box, box.eval('[defined?(Gem::BOOT1130) && Gem::BOOT1130, defined?(BundledPrelude1130::VALUE) && BundledPrelude1130::VALUE, defined?(ErrorHighlight::BOOT1130) && ErrorHighlight::BOOT1130]'), box.eval('%w[rubygems.rb bundled_gems.rb error_highlight.rb].map { |name| $LOADED_FEATURES.any? { |file| File.basename(file) == name } }')]
  RUBY
  [
    %w[--enable=gems],
    %w[--disable=gems],
    %w[--enable=gems --disable=error_highlight],
    %w[--enable=gems --disable=error_highlight --enable=error_highlight],
    %w[--disable=gems --enable=error_highlight]
  ].each_with_index do |flags, index|
    error_file = File.join(directory, "child-#{index}.err")
    env = {'RUBY_BOX' => '1', 'RUBYLIB' => directory, 'BUNDLER_SETUP' => nil, 'MERE_RUBY_NO_GEMS' => nil}
    output = IO.popen([env, RbConfig.ruby, '--disable=did_you_mean,syntax_suggest', *flags, '-W1', '-r', observer, '-e', program, err: error_file], &:read)
    status = $?.exitstatus
    errors = File.binread(error_file).lines.map do |line|
      line.include?('warning: Ruby::Box is experimental,') ? line.sub(/\A.*?: warning:/, '<binary>: warning:') : line
    end
    p [flags, output, errors, status]
  end
end

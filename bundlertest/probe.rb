# One line per step, so the harness can compare step by step rather than
# diffing a blob: a step that stops agreeing is a regression, and the step that
# is expected to diverge is named in run.sh rather than hidden in a diff.
require "rubygems"
require "bundler"
puts "versions=#{[Gem::VERSION, Bundler::VERSION].inspect}"
gemfile = File.join(File.dirname(File.expand_path(__FILE__)), "Gemfile.fixture")
ENV["BUNDLE_GEMFILE"] = gemfile
def step(name)
  puts "#{name}=#{yield.inspect}"
rescue Exception => e
  puts "#{name}=FAIL #{e.class}"
end
step("dsl") { Bundler::Dsl.evaluate(gemfile, nil, {}).dependencies.map {|d| d.name } }
step("definition") { Bundler.definition.dependencies.map {|d| d.name } }
step("setup") { Bundler.setup; :ok }

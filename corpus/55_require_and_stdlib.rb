# `require` is a method, so a library can replace it — which is exactly how
# RubyGems activates a gem when a file is not on the load path.

module Kernel
  alias_method :orig_require, :require
  def require(path)
    $seen << path
    orig_require(path)
  end
end
$seen = []
require "set"
require "set"
p $seen
p Set.new([1, 2]).include?(1)

# LoadError carries the path it could not load
begin
  require "definitely-not-a-real-file-xyz"
rescue LoadError => e
  p e.class, e.message, e.path
end
begin
  raise LoadError, "some other message"
rescue LoadError => e
  p e.path
end

# `@@x ||= v` defines the class variable; every other read of an undefined one
# is a NameError
class Memo
  def self.cache; @@cache ||= []; end
  def self.bump; @@n ||= 0; @@n += 1; end
end
p Memo.cache, Memo.cache.equal?(Memo.cache)
p Memo.bump, Memo.bump
class Cold
  def self.get; @@never + 1; end
end
begin; Cold.get; rescue NameError => e; puts "NameError: #{e.message}"; end

# File.path / expand_path normalisation / realpath
p File.path("a/b")
p File.expand_path("/a//b/../c")
p File.expand_path("x", "/base"), File.expand_path("../x", "/base/sub")
p File.expand_path("~") == ENV["HOME"], File.expand_path("~/x") == ENV["HOME"] + "/x"
p File.expand_path("/")
p File.realpath("/tmp").class
begin; File.realpath("/nope-xyz-123"); rescue StandardError => e; p e.class.to_s.start_with?("Errno"); end

# Set ships as source
s = Set.new([1, 2, 3])
p s.size, s.include?(2), s.to_a.sort, s.add?(3), s.add?(4).class
p(Set[1, 2] == Set[2, 1], (Set[1, 2] | Set[2, 3]).to_a.sort)
p((Set[1, 2] & Set[2, 3]).to_a, (Set[1, 2] - Set[2]).to_a)
p Set[1, 2].subset?(Set[1, 2, 3]), Set[1, 2, 3].superset?(Set[1, 2])
p Set[3, 1, 2].sort, Set[1, 2, 3].map { |x| x * 2 }.sort
p [1, 1, 2].to_set.size, Set[1, 2].inspect

# a nested `module` is a Module, not a Class
module Outer
  module Inner; end
  class Klass; end
end
p Outer.class, Outer::Inner.class, Outer::Klass.class
p Outer.const_get(:Inner).class

# const_get fires a pending autoload
File.write("/tmp/mrb_corpus_autoloaded.rb", "module Holder; Loaded = :yes; end\n")
module Holder
end
Object.autoload :Holder2, "/tmp/mrb_corpus_autoloaded.rb"
p Object.const_get(:Holder).name

# a constant assigned inside a class/module body belongs to that namespace
# even when the assignment is nested in a conditional or a block
module Scoped
  if true
    FromIf = 1
  end
  unless false
    FromUnless = 2
  end
  [1].each do
    FromBlock = 3
  end
  Direct = 4
  class Inner
    if true
      Nested = 5
    end
  end
end
p Scoped::FromIf, Scoped::FromUnless, Scoped::FromBlock, Scoped::Direct
p Scoped::Inner::Nested
p defined?(FromIf), defined?(Nested)
p Scoped.constants.sort

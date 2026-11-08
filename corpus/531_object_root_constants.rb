# Object owns both top-level constants and constants assigned in its body.
module RootConfig
  CONFIG = {"marker" => :root}
end
ROOT_ORDER = :root
class Object
  BODY_ORDER = :object_body
end
module RootMixin
  ROOT_ORDER = :included
  BODY_ORDER = :included
  ONLY_INCLUDED = :included_only
  module RootConfig
    CONFIG = {"marker" => :included}
  end
end
include RootMixin
module RootReader
  def self.read = [ROOT_ORDER, BODY_ORDER, ONLY_INCLUDED]
  def self.config = RootConfig
  def self.reset
    RootConfig.module_eval do
      remove_const(:CONFIG)
      const_set(:CONFIG, {"marker" => :reset})
    end
  end
end
p [ROOT_ORDER, BODY_ORDER, ONLY_INCLUDED]
p RootReader.read
p [RootReader.config.equal?(::RootConfig), RootReader.config.equal?(RootMixin::RootConfig)]
RootReader.reset
p [::RootConfig::CONFIG["marker"], RootMixin::RootConfig::CONFIG["marker"]]

# Lexical and superclass constants still precede Object's fallback.
module LexicalReader
  ROOT_ORDER = :lexical
  class Nested
    def self.read = ROOT_ORDER
  end
end
class RootBase
  ROOT_ORDER = :superclass
end
class RootChild < RootBase
  def self.read = ROOT_ORDER
end
class RootFallback
  def self.read = ROOT_ORDER
end
p [LexicalReader::Nested.read, RootChild.read, RootFallback.read]

# Qualified class lookup can still read an unshadowed mixin constant.
p [RootFallback::ONLY_INCLUDED, Object::ROOT_ORDER, ::ROOT_ORDER]
ROOT_ONLY = :top_only
begin
  RootFallback::ROOT_ONLY
rescue NameError => e
  p e.class
end
class RootIsolated < BasicObject
  def self.read = ROOT_ONLY
end
begin
  RootIsolated.read
rescue NameError => e
  p e.class
end

# Repeated reads must reflect removal/redefinition rather than cached owners.
Object.send(:remove_const, :ROOT_ORDER)
p RootReader.read
Object.const_set(:ROOT_ORDER, :restored)
p RootReader.read

# Missing constants still go to the lexical module's hook.
module RootMissing
  def self.const_missing(name) = [:missing, name]
  def self.read = ROOT_ABSENT
end
p RootMissing.read

# A lexical autoload is still checked before Object's fallback.
path = File.expand_path(__FILE__ + ".autoload.rb")
begin
  File.write(path, "module RootAutoload; ROOT_ORDER = :autoload; end\n")
  module RootAutoload
    def self.read = ROOT_ORDER
  end
  RootAutoload.autoload(:ROOT_ORDER, path)
  p RootAutoload.read
ensure
  File.unlink(path) if File.exist?(path)
end

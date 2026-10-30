# After sweep469: a glob segment written without magic answers as the
# filesystem spells it (where names are case-insensitive), the unused-block
# warning's rules for super and for duck typing, and Array/Hash#inspect in
# default_internal's encoding.

require "tmpdir"

Dir.mktmpdir do |d|
  Dir.chdir(d) do
    Dir.mkdir("SubDir")
    File.write("FileWithCases", "")
    File.write("SubDir/Inner.rb", "")
    if File.exist?("filewithcases")
      p Dir.glob("filewithcases"), Dir.glob("subdir/inner.rb"), Dir["subdir"]
    else
      p ["FileWithCases"], ["SubDir/Inner.rb"], ["SubDir"]
    end
    p Dir.glob("subdir/*.rb"), Dir.glob("nothere")
  end
end

warns = []
Warning.singleton_class.class_eval do
  alias_method :__c446_warn, :warn
  define_method(:warn) { |msg, **| warns << msg[/'([^']+)'/, 1] }
end
$VERBOSE = true
class C446a
  def f1 = nil
  def f4 = nil
  def f5 = nil
  def f6 = nil
end
class C446b < C446a
  def f1 = super
  def f4 = super(&nil)
  def f5 = super(){}
  def f6 = super{}
end
C446b.new.f1 {}
C446b.new.f4 {}
C446b.new.f5 {}
C446b.new.f6 {}
class D446a; def g = yield; end
class D446b < D446a; def g = nil; end
D446b.new.g {}
$VERBOSE = false
Warning.singleton_class.class_eval { alias_method :warn, :__c446_warn }
p warns

s = "\xB4\xC1".force_encoding("EUC-JP")
$VERBOSE = nil
Encoding.default_internal = "EUC-JP"
p [s].inspect.encoding, [1].inspect.encoding, {s => 1}.inspect.encoding, [:a, s].inspect.encoding
p [s].inspect == "[\"\xB4\xC1\"]".force_encoding("EUC-JP")
Encoding.default_internal = nil

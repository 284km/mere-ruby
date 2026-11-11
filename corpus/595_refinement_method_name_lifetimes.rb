class NameFilterTarget
  def marker; :base; end
end
NameFilterRefinery = Module.new do
  refine NameFilterTarget do
    def marker; :refined; end
  end
end
using NameFilterRefinery
target = NameFilterTarget.new
p target.marker
GC.start
NameFilterRefinery.module_eval do
  refine NameFilterTarget do
    def added_later; :late; end
    alias copied_later added_later
    undef_method :marker
  end
end
GC.start
p [target.added_later, target.copied_later]
begin
  target.marker
rescue NoMethodError
  puts :undefined_refinement
end

module NativeAliasRefinery
  refine String do
    alias_method :native_length, :size
  end
end
using NativeAliasRefinery
GC.start
p 'abc'.native_length

module LateMethodRefinery
  refine String do
    def unrelated_name; :unrelated; end
  end
end
using LateMethodRefinery
bound = Object.new.method(:to_s)
p bound.unbind.class
LateMethodRefinery.module_eval do
  refine Method do
    def unbind; :late_unbind; end
  end
end
using LateMethodRefinery
GC.start
p bound.unbind

# Case dispatch calls Ruby singleton equality and native super in real order.
class CaseAlways
  def self.===(value); :matched; end
end
object = Object.new
p [:override, CaseAlways === object, case object; when CaseAlways; :matched; else; :missed; end]
p [:splat, case object; when *[CaseAlways]; :matched; else; :missed; end]
class CaseNever
  def self.===(value); nil; end
end
p [:nil_override, case CaseNever.new; when CaseNever; :wrong; else; :missed; end]
class CaseSuper
  def self.===(value); super; end
end
p [:native_super, CaseSuper === CaseSuper.new, CaseSuper === object]
p [:native_case, case CaseSuper.new; when CaseSuper; :matched; else; :missed; end]
class CaseInherited < CaseAlways; end
p [:inherited, case object; when CaseInherited; :matched; else; :missed; end]
class WrappedCaseTime; end
class << Time
  def ===(value); super || value.is_a?(WrappedCaseTime); end
end
[Time.at(0), WrappedCaseTime.new, Object.new].each do |value|
  p [:time, Time === value, case value; when Time; true; else; false; end]
end
module CaseModule
  def self.===(value); super; end
end
class CaseIncluded; include CaseModule; end
p [:module, CaseModule === CaseIncluded.new, case CaseIncluded.new; when CaseModule; true; else; false; end]
# The metaclass object does not inherit its instance's singleton override.
p [:metaclass, case CaseAlways; when CaseAlways.singleton_class; true; else; false; end]
class CasePrivate
  def self.===(value); true; end
  private_class_method :===
end
p [:private, case object; when CasePrivate; :matched; else; :missed; end]
class CaseUndefined
  class << self; undef_method :===; end
end
begin
  case object; when CaseUndefined; :wrong; end
rescue => error
  p [:undefined, error.class]
end
# Replacing Module's own native entry sends super above Module to equality.
class Module
  alias_method :saved_native_module_case, :===
  def ===(value); super; end
end
p [:module_replaced, case CaseSuper.new; when CaseSuper; true; else; false; end]
p [:module_identity, case CaseSuper; when CaseSuper; true; else; false; end]
class Module
  alias_method :===, :saved_native_module_case
end
p [:module_restored, case CaseSuper.new; when CaseSuper; true; else; false; end]

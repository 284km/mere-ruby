# Super resumes at its selected native comparator after Module prepends.
class PrependedCaseSubject; end
saved_native = Module.instance_method(:===)

module ForwardModuleCase
  def ===(value)
    super
  end
end
Module.prepend(ForwardModuleCase)

subject = PrependedCaseSubject.new
p [:direct, PrependedCaseSubject === subject, PrependedCaseSubject === Object.new]
p [:case, case subject; when PrependedCaseSubject; true; else; false; end]
p [:array, Array === [], Array === 1]
p [:module, Module === Module.new, Module === Class.new]
p [:saved_native, saved_native.bind(PrependedCaseSubject).call(subject)]

module AnotherForwardModuleCase
  def ===(value)
    super
  end
end
Module.prepend(AnotherForwardModuleCase)
p [:two_wrappers, PrependedCaseSubject === subject, PrependedCaseSubject === nil]

Module.define_method(:===, Kernel.instance_method(:===))
p [:rebound_under_wrappers, PrependedCaseSubject === PrependedCaseSubject,
   PrependedCaseSubject === subject]
Module.define_method(:===, saved_native)
p [:restored_under_wrappers, PrependedCaseSubject === subject]

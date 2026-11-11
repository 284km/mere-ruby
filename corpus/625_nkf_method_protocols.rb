require 'nkf'
class NkfMethods
  include NKF
  alias converted nkf
  public :converted
  def implicit
    nkf('-w', 'あ') { raise 'unused block' }
  end
end
object = NkfMethods.new
p [object.respond_to?(:nkf), object.respond_to?(:nkf, true), object.respond_to?(:converted)]
p [object.implicit, object.converted('-w', 'あ'), object.send(:nkf, '-w', 'あ')]
begin
  object.nkf('-w', 'あ')
rescue NoMethodError => error
  p [error.class, error.name, error.receiver.equal?(object)]
end
p NKF.instance_method(:nkf).bind_call(object, '-w', 'あ')
extended = Object.new.extend(NKF)
p [extended.respond_to?(:nkf), extended.respond_to?(:nkf, true)]
p extended.send(:nkf, '-w', 'あ')
p NKF.instance_method(:nkf).bind_call(extended, '-w', 'あ')
class << NKF
  alias converted nkf
end
p NKF.converted('-w', 'あ')
p [NKF.method(:converted).arity, NKF.method(:converted).parameters, NKF.method(:converted).source_location]
[NKF.dup, NKF.clone].each do |copy|
  p copy.singleton_methods(false).sort
  p copy.private_instance_methods(false).sort
  p [copy.nkf('-w', 'あ'), copy.method(:nkf).arity, copy.method(:nkf).parameters,
     copy.method(:nkf).owner.equal?(copy.singleton_class)]
  p Object.new.extend(copy).send(:nkf, '-w', 'あ')
  GC.start
  p copy.nkf('-w', 'あ')
end

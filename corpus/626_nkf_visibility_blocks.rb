require 'nkf'
class NkfPrivate
  include NKF
  def self_call
    self.nkf('-w', 'あ') { raise 'unused' }
  end
end
object = NkfPrivate.new
block = proc { raise 'unused' }
begin
  object.nkf('-w', 'あ') { raise 'unused' }
rescue NoMethodError => error
  p [error.class, error.name, error.receiver.equal?(object)]
end
begin
  object.nkf('-w', 'あ', &block)
rescue NoMethodError => error
  p [error.class, error.name, error.receiver.equal?(object)]
end
p object.self_call
NKF.private_class_method(:nkf)
p [NKF.respond_to?(:nkf), NKF.respond_to?(:nkf, true)]
begin
  NKF.nkf('-w', 'あ')
rescue NoMethodError => error
  p [error.class, error.name, error.receiver.equal?(NKF)]
end
begin
  NKF.nkf('-w', 'あ') { raise 'unused' }
rescue NoMethodError => error
  p [error.class, error.name, error.receiver.equal?(NKF)]
end
p NKF.send(:nkf, '-w', 'あ')
NKF.public_class_method(:nkf)
p NKF.nkf('-w', 'あ') { raise 'unused' }

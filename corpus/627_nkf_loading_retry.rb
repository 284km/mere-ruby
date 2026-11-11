# C extension initialization reuses an existing module, including an anonymous
# module assigned to the public constant. A failed init must be retried.
NKF = Module.new
original = NKF
class << NKF
  def const_added(name)
    raise 'nkf initialization interrupted' if name == :EUC
  end
end
begin
  require 'nkf'
rescue => error
  p [error.class, error.message]
end
p $LOADED_FEATURES.grep(/nkf/).map { |path| File.basename(path) }
p NKF.equal?(original)
p NKF.nkf('-w', 'あ')
class << NKF
  remove_method :const_added
end
$VERBOSE = nil
p require('nkf')
p NKF.constants(false).sort
p [NKF.nkf('-w', 'あ'), NKF.guess('あ').name]
p [NKF.method(:nkf).arity, NKF.method(:nkf).parameters, NKF.method(:nkf).owner.equal?(NKF.singleton_class)]
p [require('nkf.so'), require('nkf.rb'), require('nkf')]

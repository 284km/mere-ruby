module NKF; end
frozen_module = NKF.freeze
begin
  require 'nkf'
rescue FrozenError => error
  p [error.class, error.receiver.equal?(frozen_module)]
end
p $LOADED_FEATURES.grep(/nkf/).empty?
Object.send(:remove_const, :NKF)
NKF = Module.new
p require('nkf')
p NKF.nkf('-w', 'あ')
p [NKF::UTF8.equal?(Encoding::UTF_8), require('nkf.so')]

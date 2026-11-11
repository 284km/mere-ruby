$nkf_added = []
module NKF
  def self.method_added(name)
    $nkf_added << [:instance, name, private_method_defined?(name), respond_to?(name)]
  end
  def self.singleton_method_added(name)
    if [:nkf, :guess].include?(name)
      $nkf_added << [:singleton, name, private_method_defined?(name), respond_to?(name)]
    end
  end
end
require 'nkf'
p $nkf_added
original = NKF.method(:nkf)
class << NKF
  alias original_nkf nkf
  def nkf(*arguments)
    :overridden
  end
end
p NKF.nkf('-w', 'あ')
p original.call('-w', 'あ')
p NKF.original_nkf('-w', 'あ')
p [original.arity, original.parameters, original.source_location]
unbound = NKF.instance_method(:nkf)
module NKF
  def nkf(*arguments)
    :instance_overridden
  end
end
p [unbound.arity, unbound.parameters, unbound.source_location, unbound.owner.equal?(NKF)]
p unbound.bind_call(Object.new, '-w', 'あ')
bound = unbound.bind(Object.new)
p [bound.arity, bound.parameters, bound.source_location, bound.call('-w', 'あ')]

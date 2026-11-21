# Existing native-alias reflection gap: reference true, main/candidate false.
module AliasPredicateControl
  define_method(:native_identity, Kernel.instance_method(:itself))
end
p AliasPredicateControl.method_defined?(:native_identity)

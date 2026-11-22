# Existing native alias metadata/dispatch gap; diagnostic for issue #133.
# The reference prints true and false. The previous main and the Range
# parent already fail with unknown operator: ===. Keep this control visible
# independently of the two class-case review regressions fixed in corpus 743.
class Module
  define_method(:===, Kernel.instance_method(:===))
  alias saved_rebound_kernel_case ===
end
class KernelComparatorAliasReceiver
end
p KernelComparatorAliasReceiver.saved_rebound_kernel_case(KernelComparatorAliasReceiver)
p KernelComparatorAliasReceiver.saved_rebound_kernel_case(KernelComparatorAliasReceiver.new)

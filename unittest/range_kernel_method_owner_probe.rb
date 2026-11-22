# Existing Method binding loses Kernel's native === owner on a Range receiver.
range = (1..3)
native = Kernel.instance_method(:===)
p [:kernel_method, native.bind_call(range, 2), native.bind_call(range, range)]

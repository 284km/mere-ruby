# The stage 3 tail: RUBY_THREAD_VM_STACK_SIZE is read as vm.c's get_param
# reads it (atol, the 16 KB minimum, 4 KB rounding) and RubyVM::DEFAULT_PARAMS
# reports it; a smaller size recurses less deep and a larger one deeper.
require "rbconfig"
p RubyVM::DEFAULT_PARAMS[:thread_vm_stack_size]
p RubyVM::DEFAULT_PARAMS[:thread_machine_stack_size] > 0
def depth(size)
  env = size ? { "RUBY_THREAD_VM_STACK_SIZE" => size.to_s } : {}
  out = IO.popen([env, RbConfig.ruby, "-e", 'def rec; print "."; $stdout.flush; rec; end; rec'], err: File::NULL, &:read)
  out.size
end
def param(size)
  IO.popen([{ "RUBY_THREAD_VM_STACK_SIZE" => size }, RbConfig.ruby, "-e", "p RubyVM::DEFAULT_PARAMS[:thread_vm_stack_size]"], &:read).chomp
end
d0, dd, dl = depth(0), depth(nil), depth(10 * 1024 * 1024)
p [d0 < dd, dd < dl]
p %w[0 100 16385 20000 1048576 abc].map { |s| param(s) }

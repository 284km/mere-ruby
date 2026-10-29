# `break` in a block passed on with `&` leaves the method that was given the
# block, whatever runs it: a builtin, class_eval / instance_eval, Module.new,
# another method's yield. A block that is no forwarded proc keeps ending only
# the call it was written on.

def via_each(&b); [1].map { [2].each(&b); :no }; end
p via_each { break 5 }

def via_instance_eval(&b); Object.new.instance_eval(&b); :no; end
p via_instance_eval { break 6 }

def via_module_new(&b); Module.new { class_eval(&b) }; :no; end
p via_module_new { break 7 }

def via_nested(&b); [1].each { Module.new.class_eval(&b) }; :no; end
p via_nested { break 8 }

def via_yield_method(&b); inner(&b); :no; end
def inner; yield; :inner; end
p via_yield_method { break 9 }

# (EnvUtil.labeled_module's shape: `break refine ...` handed out of class_eval)
def labeled(&block)
  Module.new do
    class_eval(&block) if block
  end
end
r = labeled { break :refined }
p r

# a plain block's break still ends just its own call
p [1, 2, 3].each { |x| break x * 10 if x == 2 }
def plain; [1].each { break :inner_only }; :after; end
p plain

# ensure blocks on the way out run
def with_ensure(&b)
  [1].each(&b)
  :no
ensure
  puts "ensure ran"
end
p with_ensure { break :out }

# a method called again afterwards is unaffected
p via_each { |x| x + 1 }

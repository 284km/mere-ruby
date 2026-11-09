$inside_finalizer = $nested_finalizer = false
def exit_inner_finalizer
  proc { $nested_finalizer ||= $inside_finalizer }
end
def exit_outer_finalizer
  proc do
    $inside_finalizer = true
    Fiber.new do
      100.times { ObjectSpace.define_finalizer(Object.new, exit_inner_finalizer) }
    end.resume
    3.times { GC.start }
    p [:exit_not_reentrant, !$nested_finalizer]
    $inside_finalizer = false
  end
end
$kept_until_exit = Object.new
ObjectSpace.define_finalizer($kept_until_exit, exit_outer_finalizer)

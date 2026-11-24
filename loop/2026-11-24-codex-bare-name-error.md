# Bare missing names on module and class receivers

The branch starts from main `b7fe86e104a9a68ff47a3e0598e14f9177eab3e8`,
after the Ruby 4.0.10 reference update. The reference remains Ruby 4.0.10.

A bare `nope_xyz` in a module's singleton method reached the explicit-receiver
primitive failure path. It raised NoMethodError with `undefined method` where
Ruby raises NameError with `undefined local variable or method`. Class methods
had the same problem; ordinary instance methods already distinguished them.

The bare class/module path now records its call form before dispatch and
consumes that context before a builtin can make nested calls. Actual methods
and private Kernel builtins retain their existing dispatch. Only a terminal
primitive failure naming that same method and receiver reaches the existing
bare-name exception helper; unrelated exceptions propagate unchanged.
The class/module method_missing door records the same call context as the
instance door. Its native super target names the class or module receiver,
rather than describing that receiver as an instance of its singleton class.

Corpus 983 compares the exception class, complete message, name and receiver
for module methods, class methods and instance methods. It checks a bare name,
an explicit self receiver, parentheses and an argument, both directly and
through method_missing super. It also checks a later explicit failure after a
rescue and a method_missing implementation that handles the name normally.

Local acceptance uses ordinary O2 builds with the CI-pinned Mere compiler,
the full corpus with both hash-index modes, the same corpus with
MERE_RUBY_VM=1, source gates and record hygiene. Focused unchanged upstream
exception/defined tests are compared with the independently built starting
main. Exact final-head results are recorded in the PR description. Rails cold
measurements and the full upstream unit-test suite are outside this change.

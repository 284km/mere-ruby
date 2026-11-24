# dup and clone through super use the native copy operation

The branch starts from main `b7fe86e104a9a68ff47a3e0598e14f9177eab3e8`,
with Ruby 4.0.10 as the reference.

The primitive leaf cannot copy an ordinary object's instance variables and
returned its receiver when a Ruby dup override called super. The super target
now enters the existing world-aware native copy dispatcher with the existing
one-call native bypass. Container copies consume that bypass before virtual
copy hooks run, so another object's Ruby dup inside a hook remains observable.

Copy-hook class checks look through a primitive receiver's singleton tag to
its real subclass. A String or Array subclass with a singleton method can
therefore initialize a same-class copy. Container clones defer freezing around
the virtual initialize_copy hook and restore the requested frozen state after
the hook returns, matching the existing ordinary-object copy ordering.

Corpus 985 compares plain objects, String subclasses and Array subclasses:
identity, copied ivars, shallow sharing, independent contents and singleton
classes, clone preserving singleton methods, dup dropping them, frozen copies,
clone(freeze: false), a nested Ruby dup from initialize_copy, and a prepended
second super target. All 20 output lines match on both engines in the focused
development comparison.

Final acceptance uses ordinary O2 builds, the full corpus with hash indexing
on and off, the full VM corpus, source gates, record hygiene and focused
upstream copy tests against the starting main. Exact final-head results are
posted in the PR description. No Rails cold measurement or full upstream
unit-test suite is run.

The follow-up review found that forwarding Proc dup/clone through the new
world-aware redispatch re-entered the same Ruby method. Proc's native super
path now calls its existing primitive copy operation directly and copies its
ivars without redispatch. Corpus 985 covers an extended Proc, copied ivars,
invocation, singleton retention and frozen-state preservation.

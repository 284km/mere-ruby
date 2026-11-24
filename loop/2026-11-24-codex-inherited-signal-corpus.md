# Control inherited signal dispositions in corpus 778

The branch starts from main `b7fe86e104a9a68ff47a3e0598e14f9177eab3e8`.
This fixes the corpus fixture, not the runtime's inherited-SIG_IGN handling.

Ruby 4.0.10 preserves inherited ignores: Signal.trap with DEFAULT returns
IGNORE on the first call for an initially ignored INT or HUP, then DEFAULT
on the next call. Main's corpus 778 matches only when both inherited
dispositions are default. Under ignored INT, HUP or both, the uncontrolled
child reports the inherited state differently on the two interpreters.

The signal section now explicitly sets both parent dispositions to DEFAULT,
runs its existing controlled child probes, then restores both saved
dispositions in ensure. The shell still deliberately ignores INT for the
first two children, so the original inherited-ignore checks are retained.

A launch matrix sets each ignored disposition before exec: neither signal,
INT only, HUP only, and both. Ruby 4.0.10, the evaluator and MERE_RUBY_VM=1
all produce exactly the original default-disposition reference output in
all twelve combinations. The runtime implementation is unchanged; its
remaining differences for uncontrolled inherited ignores are not claimed fixed.

Final-head corpus, VM, source-gate and record-hygiene results are posted in
the PR description. No upstream unit-test file or Rails measurement is changed.

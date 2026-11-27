#!/bin/sh
# The class watermark keeps a class made in the middle of a statement, held
# only by the statement's half-evaluated arguments, through a collection
# there (fb_cw_put in m_fiber.mere). The collector also scans the stack for
# class names, and with the scan in place a missing watermark would not
# show: the scan's answer depends on the addresses the words on the stack
# hold, and it kept those classes on most runs. So these programs are run
# with the scan left out (MERE_RUBY_GC_DBG bit 8), on both engines, and must
# still match ruby.
#
# And as a control, the evaluator with the watermarks left out as well (bit 2)
# must lose 559's class: otherwise this check cannot see a missing watermark.
# (The VM keeps that class on its operand stack, so it is not the control.)
#
# What the watermark cannot see -- a class made before the statement and held
# only by a C variable since, corpus/583's `f(queue.pop, GC.start)` -- the scan
# still keeps; 583 is not run here.
#
#   ./tools/class_watermark_check.sh            (./mere-ruby, the reference ruby)
set -u
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
cd "$root/corpus" || exit 2
. "$root/tools/ref_ruby.sh" >/dev/null
RUBYOPT="-Eutf-8${RUBYOPT:+ $RUBYOPT}"; export RUBYOPT
mr="${MR_BIN:-$root/mere-ruby}"
fail=0
for f in 559_native_class_roots.rb 561_anonymous_class_graph_roots.rb 839_classes_made_mid_statement_survive_a_collection.rb; do
  want="$(ruby "$f" 2>&1)"
  for vm in 0 1; do
    got="$(MERE_RUBY_VM=$vm MERE_RUBY_GC_DBG=8 "$mr" "$f" 2>&1)"
    if [ "$got" = "$want" ]; then echo "ok   $f vm=$vm (no class-name scan)"
    else echo "FAIL $f vm=$vm (no class-name scan)"; fail=1; fi
  done
done
want="$(ruby 559_native_class_roots.rb 2>&1)"
got="$(MERE_RUBY_VM=0 MERE_RUBY_GC_DBG=10 "$mr" 559_native_class_roots.rb 2>&1)"
if [ "$got" = "$want" ]; then echo "FAIL control: 559 kept its class with no scan and no watermarks -- the check above sees nothing"; fail=1
else echo "ok   control: 559 loses its class with no scan and no watermarks"; fi
exit $fail

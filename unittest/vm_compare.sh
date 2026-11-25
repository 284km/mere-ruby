#!/bin/sh
# unittest/vm_compare.sh -- CRuby's tests on mere-ruby's two executions, the
# evaluator and the ISeq VM (MERE_RUBY_VM=1), compared test by test.
#
#   sh unittest/vm_compare.sh <ruby-src> [--list FILE] [path under test/ ...]
#       (VM_COMPARE_OUT=<dir> keeps the records; the rest as unittest/run.sh)
#
# run.sh runs each file under ruby and under mere-ruby and records the tests
# mere-ruby did not pass (its tags). This runs it twice, once on each
# execution, and compares the two records: a test the evaluator passes and
# the VM does not is the VM's defect, since the same build passes it the
# other way. Nothing here asks what ruby does beyond what run.sh already asks.
#
# A file in which the two differ is run once more on both executions, and
# only what differs both times is reported: a test at a time limit, or one
# that depends on the order of a GC, can differ once (test_exception's
# test_blocking_backtrace has a 10 s bound, and missed it under load).
#
# Exits 1 when a test fails on the VM alone (VM_ONLY), or a file the
# evaluator completes does not complete on the VM.
set -u
here="$(cd "$(dirname "$0")" && pwd)"
src="${1:?usage: unittest/vm_compare.sh <ruby-src> [--list FILE] [path under test/ ...]}"
shift
if [ "${1:-}" = "--list" ]; then
  list="${2:?--list names a file}"
  shift 2
  set -- $(awk 'NF && $0 !~ /^#/ {print $1}' "$list") "$@"
fi
out="${VM_COMPARE_OUT:-$(mktemp -d)}"
mkdir -p "$out"
# one pass: run.sh on each execution, into <out>/<pass>-evaluator and -vm.
# run.sh exits non-zero when a file is incomplete; that is a finding here,
# read from its COVERAGE.tsv, and not a reason to stop.
pass() {
  name="$1"; shift
  env -u MERE_RUBY_VM UNITTEST_RECORD_DIR="$out/$name-evaluator" sh "$here/run.sh" "$src" "$@" > "$out/$name-evaluator.log" 2>&1
  MERE_RUBY_VM=1 UNITTEST_RECORD_DIR="$out/$name-vm" sh "$here/run.sh" "$src" "$@" > "$out/$name-vm.log" 2>&1
}
pass first "$@"
python3 "$here/vm_compare.py" "$out/first-evaluator" "$out/first-vm" --differing "$out/differing.txt" > "$out/first.txt"
if [ -s "$out/differing.txt" ]; then
  echo "vm_compare: $(wc -l < "$out/differing.txt" | tr -d ' ') files differ; run again" >&2
  pass again $(cat "$out/differing.txt")
  python3 "$here/vm_compare.py" "$out/again-evaluator" "$out/again-vm" --both-times "$out/first-evaluator" "$out/first-vm"
  status=$?
else
  cat "$out/first.txt"
  status=0
fi
echo "vm_compare: records in $out" >&2
exit $status

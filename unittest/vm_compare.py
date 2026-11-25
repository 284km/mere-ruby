"""Compare two unittest/run.sh records, one made on mere-ruby's evaluator and
one on its ISeq VM (MERE_RUBY_VM=1), test by test.

    python3 unittest/vm_compare.py <evaluator-records> <vm-records>
        [--differing FILE] [--both-times <evaluator-records> <vm-records>]

A record is run.sh's UNITTEST_RECORD_DIR: COVERAGE.tsv (each file's state on
each side) and tags/<file>.txt (each test mere-ruby did not pass, and how).
For each file both records ran:

  VM_ONLY    a test the evaluator passed and the VM did not
  EVAL_ONLY  a test the VM passed and the evaluator did not
  VM_FILE    a file the evaluator completed and the VM did not

--differing writes the files with any of the three, one a line (for a second
run). --both-times keeps only what the given first records showed too.
Exits 1 when a VM_ONLY or a VM_FILE remains.
"""
import argparse
import csv
import sys
from pathlib import Path


def tag_key(file):
    key = file.replace("/", "_")
    if "@" in key:
        key = key.replace(".rb@", "@")
    elif key.endswith(".rb"):
        key = key[:-3]
    return key


def load(records):
    records = Path(records)
    coverage = {}
    path = records / "COVERAGE.tsv"
    if path.exists():
        with path.open() as stream:
            for row in csv.DictReader(stream, delimiter="\t"):
                coverage[row["file"]] = row
    tags = {}
    for file in coverage:
        tag = records / "tags" / (tag_key(file) + ".txt")
        red = {}
        if tag.exists():
            for line in tag.read_text(errors="replace").splitlines():
                if "\t" in line:
                    name, state = line.rsplit("\t", 1)
                    red[name] = state
        tags[file] = red
    return coverage, tags


def compare(evaluator, vm):
    ev_cov, ev_tags = evaluator
    vm_cov, vm_tags = vm
    found = []
    for file in sorted(set(ev_cov) & set(vm_cov)):
        ev_done = ev_cov[file].get("mere_state") == "COMPLETE"
        vm_done = vm_cov[file].get("mere_state") == "COMPLETE"
        if ev_done and not vm_done:
            found.append(("VM_FILE", file, "", vm_cov[file].get("mere_state", "?") + " exit " + vm_cov[file].get("mere_exit", "?")))
        ev_red, vm_red = ev_tags[file], vm_tags[file]
        for name in sorted(set(vm_red) - set(ev_red)):
            found.append(("VM_ONLY", file, name, vm_red[name]))
        for name in sorted(set(ev_red) - set(vm_red)):
            found.append(("EVAL_ONLY", file, name, ev_red[name]))
    return found


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("evaluator")
    parser.add_argument("vm")
    parser.add_argument("--differing", type=Path)
    parser.add_argument("--both-times", nargs=2, metavar=("FIRST_EVALUATOR", "FIRST_VM"))
    args = parser.parse_args()
    evaluator, vm = load(args.evaluator), load(args.vm)
    found = compare(evaluator, vm)
    files = len(set(evaluator[0]) & set(vm[0]))
    if args.both_times:
        first_ev, first_vm = load(args.both_times[0]), load(args.both_times[1])
        # (the count is the first run's: the second ran only the files that
        #  differed)
        files = len(set(first_ev[0]) & set(first_vm[0]))
        first = {(kind, file, name) for kind, file, name, _ in compare(first_ev, first_vm)}
        once = [f for f in found if (f[0], f[1], f[2]) not in first]
        found = [f for f in found if (f[0], f[1], f[2]) in first]
        if once:
            print(f"-- {len(once)} differences seen in the second run only, not counted")
    if args.differing:
        args.differing.write_text("".join(f + "\n" for f in sorted({f[1] for f in found})))
    for kind, file, name, state in found:
        print(f"{kind}\t{file}\t{name}\t{state}")
    counts = {kind: sum(1 for f in found if f[0] == kind) for kind in ("VM_ONLY", "EVAL_ONLY", "VM_FILE")}
    print(f"vm_compare: {files} files -- VM_ONLY {counts['VM_ONLY']}, EVAL_ONLY {counts['EVAL_ONLY']}, VM_FILE {counts['VM_FILE']}")
    return 1 if counts["VM_ONLY"] or counts["VM_FILE"] else 0


if __name__ == "__main__":
    sys.exit(main())

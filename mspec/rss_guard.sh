#!/bin/sh
# Kill any mere-ruby whose RSS passes a cap, so ONE runaway spec file costs one
# recorded CRASH instead of the whole machine.
#
#   ./mspec/rss_guard.sh [cap_kb] [logfile] [poll_seconds] &   # then sweep
#
# The sweep bounds TIME (a per-file alarm) and does not bound BYTES. That is not
# a symmetric omission: at the allocation rate measured for this interpreter
# (~2.7 GB/s) a 25s alarm still permits ~67 GB, and macOS has no `ulimit -v` or
# `-d` to lean on (`ulimit -t` bounds CPU seconds, which for an allocation loop
# is the same 2.7 GB/s). A poller is the only bound on bytes there is.
#
# THE POLL INTERVAL IS HALF THE GUARD. What a process actually reaches is
# `cap + rate * interval`: at the ~6.5 GB/s measured here, 6 GB with `sleep 5`
# permits ~20 GB, and 6 GB with `sleep 1` permits ~12.5 GB, which this 32 GB
# machine survives.
#
# THE CAP IS ALSO PART OF THE RECORD, so it is not free to tighten. Dropping it
# to 3 GB after the 2026-09-04 crash turned five spec files that had finished
# into `CRASH (no output before aborting)` -- core/integer's bit_length, even?
# and to_r, core/method's call, core/rational's to_f -- and the table read as a
# regression in the interpreter. The crash was not this cap: it was the
# reference side of run_spec.sh running with no time bound and no byte bound at
# all. Fix what actually ran away; do not pay for it in the record.
#
# Both sides are watched. The reference ruby runs as `<rbenv>/bin/ruby
# /var/folders/.../driver.rb` -- no "mere-ruby" in that command line at all --
# so for as long as this matched only the interpreter's own name, a runaway on
# the reference side was invisible. That is the shape of the 2026-09-04 crash:
# the machine died twice in core/env with nothing in this log.
#
# A killed run is recorded as `CRASH (no output before aborting)`, which reads
# as "the interpreter aborted" -- so the kill log is part of the record, not a
# side note: check it before believing a CRASH row.
cap_kb=${1:-6291456}
log=${2:-mspec/rss_kills.log}
poll=${3:-1}
while :; do
  ps -axo pid=,rss=,args= 2>/dev/null | while read -r pid rss args; do
    case "$args" in
      *mere-ruby*|*driver.rb*) [ "$rss" -gt "$cap_kb" ] 2>/dev/null && {
        echo "$(date '+%H:%M:%S') killed pid=$pid rss=$((rss/1024))MB $args" >> "$log"
        kill -9 "$pid" 2>/dev/null; };;
    esac
  done
  sleep "$poll"
done

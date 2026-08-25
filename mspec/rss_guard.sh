#!/bin/sh
# Kill any mere-ruby whose RSS passes a cap, so ONE runaway spec file costs one
# recorded CRASH instead of the whole machine.
#
#   ./mspec/rss_guard.sh [cap_kb] [logfile] &     # then run scoreboard.sh
#
# The sweep bounds TIME (a per-file alarm) and does not bound BYTES. That is not
# a symmetric omission: at the allocation rate measured for this interpreter
# (~2.7GB/s) a 60s alarm still permits ~160GB, and macOS has no `ulimit -v` or
# `-d` to lean on. Measured here: core/integer/even_spec.rb reaches **15.3GB in
# under five seconds**, and four more files pass 6GB. Sweeping without this
# running took the machine down.
#
# The 5s poll is coarse ON PURPOSE -- cheap enough to leave running for an hour
# -- but that means a process can be far past the cap by the time it is seen. A
# 3GB cap caught one at 15.3GB. Read the cap as "kill it eventually", not as a
# ceiling the process respected.
#
# What it costs the record: a killed run prints nothing, so run_one records it as
# CRASH with the cause `(no output before aborting)`. That text says the
# interpreter aborted, and what actually happened is that this script shot it. The
# honest fix is a verdict of its own -- the way TIMEOUT is one -- which needs the
# bound INSIDE run_spec.sh, where the exit status of mere-ruby is still visible.
# Until then, cross-check `(no output before aborting)` against this log.
cap_kb=${1:-6291456}
log=${2:-mspec/rss_kills.log}
while :; do
  ps -axo pid=,rss=,args= 2>/dev/null | while read -r pid rss args; do
    case "$args" in
      *mere-ruby*) [ "$rss" -gt "$cap_kb" ] 2>/dev/null && {
        echo "$(date '+%H:%M:%S') killed pid=$pid rss=$((rss/1024))MB $args" >> "$log"
        kill -9 "$pid" 2>/dev/null; };;
    esac
  done
  sleep 5
done

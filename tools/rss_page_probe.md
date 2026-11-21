# Read-only page ownership

`rss_page_probe.py` extends the separate heap observer with page-table flags
for every inventoried native region block. It reads `/proc/self/pagemap`;
it never reads the payload, requests collection, clears references, changes
pinning, or modifies mappings. Its binary retains the diagnostic build mode
and is rejected by the ordinary memory gate.

The [Linux pagemap documentation](https://www.kernel.org/doc/html/latest/admin-guide/mm/pagemap.html)
defines present, swapped and exclusive-mapping flags independently of PFNs.
The observer neither uses nor logs PFNs. Exclusive flags can have conservative
semantics for large allocations; these counters are not a count of unique
physical pages, live Ruby objects, RSS or PSS. They provide page-level evidence
alongside the existing process RSS and region capacities.

Only full pages inside a payload belong to its counters. Partial edges are
reported as omitted bytes. Every heap range must have exactly one matching
page observation, and interior ranges may not overlap. Missing, duplicate,
malformed, impossible or unavailable observations fail collection. Denied
access is an explicit error, never an invented zero. A native control touches
two of eight anonymous pages, verifies two present pages, discards one and
verifies one; the reader must not fault in the other pages. Another control
denies the reader and verifies failure and errno preservation.

The independent `rss-page-ownership.yml` matrix locks repaired source `90c83c6e`,
released parent compiler `43f2994b`, the Map-slot clearing release `408b03d9`
from [Mere #86](https://github.com/merelang/mere/pull/86), and Ruby
source `3e93b23a` on native Linux/x86-64. Each condition has its own complete
ordinary controls and artifact. This adds an explicit experimental compiler
condition. The local candidate `44bc7bc0` has the same tree as that release;
its recorded compiler SHA is retained rather than relabeled. Existing
historical jobs and ordinary CI compiler pins are
unchanged.
The ordinary complete Module, Method-copy, reference and original selected
clone gates run first. Their 600-second / 2-GiB bounds, ten-second children,
original inputs and assertions remain unchanged. A failed ordinary gate still
fails the job even when diagnostics complete. Existing historical jobs and
their source/compiler locks remain unchanged.

Build with `python3 tools/rss_page_probe.py build --subject /path/to/subject
--diagnostic-root /path/to/probe`. Collect with the same paths and
`collect --compiler-root /path/to/compiler --reference /path/to/ruby
--ruby-src /path/to/ruby-source --output /path/to/results`. The subject and
ordinary/diagnostic C and binary hashes must match the build receipt. Set
`MERE_REF` to the full compiler SHA before collecting; the compiler checkout
must match it, as in the workflow.
Raw logs, child input, all original verdicts, heap/page observations and
build receipts are uploaded even on failure. Reading and logging may change
layout, so diagnostic ratios cannot replace ordinary ratios. A root pinner
does not establish that its references are stale or safe to discard.

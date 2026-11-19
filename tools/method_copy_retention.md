# Method-copy retention diagnostics

The paired assertion remains `method_copy_memory_check.py`: the unchanged
21,000-owner program, every post-GC prefix at most 2x initial RSS, and
600 seconds / 2 GiB per side. Run it with the ordinary O2 interpreter:

```sh
LANG=en_US.UTF-8 python3 tools/method_copy_memory_check.py \
  --reference /path/to/ruby --output /path/to/cache/method-copy-gate
```

To inspect actual retained method metadata separately:

```sh
LANG=en_US.UTF-8 python3 tools/method_copy_retention.py \
  --output /path/to/cache/method-copy-retention
```

This diagnostic runs seven independent prefixes. Only the final prefix is
the complete original program. Existing store/GC/region logging is enabled;
the source hash, executable hash, combined raw output, exit/limit state,
RSS series and actual byte counters are retained. A completed diagnostic
does not mean the paired assertion passed. Shorter prefixes are never
alternate passing workloads, warmups or baselines. In particular, the full
diagnostic can exceed 2x even when a separate ordinary run passes.

`store_stats` now also reports current native arenas for method source
locations, cref, parameters, Method payloads, aliases, definition closures
and anonymous classes. These are reads only; they perform no compaction.

The pinned Mere runtime's `map_bytes` reports the map's current private
arena. It omits old generations on `__lang_retired`, which suspended stacks
can still pin. The ordinary `region-stats kept` counter is a different
region and is not a count of those retired generations. Zero kept bytes
therefore does not establish that old map arenas were freed.

For a separate native diagnostic, compile
`tools/method_copy_retired_observer.c` **in place of** `mr.c`, retaining the
same compiler, O2/link flags, glue files and dependencies from `tools/build.sh`.
Use a separate output directory. The observer reads native retired arenas
at exit and never calls the collector, pin hook, compactor or deallocator.
Mark its `.build_mode` as `DIAGNOSTIC O2 observer`, so the normal gate refuses
that executable. Its private C layout is tied to the pinned compiler; this
file is not part of the ordinary build.

Exit-time capacity is neither resident memory nor a measurement at the
largest RSS sample. Independent prefix processes also have different native
address layouts. Use these counters to identify retained ownership, not to
claim that their difference explains every RSS byte or proves a safe fix.
Never remove pins, change cache/GC constants or relax the original gate to
make this diagnostic green.

# Original clone RSS: heap and temporary-region ownership

The separate `clone-rss-heap.yml` job locks the actual failing Module run's
source `ae6bd8cc` and its existing compiler `01f5ad73` on native Ubuntu x86-64.
It reads another session's immutable source; it does not modify that branch.
This job measures the locked failing runtime. Its verdict cannot establish
a candidate repair. A failed original assertion remains failed.

After both ordinary and private diagnostic O2 builds finish, run the complete
original Module file, one reference clone case, four ordinary clone cases and
two separate diagnostic cases, in that fixed order. No retry-until-pass loop.
Keep every result, including ordinary failures. Each file/side retains
600 seconds / 2 GiB, the upstream child retains ten seconds, and its original
input and strict RSS assertion remain unchanged. The ordinary gate must reject
the diagnostic build mode. Existing workflows, baselines and compiler pins
are unchanged.

The heap extension reads glibc allocator accounting, anonymous/file/stack
mappings of at least 1 MiB resident size, current coroutine stack ranges and
the capacities of active temporary regions, the default region, cached blocks,
retired generations and the permanently kept region. It also reports extra
independent global maps of at least 64 KiB capacity. These are printout filters,
not changes to collection or allocation thresholds. The full original workload
still runs. The existing observer reports its original mandatory maps, saved
pinners and method-floor accounting too. No collection, pin, allocation policy
or deallocation operation is added. Reading and logging can change layout;
diagnostic ratios never replace the ordinary assertions.

Capacity, cumulative allocation, allocator reservation and resident memory
are different measurements. Per-mapping RSS does not locate individual resident
pages within that mapping. Coroutine region inventories must be complete, and
default/cache/retired block capacities must agree with the independent native
totals. Missing or truncated evidence fails collection. Unsupported heap
observations do not acquire invented zero values.

The committed fixture comes from a separate native Linux/aarch64 observation
of runtime `dde0f90c`, with the same original clone input and compiler
`01f5ad73`. Initial and final snapshots each have 21 active temporary regions;
their capacity changes from 22,020,096 to 83,886,080 bytes, while allocation
since those regions were acquired is 31,096 versus 32,560 bytes. Several final
MCALL regions have 16-MiB capacity and zero allocation in that call. Retired
capacity also varies. The ordinary local cases still pass, so this does not
establish a repair or reproduce the earlier failed native x86-64 case. It
does identify oversized cached blocks reused by tiny temporary scopes as a
concrete factor to investigate. Allocator free bytes alone do not explain
that observation. No cache constant or native reuse implementation is changed.

The artifacts retain raw logs, original child input, all ordinary case verdicts,
build and binary hashes, and separate heap observations. The new hosted result
must be assessed independently of this local captured fixture.

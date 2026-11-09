# Cyclic YAML output

`ruby bench/yaml_cycles.rb` and `./mere-ruby bench/yaml_cycles.rb` dump a
one-element array containing itself. The output must be `--- &1\n- *1\n`.
The old emitter recursively expanded the array; the new emitter records object
identity before following edges and renders repeated references as aliases.

On macOS/arm64, O2 with Mere compiler
`991f299b20f18639713685fe3297e087ddc5b1d7`, separate child processes measured with
`getrusage(RUSAGE_CHILDREN)` reported:

| Emitter | Exit | Wall seconds | Native peak RSS (bytes) |
| --- | ---: | ---: | ---: |
| Before (unchanged main emitter, binary `78ab811`) | 1, SystemStackError | 2.064 | 864,567,296 |
| Indexed identity graph | 0 | 0.131 | 78,856,192 |

These are single-process native high-water marks; they are not periodic
process-family samples or end-to-end CI timings.

The unchanged Ruby 4.0.9 upstream tests, under the CI harness's 600-second /
2,097,152-KiB process-family budgets, completed as follows. Ruby source is pinned
to `3e93b23afcec3433f6aecc34b5d832799d754238`.

| File | Tests | Assertions | Failures | Errors | Seconds | Family peak KiB |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `psych/test_array.rb` | 9 | 7 | 4 | 3 | 1.250 | 140,752 |
| `psych/test_struct.rb` | 3 | 3 | 1 | 1 | 1.304 | 178,176 |
| `psych/test_data.rb` | 5 | 6 | 4 | 1 | 1.210 | 141,168 |

Before the change, the array file reached MEMORY_LIMIT in 2.208 seconds at a
sampled 2,543,248 KiB (sampling can overshoot the limit). All three files had
previously been recorded as memory-limited. Completion does not mean conformance:
visitor APIs, Struct ivars and Data serialization still need work. The loader
now reconstructs the emitted anchor/alias subset, including shared and cyclic
collections and ordinary objects. The standalone dump regression compares output directly against Ruby and
covers four indentation widths, cycles, shared values, complex keys, frozen
containers, stream state, separate dumps, IO output, and GC.


## Acyclic graph scaling

An identity Hash in this runtime currently falls back to linear key searches.
The graph instead uses an ordinary integer-key Hash and retains the object in
each node to prevent ID reuse. A bound original identity method bypasses
object-level `__id__`/`object_id` overrides.

`python3 unittest/yaml_graph_check.py` is required by the CI YAML step. It checks
output size and child user CPU for 8,000 and 32,000 unshared empty arrays. The
32,000-node run must stay below eight times the smaller run plus one second;
this allows substantial machine variation while rejecting quadratic growth.
The check explicitly enables the index; correctness is checked separately with
indexing ON/OFF and GC stress.

| Emitter | 8,000 nodes, user seconds | 32,000 nodes, user seconds | Gate |
| --- | ---: | ---: | --- |
| Original identity Hash (negative-control preload of `11af274`) | 4.756 | 45.769 | Reject |
| Indexed IDs, macOS arm64 O2 | 2.265 | 8.286 | Pass |
| Indexed IDs, Linux O2 | 1.539 | 6.147 | Pass |

The negative control uses the same current binary with the previous embedded
Psych source preloaded. It isolates the table change; it is not an end-to-end CI
benchmark. The loader also has output/identity round-trip regressions, so an
output-only emitter comparison cannot mask a broken bundled loader.

## Event backend and object visitors

The bundled Psych 5.3.1 protocols now use a Ruby event parser and emitter.
`lib/psych_parser.rb` emits events and locations rather than constructing Ruby
objects directly; the pinned nodes/visitors handle AST construction and loading.
`lib/psych_emitter.rb` accepts the handler protocol and renders node styles.
The original object graph implementation remains the baseline for the earlier
measurements above.

The refreshed upstream run discovers 635 tests in 47 files and passes all of
them against Ruby 4.0.9. The optional yamldbm file discovers zero tests on both
installed interpreters. Independent gates cover parser events/locations, malformed
input, and 29 scalar values with all five explicit styles in both wire directions.

`unittest/psych_memory_check.py` supervises each large operation with a
120-second / 2,097,152-KiB process-family bound. Its native-generated document
contains a 4 MiB plain scalar, a 4 MiB literal scalar, Unicode, and 1,000 nested
rows; the candidate loads it and emits a document the native parser validates.
A separate 4 MiB quoted scalar, a 1,000-key YAML::Store transaction/update, and
20/200 parser/visitor lifetimes are checked as well. Default-arena allocation
growth must stay below 8 MiB between those lifetime counts.

During development the large-wire check rejected the per-token Regexp scanner
at the 2 GiB memory bound. Alternating large source and small token matches
invalidated the VM's last-subject snapshot cache, allocating another source copy
per token. The scanner now caches each delimiter's next byte position and keeps
Unicode character marks separately. Scalar bodies use slices/chunks and one join.

The YAMLTree registrar uses integer identity keys and retains each source object.
Unboxed core values whose fallback identity is zero use the runtime identity table
instead, so a Range cannot alias `false`. Equal unboxed Range literals still have
the core representation's identity limitation; this backend does not promise to
repair that independent core feature.

Final macOS arm64 O2 measurements use the pinned Mere compiler
`3f0214164bdceea51c1418e4856383f64059cbd2`. The memory gate samples the whole
process family; these are single runs while other validation was active.

| Operation | Wall seconds | Family peak KiB |
| --- | ---: | ---: |
| Load native large document | 20.148 | 583,616 |
| Emit large document | 9.132 | 457,200 |
| Load 4 MiB quoted scalar | 0.718 | 138,880 |
| Store 1,000 keys and update | 38.469 | 453,536 |
| 20 parser/visitor lifetimes | 1.241 | 139,632 |
| 200 parser/visitor lifetimes | 6.874 | 166,304 |

Default-arena allocation totals were 45,414,672 and 50,788,112 bytes for
20/200 lifetimes: growth 5,373,440 bytes, below the 8 MiB gate. The event-backend
graph gate measured 7.534/30.224 child user seconds for 8,000/32,000 nodes and
passed its relative scaling bound. These numbers replace neither the earlier
implementation's timings nor a dedicated latency benchmark.

The final Linux arm64 O2 binary also passes all 635 Psych tests, the event and
scalar-wire gates, and the same supervised memory gate. Docker uses Ruby 4.0.9
and a 512 MiB stack limit for the interpreter.

| Operation | Wall seconds | Family peak KiB |
| --- | ---: | ---: |
| Load native large document | 8.666 | 606,908 |
| Emit large document | 4.391 | 480,672 |
| Load 4 MiB quoted scalar | 0.439 | 123,376 |
| Store 1,000 keys and update | 21.536 | 404,176 |
| 20 parser/visitor lifetimes | 0.540 | 90,344 |
| 200 parser/visitor lifetimes | 3.094 | 104,556 |

Linux default-arena allocation totals were 45,294,184/50,526,208 bytes,
a 5,232,024-byte increase. Six YAML corpus programs match the reference under
GC stress every 50 allocations with hash indexing both enabled and disabled.

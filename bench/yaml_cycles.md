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

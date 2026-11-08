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
| Identity graph | 0 | 0.130 | 78,823,424 |

These are single-process native high-water marks; they are not periodic
process-family samples or end-to-end CI timings.

The unchanged Ruby 4.0.9 upstream tests, under the CI harness's 600-second /
2,097,152-KiB process-family budgets, completed as follows. Ruby source is pinned
to `3e93b23afcec3433f6aecc34b5d832799d754238`.

| File | Tests | Assertions | Failures | Errors | Seconds | Family peak KiB |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `psych/test_array.rb` | 9 | 5 | 4 | 5 | 1.298 | 151,104 |
| `psych/test_struct.rb` | 3 | 1 | 1 | 2 | 1.310 | 168,800 |
| `psych/test_data.rb` | 5 | 4 | 3 | 2 | 1.292 | 162,816 |

Before the change, the array file reached MEMORY_LIMIT in 2.208 seconds at a
sampled 2,543,248 KiB (sampling can overshoot the limit). All three files had
previously been recorded as memory-limited. Completion does not mean conformance:
the loader's aliases, visitor APIs, Struct ivars and Data serialization still need
work. The standalone dump regression compares output directly against Ruby and
covers four indentation widths, cycles, shared values, complex keys, frozen
containers, stream state, separate dumps, IO output, and GC.

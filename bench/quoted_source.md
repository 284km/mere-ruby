# Quoted source parsing

`quoted_source.rb` builds a Ruby string literal containing `2 * N` bytes, then
evaluates it and checks the decoded value. `QUOTE` selects `"` (the default) or
`'`. This measures string lexing; creating an Array with 100,000 elements was
already bounded. The upstream allocation test exposed the problem because it
embeds generated Array code inside another quoted Ruby source string.

```sh
N=100000 ./mere-ruby bench/quoted_source.rb
QUOTE="'" N=100000 ./mere-ruby bench/quoted_source.rb
```

Both quote scanners formerly concatenated the entire decoded prefix for each
byte. They now append to a temporary string buffer and copy out the completed
literal once. Interpolation seals one literal run and starts a fresh buffer;
the Unicode codepoint list inside a single `\u{...}` also has a temporary buffer.
Escape decoding, token order and error paths retain their existing rules.

Local macOS O2 measurements with pinned Mere compiler `991f299b`:

| Literal bytes | Previous scanner: peak RSS | Buffered scanner: peak RSS |
| ---: | ---: | ---: |
| 2,000 | 61,865,984 bytes | 59,375,616 bytes |
| 20,000 | 260,243,456 bytes | 59,588,608 bytes |
| 200,000 | Exceeded the 2 GiB process-family guard | 61,374,464 bytes |
| 1,000,000 | Not measured | 70,647,808 bytes |

Successful-run peaks are native child-process `getrusage` maxima, including
startup. The previous-scanner binary contains the validated #38/#42 integration
(runtime sources equivalent to `4ef42c3`); the candidate is based on main
`c3ca39b`. These are individual local observations, not CI speed claims.

The full upstream `ruby/test_allocation.rb` now completes within the unchanged
600-second/2-GiB limits: 82 tests in 24.471 seconds at 473,376 KiB peak family
RSS. Its 82 errors remain: the ObjectSpace count results do not provide the
array/hash counters those CRuby allocation checks expect. A small unchanged
test reproduces that error before this patch. Completion is not conformance.

The final code also handles a single Unicode escape list containing 100,000
codepoints at 61,734,912 bytes peak child RSS; the initial fix to only the outer
quote scanners still exceeded the process-family guard on that input.

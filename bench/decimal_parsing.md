# Long decimal conversion

Build at O2 and run `./mere-ruby bench/long_decimal.rb`. The workload converts 100,000 decimal digits and checks the entire round trip without printing a large number.

On macOS with pinned Mere `991f299b`, main `8bfec2b` exceeded the unchanged 2 GiB process-family budget. Replacing per-digit prefix concatenation with a temporary string buffer completed the same conversion with 169,787,392 bytes maximum child RSS, measured with `resource.getrusage(RUSAGE_CHILDREN).ru_maxrss` (bytes on macOS). A single candidate run took 0.081 seconds; it is not an isolated timing comparison.

The complete upstream `date/test_date_parse.rb` now finishes below the limit (322,400 KiB sampled family RSS, 27 tests, 120 assertions). Its 21 compatibility failures remain reported. This change does not make Date parsing fully conformant.

The corpus regression also covers signs, underscores, malformed suffixes, base autodetection, the 18/19-digit boundary, and long inputs with separators.

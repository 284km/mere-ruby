# Hash reads with a default Proc

`./mere-ruby bench/hash_default_lookup.rb` checks 20,000 hits and misses against a 2,000-entry Hash. The default returns its argument without inserting it.

The default-Proc dispatch guard used to scan every key before ordinary indexed reads could run. Reusing `hix_has` avoids that scan for indexed keys and applies compare-by-identity rules consistently. Unsupported key kinds and `MERE_RUBY_NO_HASH_INDEX=1` retain the existing fallback.

On macOS O2 with pinned Mere `991f299b`, one run before/after the guard change measured 0.829/0.203 seconds wall time and 0.703/0.175 seconds user CPU time. This is a focused workload measurement, not an end-to-end CI speedup. The corpus case checks stored nil/false values, deletion/clear, a mutating default, identity keys and custom hash/eql? keys against Ruby in both index modes.

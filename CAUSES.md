# mere-ruby — what the gap is made of

The records in `SPEC_STATUS.md` and `mspec/tags/`, grouped by CAUSE rather
than by group. A count is a number of spec FILES. The text is the first line
where mere-ruby and ruby disagree (DIFF) or the message it aborted with
(CRASH), with paths and addresses masked.

**KIND** masks the values and keeps the shape -- this is the column that says
what to work on. **CAUSE** is the line as recorded, for reproducing one.

Regenerate with `./mspec/causes.sh` (reads `mspec/tags/`, no sweep).

Classified: 321 files.

## DIFF — 321 files, 106 kinds

| files | kind |
|---|---|
| 34 | `ERROR NoMethodError` |
| 19 | `FAILED expected N, got N` |
| 15 | `FAILED expected TypeError to be raised` |
| 14 | `ERROR NameError` |
| 13 | `FAILED expected true, got false` |
| 13 | `FAILED expected to be identical` |
| 13 | `ERROR ArgumentError` |
| 12 | `FAILED expected ArgumentError to be raised` |
| 10 | `FAILED expected "S", got "S"` |
| 8 | `FAILED expected false, got true` |
| 8 | `ERROR StandardError` |
| 7 | `pass=N fail=N err=N` |
| 7 | `FAILED expected #<OBJ>, got #<OBJ>` |
| 6 | `FAILED expected truthy from #include?` |
| 6 | `ERROR TypeError` |
| 5 | `FAILED expected [N, N, N], got [[N, N], [N, N, N], [N, N, N, N]]` |
| 4 | `FAILED raised NoMethodError, expected TypeError` |
| 4 | `FAILED expected nil, got "S"` |
| 4 | `FAILED expected ZeroDivisionError to be raised` |
| 4 | `FAILED expected NoMethodError to be raised` |
| 4 | `FAILED expected N, got nil` |
| 4 | `FAILED expected "S", got nil` |
| 4 | `ERROR RangeError` |
| 3 | `FAILED expected SyntaxError to be raised` |
| 3 | `FAILED expected RangeError to be raised` |
| 3 | `FAILED expected NameError to be raised` |
| 3 | `FAILED expected LocalJumpError to be raised` |
| 3 | `FAILED expected "S" to match` |
| 2 | `FAILED raised NoMethodError, expected SignalException` |
| 2 | `FAILED raised NoMethodError, expected FrozenError` |
| 2 | `FAILED matcher did not match #<OBJ>` |
| 2 | `FAILED expected not to be identical` |
| 2 | `FAILED expected not N` |
| 2 | `FAILED expected nil, got #<OBJ>` |
| 2 | `FAILED expected falsy from #include?` |
| 2 | `FAILED expected ThreadError to be raised` |
| 2 | `FAILED expected N, got NaN` |
| 2 | `ERROR RuntimeError` |
| 1 | `sh: feature_N: command not found` |
| 1 | `FAILED raised ZeroDivisionError, expected TypeError` |
| 1 | `FAILED raised StandardError, expected ZeroDivisionError` |
| 1 | `FAILED raised StandardError, expected TypeError` |
| 1 | `FAILED raised StandardError, expected ArgumentError` |
| 1 | `FAILED raised NoMethodError, expected ZeroDivisionError` |
| 1 | `FAILED raised ArgumentError, expected SyntaxError` |
| 1 | `FAILED raised ArgumentError, expected IndexError` |
| 1 | `FAILED matcher did not match N` |
| 1 | `FAILED expected {a: N, b: N}, got {a: N}` |
| 1 | `FAILED expected {N => N}, got {}` |
| 1 | `FAILED expected {...}, got {...}` |
| 1 | `FAILED expected {#<OBJ> => "S", #<OBJ> => "S"}, got {}` |
| 1 | `FAILED expected truthy from #start_with?` |
| 1 | `FAILED expected truthy from #lambda?` |
| 1 | `FAILED expected truthy from #finite?` |
| 1 | `FAILED expected truthy from #>` |
| 1 | `FAILED expected truthy from #<=` |
| 1 | `FAILED expected truthy from #<` |
| 1 | `FAILED expected true, got nil` |
| 1 | `FAILED expected true, got "S"` |
| 1 | `FAILED expected falsy from #start_with?` |
| 1 | `FAILED expected a Integer, got N` |
| 1 | `FAILED expected a Complex, got N` |
| 1 | `FAILED expected [], got [[:SYM, :"S"]]` |
| 1 | `FAILED expected [], got [:@make, :@model, :@year]` |
| 1 | `FAILED expected [], got #<OBJ>` |
| 1 | `FAILED expected [[N, [N]], [N, [N, N]], [N, [N]]], got [[N, [N]], [:SYM, [N]], [N, [N, N]], [:SYM, [N]], [N, [N]]]` |
| 1 | `FAILED expected [[N, N], [N, N], [N, N]], got [[N, nil], [N, nil], [N, nil]]` |
| 1 | `FAILED expected [[N, N, N], [N, N, N]], got []` |
| 1 | `FAILED expected [[N, N, N], [N, N, N], [N]], got []` |
| 1 | `FAILED expected [N, N, [N], {x: N}, N, {}], got [[N, N, N, {x: N}], N, [], nil, N, {}]` |
| 1 | `FAILED expected [N, N, N, N, N, N], got [N, N, N, N, N, N]` |
| 1 | `FAILED expected [N, N, N, N, N, N, N, N, N], got [N, N, N, N, N, N, N, N, N, N]` |
| 1 | `FAILED expected [N, N ...[clipped]` |
| 1 | `FAILED expected [N, :SYM], got [N, N, N, :SYM]` |
| 1 | `FAILED expected [N, :SYM, :SYM, N], got [N, #<OBJ>, N]` |
| 1 | `FAILED expected [:SYM], got :SYM` |
| 1 | `FAILED expected ["S", "S"], got nil` |
| 1 | `FAILED expected ["S", "S", "S"], got ["S", "S"]` |
| 1 | `FAILED expected ["S", "S", "S", "S"], got ["S", "S", "S", "S"]` |
| 1 | `FAILED expected ["S", "S", "S", "S", "S", "S", "S", "S"], got ["S", "S", "S", "S", "S"]` |
| 1 | `FAILED expected N, got true` |
| 1 | `FAILED expected N, got (N+Ni)` |
| 1 | `FAILED expected N, got "S"` |
| 1 | `FAILED expected N ...[clipped]` |
| 1 | `FAILED expected MethodSpecs::Methods, got Object` |
| 1 | `FAILED expected MethodSpecs::InheritedMethods::C, got MethodSpecs::InheritedMethods::B` |
| 1 | `FAILED expected IndexError to be raised` |
| 1 | `FAILED expected Encoding::CompatibilityError to be raised` |
| 1 | `FAILED expected :SYM, got nil` |
| 1 | `FAILED expected :SYM, got :SYM` |
| 1 | `FAILED expected /(p(a)t[e]rn)/, got nil` |
| 1 | `FAILED expected (N/N), got N` |
| 1 | `FAILED expected (N/N), got (N/N)` |
| 1 | `FAILED expected #<OBJ>, got nil` |
| 1 | `FAILED expected "S"localhost\"S"root\"S", got "S"localhost\"S"root\"S"` |
| 1 | `FAILED expected "S"\xN\"S", got "S"N\"S"` |
| 1 | `FAILED expected "S"\uN\"S", got "S"` |
| 1 | `FAILED expected "S"\"S", got "S"` |
| 1 | `FAILED expected "S", got N` |
| 1 | `FAILED expected "S", got #<OBJ>` |
| 1 | `FAILED expected "S"$ruby!\"S", got "S"` |
| 1 | `FAILED expected "` |
| 1 | `ERROR ZeroDivisionError` |
| 1 | `ERROR SystemStackError` |
| 1 | `ERROR SyntaxError` |
| 1 | `ERROR Errno::ENOENT` |

<details><summary>the same rows by exact cause (top 40)</summary>

| files | cause |
|---|---|
| 15 | `FAILED: expected TypeError to be raised` |
| 12 | `FAILED: expected ArgumentError to be raised` |
| 5 | `FAILED: gathers initial args as elements when each yields multiple: expected [1, 3, 6], got [[1, 2], [3, 4, 5], [6, 7, 8, 9]]` |
| 4 | `FAILED: raised NoMethodError, expected TypeError` |
| 4 | `FAILED: expected ZeroDivisionError to be raised` |
| 4 | `FAILED: expected NoMethodError to be raised` |
| 3 | `FAILED: expected SyntaxError to be raised` |
| 3 | `FAILED: expected RangeError to be raised` |
| 3 | `FAILED: expected NameError to be raised` |
| 3 | `FAILED: expected LocalJumpError to be raised` |
| 3 | `ERROR: bignum dispatches the correct operator after coercion: ArgumentError` |
| 2 | `pass=14 fail=0 err=0` |
| 2 | `pass=11 fail=0 err=0` |
| 2 | `FAILED: transcodes from the locale encoding to Encoding.default_internal if set: expected to be identical` |
| 2 | `FAILED: sets the encoding to the encoding of the source String: expected to be identical` |
| 2 | `FAILED: returns self: expected to be identical` |
| 2 | `FAILED: returns -1: expected -1, got -4` |
| 2 | `FAILED: raised NoMethodError, expected SignalException` |
| 2 | `FAILED: raised NoMethodError, expected FrozenError` |
| 2 | `FAILED: is a private method: expected truthy from #include?` |
| 2 | `FAILED: is a private method only when -n is passed: expected falsy from #include?` |
| 2 | `FAILED: includes Comparable: expected true, got false` |
| 2 | `FAILED: expected not 0` |
| 2 | `FAILED: expected ThreadError to be raised` |
| 2 | `FAILED: duplicates the range: expected not to be identical` |
| 2 | `FAILED: deletes pairs through enumerator: expected nil, got "0"` |
| 2 | `ERROR: when given an argument and no block doesn't yield an empty array if the filter matches the first entry or the last entry: NoMethodError` |
| 2 | `ERROR: bignum coerces the RHS and calls #coerce even if it's private: TypeError` |
| 1 | `sh: feature_14386: command not found` |
| 1 | `pass=4 fail=2 err=7` |
| 1 | `pass=34 fail=0 err=0` |
| 1 | `pass=16 fail=0 err=0` |
| 1 | `FAILED: yields while increasing self until it is greater than floor of a Float endpoint: expected [9, 10, 11, 12, 13, -5, -4, -3, -2], got [9, 10, 11, 12, 13, -5, -4, -3, -2, -1]` |
| 1 | `FAILED: yields only when necessary: expected 2, got 3` |
| 1 | `FAILED: yields multiple arguments as an array: expected to be identical` |
| 1 | `FAILED: yields elements to the provided block: expected [6, 5, 4, 3, 2, 1], got [1, 2, 3, 4, 5, 6]` |
| 1 | `FAILED: wraps the lock/unlock pair in an ensure: expected true, got false` |
| 1 | `FAILED: will only go through what's needed: expected 3, got 4` |
| 1 | `FAILED: will only go through what's needed: expected 2, got 5` |
| 1 | `FAILED: uses non-e format for a positive value with whole part having 15 significant figures: expected "10000000000000.0", got "1.0e+13"` |

</details>

## The absent names

Files whose FIRST divergence is NoMethodError or NameError, keyed by the
method the spec file is named for. Not every row is a missing method --
a spec can raise NoMethodError from a helper -- but most are, and the
class column says where the weight sits.

| class | absent names (from the spec filenames) |
|---|---|
| exception (7) | `backtrace_locations backtrace errno exception interrupt io_error signal_exception` |
| kernel (6) | `binding lambda loop method select test` |
| rational (5) | `comparison divide minus multiply plus` |
| symbol (4) | `all_symbols intern match slice` |
| struct (4) | `deconstruct filter initialize new` |
| language (4) | `alias constants module numbered_parameters` |
| enumerable (4) | `inject slice_after slice_before sum` |
| unboundmethod (3) | `bind_call original_name super_method` |
| method (3) | `original_name super_method to_proc` |
| proc (2) | `binding new` |
| numeric (2) | `integer real` |
| threadgroup (1) | `list` |
| regexp (1) | `timeout` |
| integer (1) | `div` |
| array (1) | `fetch_values` |

_Generated by `mspec/causes.sh`._

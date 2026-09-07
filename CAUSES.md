# mere-ruby — what the gap is made of

The records in `SPEC_STATUS.md` and `mspec/tags/`, grouped by CAUSE rather
than by group. A count is a number of spec FILES. The text is the first line
where mere-ruby and ruby disagree (DIFF) or the message it aborted with
(CRASH), with paths and addresses masked.

**KIND** masks the values and keeps the shape -- this is the column that says
what to work on. **CAUSE** is the line as recorded, for reproducing one.

Regenerate with `./mspec/causes.sh` (reads `mspec/tags/`, no sweep).

Classified: 234 files.

## DIFF — 234 files, 89 kinds

| files | kind |
|---|---|
| 25 | `ERROR NoMethodError` |
| 12 | `FAILED expected N, got N` |
| 11 | `FAILED expected TypeError to be raised` |
| 10 | `FAILED expected false, got true` |
| 10 | `FAILED expected ArgumentError to be raised` |
| 10 | `ERROR NameError` |
| 9 | `FAILED expected true, got false` |
| 9 | `FAILED expected to be identical` |
| 9 | `FAILED expected "S", got "S"` |
| 6 | `FAILED expected N, got nil` |
| 6 | `ERROR TypeError` |
| 5 | `ERROR ArgumentError` |
| 4 | `FAILED raised NoMethodError, expected TypeError` |
| 4 | `FAILED expected truthy from #include?` |
| 4 | `FAILED expected NameError to be raised` |
| 4 | `FAILED expected #<OBJ>, got #<OBJ>` |
| 4 | `FAILED expected "S", got nil` |
| 3 | `FAILED expected nil, got "S"` |
| 3 | `FAILED expected SyntaxError to be raised` |
| 3 | `FAILED expected NoMethodError to be raised` |
| 3 | `FAILED expected "S" to match` |
| 3 | `ERROR RangeError` |
| 2 | `pass=N fail=N err=N` |
| 2 | `FAILED raised NoMethodError, expected SignalException` |
| 2 | `FAILED expected not to be identical` |
| 2 | `FAILED expected nil, got #<OBJ>` |
| 2 | `FAILED expected falsy from #include?` |
| 2 | `FAILED expected ThreadError to be raised` |
| 2 | `FAILED expected MethodSpecs::InheritedMethods::C, got MethodSpecs::InheritedMethods::B` |
| 2 | `FAILED expected LocalJumpError to be raised` |
| 2 | `ERROR StandardError` |
| 2 | `ERROR RuntimeError` |
| 1 | `sh: feature_N: command not found` |
| 1 | `FAILED raised StandardError, expected ZeroDivisionError` |
| 1 | `FAILED raised NoMethodError, expected ZeroDivisionError` |
| 1 | `FAILED raised NoMethodError, expected FrozenError` |
| 1 | `FAILED raised FrozenError, expected TypeError` |
| 1 | `FAILED raised ArgumentError, expected SyntaxError` |
| 1 | `FAILED raised ArgumentError, expected IndexError` |
| 1 | `FAILED matcher did not match #<OBJ>` |
| 1 | `FAILED expected {N => N}, got {}` |
| 1 | `FAILED expected {...}, got {...}` |
| 1 | `FAILED expected truthy from #start_with?` |
| 1 | `FAILED expected truthy from #finite?` |
| 1 | `FAILED expected truthy from #>` |
| 1 | `FAILED expected truthy from #<=` |
| 1 | `FAILED expected truthy from #<` |
| 1 | `FAILED expected true, got nil` |
| 1 | `FAILED expected true, got "S"` |
| 1 | `FAILED expected nil, got false` |
| 1 | `FAILED expected falsy from #start_with?` |
| 1 | `FAILED expected a Integer, got N` |
| 1 | `FAILED expected a Complex, got N` |
| 1 | `FAILED expected [[N, [N]], [N, [N, N]], [N, [N]]], got [[N, [N]], [:SYM, [N]], [N, [N, N]], [:SYM, [N]], [N, [N]]]` |
| 1 | `FAILED expected [[:SYM]], got []` |
| 1 | `FAILED expected [[:SYM], [:SYM]], got [[:SYM, :SYM], [:SYM, :SYM]]` |
| 1 | `FAILED expected [N], got [N]` |
| 1 | `FAILED expected [N, N, [N], {x: N}, N, {}], got [[N, N, N, {x: N}], N, [], nil, N, {}]` |
| 1 | `FAILED expected [N, N, N, N, N, N], got [N, N, N, N, N, N]` |
| 1 | `FAILED expected [N, N, N, N, N, N, N, N, N], got [N, N, N, N, N, N, N, N, N, N]` |
| 1 | `FAILED expected [:SYM], got :SYM` |
| 1 | `FAILED expected [:SYM, :SYM, :SYM, :SYM, :SYM, :SYM], got [:SYM, :SYM, :SYM, :SYM, :SYM]` |
| 1 | `FAILED expected ["S", "S", "S"], got ["S", "S"]` |
| 1 | `FAILED expected ["S", "S", "S", "S"], got ["S", "S", "S", "S"]` |
| 1 | `FAILED expected ["S", "S", "S", "S", "S", "S", "S", "S"], got ["S", "S", "S", "S", "S"]` |
| 1 | `FAILED expected ZeroDivisionError to be raised` |
| 1 | `FAILED expected RangeError to be raised` |
| 1 | `FAILED expected N, got NaN` |
| 1 | `FAILED expected N, got (N+Ni)` |
| 1 | `FAILED expected IndexError to be raised` |
| 1 | `FAILED expected Errno::EINVAL to be raised` |
| 1 | `FAILED expected Encoding::CompatibilityError to be raised` |
| 1 | `FAILED expected :SYM, got nil` |
| 1 | `FAILED expected :SYM, got :SYM` |
| 1 | `FAILED expected (N/N), got N` |
| 1 | `FAILED expected #<OBJ>, got nil` |
| 1 | `FAILED expected "\e[NmTraceback\e[m (most recent call last):` |
| 1 | `FAILED expected "S"localhost\"S"root\"S", got "S"localhost\"S"root\"S"` |
| 1 | `FAILED expected "S"\xN\"S", got "S"N\"S"` |
| 1 | `FAILED expected "S"\uN\"S", got "S"` |
| 1 | `FAILED expected "S"\"S", got "S"` |
| 1 | `FAILED expected "S", got N` |
| 1 | `FAILED expected "S", got "S"\"S"` |
| 1 | `FAILED expected "` |
| 1 | `Exception 'S' at /privateTMPDIR - uninitialized constant IOStub` |
| 1 | `ERROR SystemStackError` |
| 1 | `ERROR SystemExit` |
| 1 | `ERROR SyntaxError` |
| 1 | `ERROR Errno::ENOENT` |

<details><summary>the same rows by exact cause (top 40)</summary>

| files | cause |
|---|---|
| 11 | `FAILED: expected TypeError to be raised` |
| 10 | `FAILED: expected ArgumentError to be raised` |
| 4 | `FAILED: raised NoMethodError, expected TypeError` |
| 4 | `FAILED: expected NameError to be raised` |
| 3 | `FAILED: expected SyntaxError to be raised` |
| 3 | `FAILED: expected NoMethodError to be raised` |
| 2 | `FAILED: transcodes from the locale encoding to Encoding.default_internal if set: expected to be identical` |
| 2 | `FAILED: sets the encoding to the encoding of the source String: expected to be identical` |
| 2 | `FAILED: returns the class on which public was called for a private method in ancestor: expected MethodSpecs::InheritedMethods::C, got MethodSpecs::InheritedMethods::B` |
| 2 | `FAILED: returns self: expected to be identical` |
| 2 | `FAILED: returns -1: expected -1, got -4` |
| 2 | `FAILED: raised NoMethodError, expected SignalException` |
| 2 | `FAILED: is a private method: expected truthy from #include?` |
| 2 | `FAILED: is a private method only when -n is passed: expected falsy from #include?` |
| 2 | `FAILED: expected ThreadError to be raised` |
| 2 | `FAILED: expected LocalJumpError to be raised` |
| 2 | `FAILED: duplicates the range: expected not to be identical` |
| 2 | `FAILED: deletes pairs through enumerator: expected nil, got "0"` |
| 2 | `ERROR: when given an argument and no block doesn't yield an empty array if the filter matches the first entry or the last entry: NoMethodError` |
| 1 | `sh: feature_14386: command not found` |
| 1 | `pass=4 fail=2 err=7` |
| 1 | `pass=16 fail=0 err=0` |
| 1 | `FAILED: yields while increasing self until it is greater than floor of a Float endpoint: expected [9, 10, 11, 12, 13, -5, -4, -3, -2], got [9, 10, 11, 12, 13, -5, -4, -3, -2, -1]` |
| 1 | `FAILED: yields elements to the provided block: expected [6, 5, 4, 3, 2, 1], got [1, 2, 3, 4, 5, 6]` |
| 1 | `FAILED: wraps the lock/unlock pair in an ensure: expected true, got false` |
| 1 | `FAILED: uses non-e format for a positive value with whole part having 15 significant figures: expected "10000000000000.0", got "1.0e+13"` |
| 1 | `FAILED: uses class name when receiver has a singleton class: expected "undefined method 'bar' for an instance of NoMethodErrorSpecs::NoMethodErrorA" to match` |
| 1 | `FAILED: upgrades the encoding to that of an embedded String: expected #<Encoding:EUC-JP>, got #<Encoding:UTF-8>` |
| 1 | `FAILED: takes matching position as the 2nd argument: expected false, got true` |
| 1 | `FAILED: supports :highlight option and adds escape sequences to highlight some strings: expected "\e[1mTraceback\e[m (most recent call last):` |
| 1 | `FAILED: sets the first element of each sub-Array to :req for required argument if lambda keyword used: expected :req, got :opt` |
| 1 | `FAILED: sets regexp matches in the caller: expected ["w", "a", "w", "a"], got ["a", "a", "a", "a"]` |
| 1 | `FAILED: sets $~ in the block: expected nil, got #<MatchData "e">` |
| 1 | `FAILED: sets $~ in the block: expected "b", got nil` |
| 1 | `FAILED: selects via the enumerator: expected nil, got "bar"` |
| 1 | `FAILED: samples evenly: expected truthy from #<=` |
| 1 | `FAILED: returns true when self's imaginary part is 0 and the real part and other have numerical equality: expected 3.5, got (3.5+0i)` |
| 1 | `FAILED: returns true if the Regexp was created with the Regexp::FIXEDENCODING option: expected true, got false` |
| 1 | `FAILED: returns true if magnitude is finite: expected truthy from #finite?` |
| 1 | `FAILED: returns true if a method was defined using the other one: expected true, got false` |

</details>

## The absent names

Files whose FIRST divergence is NoMethodError or NameError, keyed by the
method the spec file is named for. Not every row is a missing method --
a spec can raise NoMethodError from a helper -- but most are, and the
class column says where the weight sits.

| class | absent names (from the spec filenames) |
|---|---|
| kernel (7) | `binding eval lambda loop method select test` |
| enumerable (6) | `inject one slice_after slice_before to_h zip` |
| unboundmethod (4) | `bind_call bind original_name super_method` |
| language (4) | `alias constants module numbered_parameters` |
| method (3) | `original_name super_method to_proc` |
| exception (3) | `backtrace_locations backtrace exception` |
| struct (2) | `deconstruct initialize` |
| numeric (2) | `integer real` |
| threadgroup (1) | `list` |
| symbol (1) | `all_symbols` |
| regexp (1) | `timeout` |
| proc (1) | `new` |

_Generated by `mspec/causes.sh`._

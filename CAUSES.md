# mere-ruby — what the gap is made of

The records in `SPEC_STATUS.md` and `mspec/tags/`, grouped by CAUSE rather
than by group. A count is a number of spec FILES. The text is the first line
where mere-ruby and ruby disagree (DIFF) or the message it aborted with
(CRASH), with paths and addresses masked.

**KIND** masks the values and keeps the shape -- this is the column that says
what to work on. **CAUSE** is the line as recorded, for reproducing one.

Regenerate with `./mspec/causes.sh` (reads `mspec/tags/`, no sweep).

Classified: 165 files.

## DIFF — 165 files, 79 kinds

| files | kind |
|---|---|
| 19 | `ERROR NoMethodError` |
| 10 | `FAILED expected N, got N` |
| 8 | `ERROR NameError` |
| 7 | `FAILED expected to be identical` |
| 7 | `FAILED expected false, got true` |
| 6 | `FAILED expected TypeError to be raised` |
| 6 | `FAILED expected "S", got "S"` |
| 5 | `FAILED expected true, got false` |
| 5 | `FAILED expected ArgumentError to be raised` |
| 5 | `ERROR TypeError` |
| 4 | `FAILED expected truthy from #include?` |
| 4 | `FAILED expected #<OBJ>, got #<OBJ>` |
| 3 | `FAILED expected nil, got "S"` |
| 3 | `FAILED expected "S", got nil` |
| 2 | `pass=N fail=N err=N` |
| 2 | `FAILED raised NoMethodError, expected SignalException` |
| 2 | `FAILED expected not to be identical` |
| 2 | `FAILED expected ThreadError to be raised` |
| 2 | `FAILED expected N, got nil` |
| 2 | `FAILED expected "S" to match` |
| 2 | `ERROR RangeError` |
| 2 | `ERROR ArgumentError` |
| 1 | `sh: feature_N: command not found` |
| 1 | `FAILED raised NoMethodError, expected TypeError` |
| 1 | `FAILED raised NoMethodError, expected FrozenError` |
| 1 | `FAILED raised FrozenError, expected TypeError` |
| 1 | `FAILED raised ArgumentError, expected SyntaxError` |
| 1 | `FAILED raised ArgumentError, expected IndexError` |
| 1 | `FAILED matcher did not match #<OBJ>` |
| 1 | `FAILED expected {...}, got {...}` |
| 1 | `FAILED expected {#<OBJ> => N}, got {}` |
| 1 | `FAILED expected truthy from #start_with?` |
| 1 | `FAILED expected truthy from #>` |
| 1 | `FAILED expected truthy from #<=` |
| 1 | `FAILED expected truthy from #<` |
| 1 | `FAILED expected true, got nil` |
| 1 | `FAILED expected true, got "S"` |
| 1 | `FAILED expected not N` |
| 1 | `FAILED expected nil, got false` |
| 1 | `FAILED expected nil, got N` |
| 1 | `FAILED expected nil, got #<OBJ>` |
| 1 | `FAILED expected a Float, got nil` |
| 1 | `FAILED expected [[:SYM, :SYM], [:SYM, :SYM], [:SYM, :SYM], [:SYM, :SYM], [:SYM, :SYM], [:SYM, :SYM], [:SYM, :SYM], [:SYM, :SYM]], got [[:SYM, :SYM], [:SYM, :SYM], [:SYM, :SYM], [:SYM, :SYM], [:SYM, : ...[clipped]` |
| 1 | `FAILED expected [[:SYM, :*], [:SYM, :**], [:SYM, :&]], got [[:SYM, :SYM], [:SYM, :&]]` |
| 1 | `FAILED expected [N], got [N]` |
| 1 | `FAILED expected [N, N, [N], {x: N}, N, {}], got [[N, N, N, {x: N}], N, [], nil, N, {}]` |
| 1 | `FAILED expected [N, N, N, N, N, N, N, N, N], got [N, N, N, N, N, N, N, N, N, N]` |
| 1 | `FAILED expected [N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, ...[clipped]` |
| 1 | `FAILED expected [:SYM], got :SYM` |
| 1 | `FAILED expected [:SYM, :SYM, :SYM, :SYM, :SYM, :SYM], got [:SYM, :SYM, :SYM, :SYM, :SYM]` |
| 1 | `FAILED expected ["S", "S"], got ["S", "S"]` |
| 1 | `FAILED expected ["S", "S", "S"], got ["S", "S"]` |
| 1 | `FAILED expected ["S", "S", "S", "S"], got ["S", "S", "S", "S"]` |
| 1 | `FAILED expected ["S", "S", "S", "S", "S", "S", "S", "S"], got ["S", "S", "S", "S", "S"]` |
| 1 | `FAILED expected ZeroDivisionError to be raised` |
| 1 | `FAILED expected SyntaxError to be raised` |
| 1 | `FAILED expected RangeError to be raised` |
| 1 | `FAILED expected NoMethodError to be raised` |
| 1 | `FAILED expected NameError to be raised` |
| 1 | `FAILED expected N, got NaN` |
| 1 | `FAILED expected IndexError to be raised` |
| 1 | `FAILED expected Errno::EINVAL to be raised` |
| 1 | `FAILED expected Encoding::CompatibilityError to be raised` |
| 1 | `FAILED expected :SYM, got nil` |
| 1 | `FAILED expected (N/N), got N` |
| 1 | `FAILED expected #<OBJ>, got nil` |
| 1 | `FAILED expected #<Method: KernelSpecs::A#pub_method() TMPDIR got #<Method: KernelSpecs::B#aliased_pub_method() TMPDIR` |
| 1 | `FAILED expected "\e[NmTraceback\e[m (most recent call last):` |
| 1 | `FAILED expected "S"foo\xAN\"S", got "S"` |
| 1 | `FAILED expected "S"\uN\"S", got "S"` |
| 1 | `FAILED expected "S", got N` |
| 1 | `FAILED expected "` |
| 1 | `Exception 'S' at /privateTMPDIR - uninitialized constant IOStub` |
| 1 | `ERROR ZeroDivisionError` |
| 1 | `ERROR SystemStackError` |
| 1 | `ERROR SystemExit` |
| 1 | `ERROR SyntaxError` |
| 1 | `ERROR StandardError` |
| 1 | `ERROR RuntimeError` |

<details><summary>the same rows by exact cause (top 40)</summary>

| files | cause |
|---|---|
| 6 | `FAILED: expected TypeError to be raised` |
| 5 | `FAILED: expected ArgumentError to be raised` |
| 2 | `pass=16 fail=0 err=0` |
| 2 | `FAILED: transcodes from the locale encoding to Encoding.default_internal if set: expected to be identical` |
| 2 | `FAILED: sets the encoding to the encoding of the source String: expected to be identical` |
| 2 | `FAILED: returns -1: expected -1, got -4` |
| 2 | `FAILED: raised NoMethodError, expected SignalException` |
| 2 | `FAILED: is a private method: expected truthy from #include?` |
| 2 | `FAILED: expected ThreadError to be raised` |
| 2 | `FAILED: duplicates the range: expected not to be identical` |
| 2 | `FAILED: deletes pairs through enumerator: expected nil, got "0"` |
| 1 | `sh: feature_14386: command not found` |
| 1 | `FAILED: yields while increasing self until it is greater than floor of a Float endpoint: expected [9, 10, 11, 12, 13, -5, -4, -3, -2], got [9, 10, 11, 12, 13, -5, -4, -3, -2, -1]` |
| 1 | `FAILED: wraps the lock/unlock pair in an ensure: expected true, got false` |
| 1 | `FAILED: will see an alias of the original method as == when in a derived class: expected #<Method: KernelSpecs::A#pub_method() TMPDIR got #<Method: KernelSpecs::B#aliased_pub_method() TMPDIR` |
| 1 | `FAILED: uses non-e format for a positive value with whole part having 15 significant figures: expected "10000000000000.0", got "1.0e+13"` |
| 1 | `FAILED: upgrades the encoding to that of an embedded String: expected #<Encoding:EUC-JP>, got #<Encoding:UTF-8>` |
| 1 | `FAILED: tries to convert a key with #to_int if index is not a String nor a Symbol, but responds to #to_int: expected {#<MockObject to_int> => 2}, got {}` |
| 1 | `FAILED: treats the block as a Proc when lambda is re-defined: expected 1, got 2` |
| 1 | `FAILED: tolerates increasing a collection size during iterating Array: expected [0, 1, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 2, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 3, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 4, 40, 41, 42, 43, 44, 45, ...[clipped]` |
| 1 | `FAILED: supports :highlight option and adds escape sequences to highlight some strings: expected "\e[1mTraceback\e[m (most recent call last):` |
| 1 | `FAILED: sets regexp matches in the caller: expected ["w", "a", "w", "a"], got ["a", "a", "a", "a"]` |
| 1 | `FAILED: selects via the enumerator: expected nil, got "bar"` |
| 1 | `FAILED: samples evenly: expected truthy from #<=` |
| 1 | `FAILED: returns true if the Regexp was created with the Regexp::FIXEDENCODING option: expected true, got false` |
| 1 | `FAILED: returns the status of the lock: expected false, got true` |
| 1 | `FAILED: returns the remainder of dividing self by other: expected (2/1), got 0.0` |
| 1 | `FAILED: returns the previous seed value: expected 10, got 0` |
| 1 | `FAILED: returns the nearest Integer for Float near the limit: expected 0, got 1` |
| 1 | `FAILED: returns self divided by other: expected 4611686018427387926, got 4611686018427387904` |
| 1 | `FAILED: returns nil when comparing characters with different encodings: expected nil, got false` |
| 1 | `FAILED: returns mutable copy of a literal: expected false, got true` |
| 1 | `FAILED: returns matches in the String's encoding: expected #<Encoding:EUC-JP>, got #<Encoding:UTF-8>` |
| 1 | `FAILED: returns from the lambda: expected [:a, :d, :aaa, :b, :bbb, :e], got [:a, :d, :aaa, :b, :e]` |
| 1 | `FAILED: returns false when a method defined by define_method is called with a block: expected false, got true` |
| 1 | `FAILED: returns false if compares with near float: expected false, got true` |
| 1 | `FAILED: returns false if both have same Module, same name, identical body but not the same: expected false, got true` |
| 1 | `FAILED: returns an Enumerator if called without a block: expected to be identical` |
| 1 | `FAILED: returns an Array that can be updated: expected "backtrace first", got "TMPDIR 'Object#it'"` |
| 1 | `FAILED: returns an Array of caller locations using a custom offset: expected "TMPDIR 'Object#describe'" to match` |

</details>

## The absent names

Files whose FIRST divergence is NoMethodError or NameError, keyed by the
method the spec file is named for. Not every row is a missing method --
a spec can raise NoMethodError from a helper -- but most are, and the
class column says where the weight sits.

| class | absent names (from the spec filenames) |
|---|---|
| kernel (9) | `binding chomp chop eval loop open select singleton_class test` |
| language (4) | `alias constants module numbered_parameters` |
| unboundmethod (3) | `bind_call bind super_method` |
| method (3) | `equal_value super_method to_proc` |
| symbol (2) | `all_symbols to_proc` |
| threadgroup (1) | `list` |
| struct (1) | `new` |
| regexp (1) | `timeout` |
| proc (1) | `new` |
| exception (1) | `interrupt` |
| enumerable (1) | `to_h` |

_Generated by `mspec/causes.sh`._

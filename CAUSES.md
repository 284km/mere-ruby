# mere-ruby — what the gap is made of

The records in `SPEC_STATUS.md` and `mspec/tags/`, grouped by CAUSE rather
than by group. A count is a number of spec FILES. The text is the first line
where mere-ruby and ruby disagree (DIFF) or the message it aborted with
(CRASH), with paths and addresses masked.

**KIND** masks the values and keeps the shape -- this is the column that says
what to work on. **CAUSE** is the line as recorded, for reproducing one.

Regenerate with `./mspec/causes.sh` (reads `mspec/tags/`, no sweep).

Classified: 371 files.

## CRASH — 21 files, 13 kinds

| files | kind |
|---|---|
| 4 | `(no output before aborting)` |
| 3 | `stack overflow (recursion too deep)` |
| 2 | `ERROR StandardError` |
| 2 | `*.rb:N: mere-ruby: expected end of statement in TMPDIR near line N` |
| 2 | `*.rb:N: mere-ruby: expected block in TMPDIR near line N` |
| 1 | `ERROR NoMethodError` |
| 1 | `*.rb:N: wrong number of arguments (given N, expected N) (ArgumentError)` |
| 1 | `*.rb:N: uninitialized constant Enumerator::ArithmeticSequence (NameError)` |
| 1 | `*.rb:N: uninitialized constant CS_SINGLETONN_CLASSES (NameError)` |
| 1 | `*.rb:N: undefined method 'S' for an instance of Object (NoMethodError)` |
| 1 | `*.rb:N: mere-ruby: unterminated string in TMPDIR near line N` |
| 1 | `*.rb:N: mere-ruby: undefined method 'S' for class KernelSpecs::CalleeTest` |
| 1 | `*.rb:N: mere-ruby: undefined method 'S' for class DefineSingletonMethodSpecClass` |

<details><summary>the same rows by exact cause (top 40)</summary>

| files | cause |
|---|---|
| 4 | `(no output before aborting)` |
| 3 | `stack overflow (recursion too deep)` |
| 1 | `ERROR: when m is a bignum or larger than int returns 0 when m > 0 and n >= 0: StandardError` |
| 1 | `ERROR: when m is a bignum or larger than int returns 0 when m < 0 and n >= 0: StandardError` |
| 1 | `ERROR: rescuing SignalException raises a SignalException when sent a signal: NoMethodError` |
| 1 | `*.rb:N: wrong number of arguments (given 1, expected 0) (ArgumentError)` |
| 1 | `*.rb:N: uninitialized constant Enumerator::ArithmeticSequence (NameError)` |
| 1 | `*.rb:N: uninitialized constant CS_SINGLETON4_CLASSES (NameError)` |
| 1 | `*.rb:N: undefined method 'each' for an instance of Object (NoMethodError)` |
| 1 | `*.rb:N: mere-ruby: unterminated string in TMPDIR near line 645` |
| 1 | `*.rb:N: mere-ruby: undefined method 'define_singleton_method' for class DefineSingletonMethodSpecClass` |
| 1 | `*.rb:N: mere-ruby: undefined method '__callee__' for class KernelSpecs::CalleeTest` |
| 1 | `*.rb:N: mere-ruby: expected end of statement in TMPDIR near line 66` |
| 1 | `*.rb:N: mere-ruby: expected end of statement in TMPDIR near line 334` |
| 1 | `*.rb:N: mere-ruby: expected block in TMPDIR near line 51` |
| 1 | `*.rb:N: mere-ruby: expected block in TMPDIR near line 35` |

</details>

## DIFF — 350 files, 103 kinds

| files | kind |
|---|---|
| 60 | `ERROR NoMethodError` |
| 23 | `ERROR NameError` |
| 19 | `FAILED expected N, got N` |
| 19 | `ERROR StandardError` |
| 14 | `FAILED expected true, got false` |
| 12 | `FAILED expected to be identical` |
| 12 | `FAILED expected ArgumentError to be raised` |
| 11 | `FAILED expected TypeError to be raised` |
| 8 | `FAILED expected #<OBJ>, got #<OBJ>` |
| 8 | `ERROR ArgumentError` |
| 7 | `FAILED expected truthy from #include?` |
| 7 | `FAILED expected false, got true` |
| 7 | `FAILED expected "S", got "S"` |
| 6 | `pass=N fail=N err=N` |
| 6 | `FAILED expected N, got nil` |
| 5 | `FAILED raised NoMethodError, expected RangeError` |
| 4 | `FAILED expected nil, got "S"` |
| 4 | `FAILED expected "S", got nil` |
| 3 | `FAILED raised StandardError, expected ZeroDivisionError` |
| 3 | `FAILED expected not N` |
| 3 | `FAILED expected falsy from #include?` |
| 3 | `FAILED expected SyntaxError to be raised` |
| 3 | `FAILED expected LocalJumpError to be raised` |
| 3 | `FAILED expected :SYM, got nil` |
| 3 | `FAILED expected "S" to match` |
| 3 | `ERROR TypeError` |
| 2 | `FAILED raised NoMethodError, expected SignalException` |
| 2 | `FAILED raised NoMethodError, expected ArgumentError` |
| 2 | `FAILED raised NameError, expected TypeError` |
| 2 | `FAILED expected not to be identical` |
| 2 | `FAILED expected nil, got N` |
| 2 | `FAILED expected ZeroDivisionError to be raised` |
| 2 | `FAILED expected ThreadError to be raised` |
| 2 | `FAILED expected RangeError to be raised` |
| 2 | `FAILED expected NoMethodError to be raised` |
| 2 | `FAILED expected NameError to be raised` |
| 2 | `FAILED expected N, got NaN` |
| 2 | `FAILED expected N ...[clipped]` |
| 2 | `FAILED expected :SYM, got :SYM` |
| 2 | `FAILED expected (N/N), got (N/N)` |
| 2 | `FAILED expected #<OBJ>, got nil` |
| 2 | `ERROR SystemStackError` |
| 2 | `ERROR RuntimeError` |
| 1 | `sh: feature_N: command not found` |
| 1 | `FAILED raised StandardError, expected TypeError` |
| 1 | `FAILED raised StandardError, expected ArgumentError` |
| 1 | `FAILED raised RuntimeError, expected NoMethodError` |
| 1 | `FAILED raised NoMethodError, expected ZeroDivisionError` |
| 1 | `FAILED raised NoMethodError, expected TypeError` |
| 1 | `FAILED raised NameError, expected ArgumentError` |
| 1 | `FAILED matcher did not match N` |
| 1 | `FAILED expected {:SYM=>[N, N, N]}, got nil` |
| 1 | `FAILED expected {:SYM=>N}, got {}` |
| 1 | `FAILED expected {#<OBJ>=>"S", #<OBJ>=>"S"}, got {}` |
| 1 | `FAILED expected {"S"=>N, "S"=>N}, got {}` |
| 1 | `FAILED expected {"S"=>"S", "S"=>"S"}, got {"S"=>"S", "S"=>nil}` |
| 1 | `FAILED expected {"S"=>"S", "S"=>"S", "S"=>"S"}, got {:SYM=>"S", :SYM=>"S", :SYM=>nil}` |
| 1 | `FAILED expected truthy from #lambda?` |
| 1 | `FAILED expected truthy from #finite?` |
| 1 | `FAILED expected truthy from #>=` |
| 1 | `FAILED expected truthy from #>` |
| 1 | `FAILED expected truthy from #<=` |
| 1 | `FAILED expected truthy from #<` |
| 1 | `FAILED expected true, got nil` |
| 1 | `FAILED expected true, got "S"` |
| 1 | `FAILED expected a Integer, got N` |
| 1 | `FAILED expected a Complex, got N` |
| 1 | `FAILED expected a #<OBJ>>, got #<OBJ>` |
| 1 | `FAILED expected [], got nil` |
| 1 | `FAILED expected [], got [[:SYM, :"S"]]` |
| 1 | `FAILED expected [], got [:SYM, :SYM, :SYM, :SYM, :SYM]` |
| 1 | `FAILED expected [], got [:@make, :@model, :@year]` |
| 1 | `FAILED expected [[N], {:SYM=>N}, #<OBJ>], got [[N], {:SYM=>N}, #<OBJ>]` |
| 1 | `FAILED expected [N, N], got nil` |
| 1 | `FAILED expected [N, N], got []` |
| 1 | `FAILED expected [N, N], got [N, N]` |
| 1 | `FAILED expected [N, N, [N], {:SYM=>N}, N, {}], got [[N, N, N, {:SYM=>N}], N, [], nil, N, {}]` |
| 1 | `FAILED expected [N, N, N], got [#<OBJ>]` |
| 1 | `FAILED expected [N, N, N, N, N, N, N, N, N], got [N, N, N, N, N, N, N, N, N, N]` |
| 1 | `FAILED expected [#<OBJ>, {:SYM=>true}], got nil` |
| 1 | `FAILED expected ["S", "S"], got nil` |
| 1 | `FAILED expected ["S", "S"], got ["S", "S"]` |
| 1 | `FAILED expected ["S", "S", "S"], got ["S", "S", nil]` |
| 1 | `FAILED expected ["S", "S", "S", "S"], got ["S", "S", "S", "S"]` |
| 1 | `FAILED expected ["S", "S", "S", "S", "S", "S"], got ["S", "S", "S", "S", "S"]` |
| 1 | `FAILED expected N, got true` |
| 1 | `FAILED expected N, got (N+Ni)` |
| 1 | `FAILED expected N, got "S"` |
| 1 | `FAILED expected MethodSpecs::Methods, got Object` |
| 1 | `FAILED expected MethodSpecs::InheritedMethods::C, got MethodSpecs::InheritedMethods::B` |
| 1 | `FAILED expected Kernel, got Module` |
| 1 | `FAILED expected IndexError to be raised` |
| 1 | `FAILED expected (N+Ni), got (N+Ni+N+Nii)` |
| 1 | `FAILED expected #<OBJ>"S", "S"=>"S", "S"=>"cl ...[clipped]` |
| 1 | `FAILED expected "S"abc def ghi\"S"abc\"S"def\"S", got "S"abc def ghi\"S"abc\"S"def\"S"ghi\"S"` |
| 1 | `FAILED expected "S"\xN\"S", got "S"N\"S"` |
| 1 | `FAILED expected "S"\"S", got "S"` |
| 1 | `FAILED expected "S"MethodSpecs::MyMod\"S"bar\"S" to match` |
| 1 | `FAILED expected "S", got #<OBJ>` |
| 1 | `FAILED expected "S"$ruby!\"S", got "S"` |
| 1 | `ERROR SyntaxError` |
| 1 | `ERROR RangeError` |
| 1 | `ERROR Errno::ENOENT` |

<details><summary>the same rows by exact cause (top 40)</summary>

| files | cause |
|---|---|
| 12 | `FAILED: expected ArgumentError to be raised` |
| 11 | `FAILED: expected TypeError to be raised` |
| 5 | `FAILED: raised NoMethodError, expected RangeError` |
| 3 | `FAILED: raised StandardError, expected ZeroDivisionError` |
| 3 | `FAILED: expected not 0` |
| 3 | `FAILED: expected SyntaxError to be raised` |
| 3 | `FAILED: expected LocalJumpError to be raised` |
| 2 | `pass=55 fail=0 err=0` |
| 2 | `pass=52 fail=0 err=0` |
| 2 | `FAILED: transcodes from the locale encoding to Encoding.default_internal if set: expected to be identical` |
| 2 | `FAILED: sets the encoding to the encoding of the source String: expected to be identical` |
| 2 | `FAILED: returns the original name even when aliased twice: expected :foo, got :bar` |
| 2 | `FAILED: returns self: expected to be identical` |
| 2 | `FAILED: returns -1: expected -1, got -4` |
| 2 | `FAILED: raised NoMethodError, expected SignalException` |
| 2 | `FAILED: raised NoMethodError, expected ArgumentError` |
| 2 | `FAILED: raised NameError, expected TypeError` |
| 2 | `FAILED: is a private method: expected truthy from #include?` |
| 2 | `FAILED: is a private method only when -n is passed: expected falsy from #include?` |
| 2 | `FAILED: includes Comparable: expected true, got false` |
| 2 | `FAILED: expected ZeroDivisionError to be raised` |
| 2 | `FAILED: expected ThreadError to be raised` |
| 2 | `FAILED: expected RangeError to be raised` |
| 2 | `FAILED: expected NoMethodError to be raised` |
| 2 | `FAILED: expected NameError to be raised` |
| 2 | `FAILED: duplicates the range: expected not to be identical` |
| 2 | `FAILED: deletes pairs through enumerator: expected nil, got "0"` |
| 2 | `ERROR: bignum coerces the RHS and calls #coerce even if it's private: TypeError` |
| 1 | `sh: feature_14386: command not found` |
| 1 | `pass=157 fail=0 err=0` |
| 1 | `pass=110 fail=0 err=0` |
| 1 | `FAILED: yields while increasing self until it is greater than floor of a Float endpoint: expected [9, 10, 11, 12, 13, -5, -4, -3, -2], got [9, 10, 11, 12, 13, -5, -4, -3, -2, -1]` |
| 1 | `FAILED: writer method be a synonym for []=: expected "F150", got nil` |
| 1 | `FAILED: wraps the lock/unlock pair in an ensure: expected true, got false` |
| 1 | `FAILED: uses non-e format for a positive value with whole part having 15 significant figures: expected "10000000000000.0", got "1.0e+13"` |
| 1 | `FAILED: the String shows the method name, Module defined in and Module extracted from: expected "#<UnboundMethod:0xADDR>" to match` |
| 1 | `FAILED: sets regexp matches in the caller: expected ["w", "a", "w", "a"], got ["a", "a", "a", "a"]` |
| 1 | `FAILED: selects via the enumerator: expected nil, got "bar"` |
| 1 | `FAILED: samples evenly: expected truthy from #<=` |
| 1 | `FAILED: returns true: expected true, got false` |

</details>

## The absent names

Files whose FIRST divergence is NoMethodError or NameError, keyed by the
method the spec file is named for. Not every row is a missing method --
a spec can raise NoMethodError from a helper -- but most are, and the
class column says where the weight sits.

| class | absent names (from the spec filenames) |
|---|---|
| kernel (18) | `__method__ binding fail format initialize_clone initialize_copy initialize_dup instance_variable_get lambda loop method private_methods protected_methods public_send respond_to_missing select test warn` |
| integer (10) | `ceildiv div gcd ord pred remainder round size succ try_convert` |
| matchdata (9) | `byteoffset deconstruct_keys deconstruct dup equal_value length match_length match regexp` |
| exception (8) | `backtrace_locations backtrace errno exception interrupt io_error signal_exception system_call_error` |
| proc (7) | `binding case_compare curry element_reference new to_proc yield` |
| method (7) | `case_compare clone curry element_reference source_location super_method to_proc` |
| struct (6) | `deconstruct element_reference element_set filter keyword_init new` |
| symbol (5) | `all_symbols intern match name slice` |
| unboundmethod (4) | `bind_call clone source_location super_method` |
| rational (4) | `divide minus multiply plus` |
| language (3) | `alias metaclass module` |
| numeric (2) | `integer real` |
| threadgroup (1) | `list` |
| range (1) | `step` |

_Generated by `mspec/causes.sh`._

# mere-ruby — what the gap is made of

The records in `SPEC_STATUS.md` and `mspec/tags/`, grouped by CAUSE rather
than by group. A count is a number of spec FILES. The text is the first line
where mere-ruby and ruby disagree (DIFF) or the message it aborted with
(CRASH), with paths and addresses masked.

**KIND** masks the values and keeps the shape -- this is the column that says
what to work on. **CAUSE** is the line as recorded, for reproducing one.

Regenerate with `./mspec/causes.sh` (reads `mspec/tags/`, no sweep).

Classified: 610 files.

## CRASH — 22 files, 13 kinds

| files | kind |
|---|---|
| 5 | `stack overflow (recursion too deep)` |
| 4 | `(no output before aborting)` |
| 2 | `ERROR StandardError` |
| 2 | `*.rb:N: mere-ruby: expected end of statement in TMPDIR near line N` |
| 1 | `FAILED expected "S", got "S"` |
| 1 | `ERROR NoMethodError` |
| 1 | `*.rb:N: wrong number of arguments (given N, expected N) (ArgumentError)` |
| 1 | `*.rb:N: uninitialized constant Enumerator::ArithmeticSequence (NameError)` |
| 1 | `*.rb:N: uninitialized constant CS_SINGLETONN_CLASSES (NameError)` |
| 1 | `*.rb:N: mere-ruby: unterminated string in TMPDIR near line N` |
| 1 | `*.rb:N: mere-ruby: unexpected end of input in TMPDIR near line N` |
| 1 | `*.rb:N: mere-ruby: undefined method 'S' for class KernelSpecs::CalleeTest` |
| 1 | `*.rb:N: mere-ruby: undefined method 'S' for class DefineSingletonMethodSpecClass` |

<details><summary>the same rows by exact cause (top 40)</summary>

| files | cause |
|---|---|
| 5 | `stack overflow (recursion too deep)` |
| 4 | `(no output before aborting)` |
| 1 | `FAILED: supports float formats using %e: expected "9.000000e+00", got "%*e"` |
| 1 | `ERROR: when m is a bignum or larger than int returns 0 when m > 0 and n >= 0: StandardError` |
| 1 | `ERROR: when m is a bignum or larger than int returns 0 when m < 0 and n >= 0: StandardError` |
| 1 | `ERROR: rescuing SignalException raises a SignalException when sent a signal: NoMethodError` |
| 1 | `*.rb:N: wrong number of arguments (given 1, expected 0) (ArgumentError)` |
| 1 | `*.rb:N: uninitialized constant Enumerator::ArithmeticSequence (NameError)` |
| 1 | `*.rb:N: uninitialized constant CS_SINGLETON4_CLASSES (NameError)` |
| 1 | `*.rb:N: mere-ruby: unterminated string in TMPDIR near line 622` |
| 1 | `*.rb:N: mere-ruby: unexpected end of input in TMPDIR near line 91` |
| 1 | `*.rb:N: mere-ruby: undefined method 'define_singleton_method' for class DefineSingletonMethodSpecClass` |
| 1 | `*.rb:N: mere-ruby: undefined method '__callee__' for class KernelSpecs::CalleeTest` |
| 1 | `*.rb:N: mere-ruby: expected end of statement in TMPDIR near line 66` |
| 1 | `*.rb:N: mere-ruby: expected end of statement in TMPDIR near line 334` |

</details>

## DIFF — 588 files, 124 kinds

| files | kind |
|---|---|
| 111 | `ERROR NoMethodError` |
| 68 | `ERROR NameError` |
| 29 | `FAILED expected #<OBJ>, got #<OBJ>` |
| 29 | `ERROR StandardError` |
| 28 | `FAILED expected "S", got "S"` |
| 26 | `ERROR ArgumentError` |
| 24 | `FAILED expected TypeError to be raised` |
| 23 | `FAILED expected true, got false` |
| 23 | `FAILED expected ArgumentError to be raised` |
| 21 | `FAILED expected N, got N` |
| 17 | `FAILED expected N, got nil` |
| 16 | `FAILED expected to be identical` |
| 12 | `FAILED expected false, got true` |
| 6 | `FAILED expected "S", got nil` |
| 6 | `ERROR TypeError` |
| 5 | `pass=N fail=N err=N` |
| 5 | `FAILED raised NoMethodError, expected RangeError` |
| 5 | `FAILED expected not N` |
| 4 | `FAILED expected LocalJumpError to be raised` |
| 3 | `FAILED raised NoMethodError, expected ArgumentError` |
| 3 | `FAILED matcher did not match #<OBJ>` |
| 3 | `FAILED expected [N, N, N, N], got []` |
| 3 | `FAILED expected SyntaxError to be raised` |
| 3 | `FAILED expected NoMethodError to be raised` |
| 2 | `FAILED raised StandardError, expected ZeroDivisionError` |
| 2 | `FAILED raised NoMethodError, expected TypeError` |
| 2 | `FAILED raised NoMethodError, expected SignalException` |
| 2 | `FAILED raised NameError, expected TypeError` |
| 2 | `FAILED expected nil, got N` |
| 2 | `FAILED expected ["S", "S"], got nil` |
| 2 | `FAILED expected ["S", "S", "S"], got ["S", "S", "S"]` |
| 2 | `FAILED expected ZeroDivisionError to be raised` |
| 2 | `FAILED expected ThreadError to be raised` |
| 2 | `FAILED expected RangeError to be raised` |
| 2 | `FAILED expected NameError to be raised` |
| 2 | `FAILED expected N, got NaN` |
| 2 | `FAILED expected "S" to match` |
| 2 | `ERROR SystemStackError` |
| 2 | `ERROR FrozenError` |
| 1 | `sh: feature_N: command not found` |
| 1 | `FAILED raised StandardError, expected TypeError` |
| 1 | `FAILED raised StandardError, expected IndexError` |
| 1 | `FAILED raised StandardError, expected ArgumentError` |
| 1 | `FAILED raised RuntimeError, expected NoMethodError` |
| 1 | `FAILED raised NoMethodError, expected ZeroDivisionError` |
| 1 | `FAILED raised NoMethodError, expected IndexError` |
| 1 | `FAILED raised NameError, expected ArgumentError` |
| 1 | `FAILED matcher did not match N` |
| 1 | `FAILED expected {N=>N, N=>N}, got {}` |
| 1 | `FAILED expected {N=>N, N=>N}, got {N=>N}` |
| 1 | `FAILED expected {:SYM=>N}, got {}` |
| 1 | `FAILED expected {:SYM=>N}, got {:SYM=>N, :SYM=>N, :SYM=>N}` |
| 1 | `FAILED expected {:SYM=>N, :SYM=>N}, got {:SYM=>N, :SYM=>N, :SYM=>N}` |
| 1 | `FAILED expected {#<OBJ>=>"S", #<OBJ>=>"S"}, got {}` |
| 1 | `FAILED expected {"S"=>"S", "S"=>"S"}, got {"S"=>"S", "S"=>nil}` |
| 1 | `FAILED expected {"S"=>"S", "S"=>"S", "S"=>"S"}, got {:SYM=>"S", :SYM=>"S", :SYM=>nil}` |
| 1 | `FAILED expected true, got nil` |
| 1 | `FAILED expected true, got "S"` |
| 1 | `FAILED expected not {N=>N}` |
| 1 | `FAILED expected not nil` |
| 1 | `FAILED expected nil, got []` |
| 1 | `FAILED expected nil, got "S"` |
| 1 | `FAILED expected a Integer, got N` |
| 1 | `FAILED expected a Complex, got N` |
| 1 | `FAILED expected a #<OBJ>>, got #<OBJ>` |
| 1 | `FAILED expected [{}, nil], got nil` |
| 1 | `FAILED expected [], got [[:SYM, :"S"]]` |
| 1 | `FAILED expected [], got [:@make, :@model, :@year]` |
| 1 | `FAILED expected [[N], {:SYM=>N}, #<OBJ>], got [[N], {:SYM=>N}, #<OBJ>]` |
| 1 | `FAILED expected [[N, N], [N, N]], got [[N, nil], [N, nil]]` |
| 1 | `FAILED expected [[N, N], [N, N], [N, N]], got [[N, N], [N, N], [N, N]]` |
| 1 | `FAILED expected [[N, N, N], [N, N, N], [N, N, N], [N, N, N], [N, N, N], [N, N, N]], got [[N, N], [N, N]]` |
| 1 | `FAILED expected [[:SYM], [:SYM]], got [[:SYM, :SYM], [:SYM, :SYM], [:SYM, :SYM]]` |
| 1 | `FAILED expected [["S", "S"], ["S", "S"]], got [[["S", "S"]], [["S", "S"]]]` |
| 1 | `FAILED expected [NaN], got [NaN]` |
| 1 | `FAILED expected [N, N], got nil` |
| 1 | `FAILED expected [N, N], got []` |
| 1 | `FAILED expected [N, N], got [N]` |
| 1 | `FAILED expected [N, N, [N], {:SYM=>N}, N, {}], got [[N, N, N, {:SYM=>N}], N, [], nil, N, {}]` |
| 1 | `FAILED expected [N, N, N], got []` |
| 1 | `FAILED expected [N, N, N], got [N, N, N]` |
| 1 | `FAILED expected [N, N, N], got [#<OBJ>]` |
| 1 | `FAILED expected [N, N, N, [N, N]], got [N, N, N, N, N]` |
| 1 | `FAILED expected [N, N, N, N], got [N, N, #<OBJ>, N, N, #<OBJ>]` |
| 1 | `FAILED expected [N, N, N, N, N, N], got [N, N, N, N]` |
| 1 | `FAILED expected [N, N, N, N, N, N, N], got [N, N, N, N, N]` |
| 1 | `FAILED expected [N, "S", "S", "S", N], got ["S", "S", "S"]` |
| 1 | `FAILED expected [:SYM, :SYM, N], got [:SYM, :SYM, :SYM]` |
| 1 | `FAILED expected [#<OBJ>, {:SYM=>true}], got nil` |
| 1 | `FAILED expected ["S", N, "S", N, N, "S", nil, "S"], got ["S", N, "S", N, N, "S", "S"]` |
| 1 | `FAILED expected ["S", "S"], got []` |
| 1 | `FAILED expected ["S", "S"], got ["S"]` |
| 1 | `FAILED expected ["S", "S"], got ["S", "S"]` |
| 1 | `FAILED expected ["S", "S", "S"], got ["S", "S", nil]` |
| 1 | `FAILED expected ["S", "S", "S", "S", "S"], got ["S", "S", "S", "S", "S", "S", "S", "S", "S", "S", "S", "S", "S"]` |
| 1 | `FAILED expected ["S", "S", "S", "S", "S", "S"], got ["S", "S", "S", "S", "S"]` |
| 1 | `FAILED expected N, got (N+Ni)` |
| 1 | `FAILED expected MethodSpecs::Methods, got Object` |
| 1 | `FAILED expected MethodSpecs::InheritedMethods::C, got MethodSpecs::InheritedMethods::B` |
| 1 | `FAILED expected Kernel, got Module` |
| 1 | `FAILED expected IndexError to be raised` |
| 1 | `FAILED expected FrozenError to be raised` |
| 1 | `FAILED expected :SYM, got nil` |
| 1 | `FAILED expected :SYM, got [:SYM, :SYM]` |
| 1 | `FAILED expected :SYM, got :SYM` |
| 1 | `FAILED expected (N/N), got (N/N)` |
| 1 | `FAILED expected (N+Ni), got (N+Ni+N+Nii)` |
| 1 | `FAILED expected #<OBJ>, got nil` |
| 1 | `FAILED expected "a.rb:N: Some runtime error (RuntimeError)` |
| 1 | `FAILED expected "S"abc def ghi\"S"abc\"S"def\"S", got "S"abc def ghi\"S"abc\"S"def\"S"ghi\"S"` |
| 1 | `FAILED expected "S"\xN\"S", got "S"N\"S"` |
| 1 | `FAILED expected "S"\u{N}\"S", got "S"\uNFN\uN\uN\uN\"S"` |
| 1 | `FAILED expected "S"\"S", got "S"` |
| 1 | `FAILED expected "S"MethodSpecs::MyMod\"S"bar\"S" to match` |
| 1 | `FAILED expected "S", got #<OBJ>` |
| 1 | `FAILED expected "S", got "goodbye` |
| 1 | `FAILED expected "S", got " hello world` |
| 1 | `FAILED expected "S", got "` |
| 1 | `FAILED expected "S"$ruby!\"S", got "S"` |
| 1 | `ERROR SyntaxError` |
| 1 | `ERROR RuntimeError` |
| 1 | `ERROR RangeError` |
| 1 | `ERROR Errno::ENOENT` |
| 1 | `ERROR Encoding::UndefinedConversionError` |

<details><summary>the same rows by exact cause (top 40)</summary>

| files | cause |
|---|---|
| 24 | `FAILED: expected TypeError to be raised` |
| 23 | `FAILED: expected ArgumentError to be raised` |
| 5 | `FAILED: raised NoMethodError, expected RangeError` |
| 5 | `FAILED: expected not 0` |
| 4 | `FAILED: retains compare_by_identity flag: expected true, got false` |
| 4 | `FAILED: expected LocalJumpError to be raised` |
| 3 | `pass=2 fail=0 err=0` |
| 3 | `FAILED: raised NoMethodError, expected ArgumentError` |
| 3 | `FAILED: expected SyntaxError to be raised` |
| 3 | `FAILED: expected NoMethodError to be raised` |
| 3 | `FAILED: always returns the same string: expected to be identical` |
| 2 | `FAILED: yields in turn the last length-1 values from the array: expected [2, 3, 4, 5], got []` |
| 2 | `FAILED: tries to convert length to an integer using to_int: expected "^_^", got "^"` |
| 2 | `FAILED: transcodes from the locale encoding to Encoding.default_internal if set: expected to be identical` |
| 2 | `FAILED: sets the encoding to the encoding of the source String: expected to be identical` |
| 2 | `FAILED: returns self: expected to be identical` |
| 2 | `FAILED: returns -1: expected -1, got -4` |
| 2 | `FAILED: raised StandardError, expected ZeroDivisionError` |
| 2 | `FAILED: raised NoMethodError, expected TypeError` |
| 2 | `FAILED: raised NoMethodError, expected SignalException` |
| 2 | `FAILED: raised NameError, expected TypeError` |
| 2 | `FAILED: includes Comparable: expected true, got false` |
| 2 | `FAILED: expected ZeroDivisionError to be raised` |
| 2 | `FAILED: expected ThreadError to be raised` |
| 2 | `FAILED: expected RangeError to be raised` |
| 2 | `FAILED: expected NameError to be raised` |
| 2 | `FAILED: calls #initialize_copy on the new instance: expected 2003088, got nil` |
| 2 | `ERROR: with no arguments (precision = 0) returns an integer: NoMethodError` |
| 1 | `sh: feature_14386: command not found` |
| 1 | `pass=56 fail=0 err=1` |
| 1 | `pass=53 fail=0 err=0` |
| 1 | `FAILED: yields each element to the block even if the array is changed during iteration: expected [1, 2, 3, 4, 5, 7, 9], got [1, 2, 3, 4, 5]` |
| 1 | `FAILED: writer method be a synonym for []=: expected "F150", got nil` |
| 1 | `FAILED: wraps the lock/unlock pair in an ensure: expected true, got false` |
| 1 | `FAILED: works with a broken string: expected false, got true` |
| 1 | `FAILED: uses the last value of a duplicated key: expected {:a=>3, :b=>2}, got {:a=>1, :b=>2, :a=>3}` |
| 1 | `FAILED: uses the default proc to compute a default value, passing given key: expected [{}, nil], got nil` |
| 1 | `FAILED: uses non-e format for a positive value with whole part having 15 significant figures: expected "10000000000000.0", got "1.0e+13"` |
| 1 | `FAILED: uses eql? semantics: expected [1.0, 1], got [1.0]` |
| 1 | `FAILED: uses block to sort array if passed a block: expected [[3, 4], [2, 9], [1, 2]], got [[1, 2], [2, 9], [3, 4]]` |

</details>

## The absent names

Files whose FIRST divergence is NoMethodError or NameError, keyed by the
method the spec file is named for. Not every row is a missing method --
a spec can raise NoMethodError from a helper -- but most are, and the
class column says where the weight sits.

| class | absent names (from the spec filenames) |
|---|---|
| kernel (23) | `Rational __method__ binding chomp chop comparison enum_for fail format global_variables initialize_clone initialize_copy initialize_dup instance_variable_get lambda loop method public_send respond_to_missing select singleton_method test warn` |
| env (15) | `delete_if each_key each each_value filter has_key has_value keep_if key length member reject select store update` |
| rational (14) | `ceil div divide divmod floor magnitude marshal_dump minus multiply plus quo round truncate zero` |
| struct (13) | `deconstruct_keys deconstruct dig each_pair element_reference element_set filter initialize keyword_init length new size values_at` |
| exception (13) | `backtrace_locations backtrace detailed_message errno exception interrupt io_error key_error load_error signal_exception syntax_error system_call_error uncaught_throw_error` |
| integer (11) | `case_compare ceildiv div gcd ord pred remainder round size succ try_convert` |
| symbol (10) | `all_symbols case_compare encoding id2name intern match name next size slice` |
| string (10) | `each_grapheme_cluster grapheme_clusters inspect scrub to_c to_r to_sym undump unicode_normalize unicode_normalized` |
| matchdata (10) | `byteoffset deconstruct_keys deconstruct dup equal_value length match_length match offset regexp` |
| complex (10) | `angle conj constants imag integer magnitude marshal_dump phase quo rect` |
| method (9) | `case_compare clone curry element_reference hash original_name source_location super_method to_proc` |
| unboundmethod (6) | `bind_call clone hash original_name source_location super_method` |
| numeric (6) | `angle conj imag modulo phase rect` |
| sizedqueue (5) | `deq enq length push shift` |
| queue (5) | `deq enq length push shift` |
| array (5) | `bsearch_index bsearch delete_if repeated_combination repeated_permutation` |
| language (4) | `alias keyword_arguments metaclass order` |
| hash (4) | `compact deconstruct_keys fetch_values transform_values` |
| float (4) | `angle case_compare phase quo` |
| nil (2) | `to_c to_r` |
| range (1) | `step` |
| comparable (1) | `equal_value` |

_Generated by `mspec/causes.sh`._

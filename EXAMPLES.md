# mere-ruby — the examples that actually fail

One row per recorded DIFF file, holding the first few FAILED / ERROR
lines the harness prints for it. `CAUSES.md` groups the record; this
runs the specs again, because a recorded row is the first DIVERGENCE in
a file and not the diagnosis.

Regenerate with `./mspec/examples.sh <spec-root>` (slow: it runs every
file below, both sides). Paths and addresses are masked by mask.sh.

Visited **146** of **146** recorded DIFF files.

| file | what fails |
|---|---|
| core/array/element_reference_spec.rb | ERROR: with a subclass of Array raises a RangeError when the start index is out of range of Fixnum: NameError -- undefined local variable or method 'max_long' for an instance of Object |
| core/array/element_reference_spec.rb | FAILED: expected RangeError to be raised |
| core/array/element_reference_spec.rb | FAILED: expected TypeError to be raised |
| core/array/intersect_spec.rb | FAILED: determines equivalence between elements in the sense of eql?: expected true, got false |
| core/array/intersect_spec.rb | pass=12 fail=1 err=0 |
| core/array/sample_spec.rb | FAILED: samples evenly: expected truthy from #<= |
| core/array/sample_spec.rb | FAILED: samples evenly: expected truthy from #<= |
| core/array/sample_spec.rb | FAILED: samples evenly: expected truthy from #<= |
| core/array/shuffle_spec.rb | FAILED: expected NoMethodError to be raised |
| core/array/shuffle_spec.rb | FAILED: expected RangeError to be raised |
| core/array/shuffle_spec.rb | FAILED: raises a RangeError if the value is less than zero: expected to receive #to_int |
| core/complex/inspect_spec.rb | ERROR: Complex#inspect calls #inspect on real and imaginary: TypeError -- not a real |
| core/complex/inspect_spec.rb | ERROR: Complex#inspect adds an `*' before the `i' if the last character of the imaginary part is not numeric: TypeError -- not a real |
| core/complex/inspect_spec.rb | pass=7 fail=0 err=2 |
| core/complex/to_s_spec.rb | ERROR: when self's real component is 0 treats real and imaginary parts as strings: TypeError -- not a real |
| core/complex/to_s_spec.rb | pass=13 fail=0 err=1 |
| core/enumerable/chunk_spec.rb | FAILED: returned Enumerator size returns nil: expected nil, got 1 |
| core/enumerable/chunk_spec.rb | pass=10 fail=1 err=0 |
| core/enumerable/inject_spec.rb | ERROR: Enumerable#inject ignores the block if two arguments: NoMethodError -- undefined method 'complain' for an instance of Object |
| core/enumerable/inject_spec.rb | ERROR: Enumerable#inject does not warn when given a Symbol with $VERBOSE true: NoMethodError -- undefined method 'complain' for an instance of Object |
| core/enumerable/inject_spec.rb | FAILED: tolerates increasing a collection size during iterating Array: expected [0, 1, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 2, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 3, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 4, 40, 41, 42, 43, 44, 45,  ...[clipped] |
| core/enumerable/map_spec.rb | FAILED: reports the same arity as the given block: expected [2], got [-2] |
| core/enumerable/map_spec.rb | FAILED: reports the same arity as the given block: expected [1], got [-2] |
| core/enumerable/map_spec.rb | ERROR: Enumerable#map yields 2 arguments for a Hash when block arity is 2: ArgumentError -- wrong number of arguments (given 1, expected 2) |
| core/enumerable/tally_spec.rb | FAILED: ignores the default value: expected {...}, got {...} |
| core/enumerable/tally_spec.rb | FAILED: ignores the default proc: expected {...}, got {...} |
| core/enumerable/tally_spec.rb | pass=14 fail=2 err=0 |
| core/enumerable/to_h_spec.rb | ERROR: Enumerable#to_h forwards arguments to #each: NoMethodError -- undefined method 'to_h' for #<Object:0xADDR> |
| core/enumerable/to_h_spec.rb | pass=13 fail=0 err=1 |
| core/env/each_pair_spec.rb | FAILED: transcodes from the locale encoding to Encoding.default_internal if set: expected to be identical |
| core/env/each_pair_spec.rb | FAILED: transcodes from the locale encoding to Encoding.default_internal if set: expected to be identical |
| core/env/each_pair_spec.rb | FAILED: transcodes from the locale encoding to Encoding.default_internal if set: expected to be identical |
| core/env/merge_spec.rb | FAILED: adds the multiple parameter hashes to ENV, returning ENV: expected "multi2", got nil |
| core/env/merge_spec.rb | ERROR: ENV.merge! yields key, the old value and the new value when replacing an entry: NotImplementedError -- mere-ruby: ENV.merge! is not implemented (it would change the environment) |
| core/env/merge_spec.rb | ERROR: ENV.merge! yields key, the old value and the new value when replacing an entry: NotImplementedError -- mere-ruby: ENV.merge! is not implemented (it would change the environment) |
| core/env/replace_spec.rb | FAILED: expected TypeError to be raised |
| core/env/replace_spec.rb | FAILED: raises TypeError if a key is not a String: expected {...}, got {...} |
| core/env/replace_spec.rb | FAILED: expected TypeError to be raised |
| core/env/shift_spec.rb | FAILED: transcodes from the locale encoding to Encoding.default_internal if set: expected to be identical |
| core/env/shift_spec.rb | FAILED: transcodes from the locale encoding to Encoding.default_internal if set: expected to be identical |
| core/env/shift_spec.rb | pass=6 fail=2 err=0 |
| core/exception/backtrace_locations_spec.rb | FAILED: returns an Array that can be updated: expected "backtrace first", got "TMPDIR 'Object#it'" |
| core/exception/backtrace_locations_spec.rb | pass=2 fail=1 err=0 |
| core/exception/backtrace_spec.rb | pass=16 fail=0 err=0 |
| core/exception/full_message_spec.rb | FAILED: supports :highlight option and adds escape sequences to highlight some strings: expected "\e[1mTraceback\e[m (most recent call last): |
| core/exception/full_message_spec.rb | FAILED: supports :highlight option and adds escape sequences to highlight some strings: expected "Traceback (most recent call last): |
| core/exception/interrupt_spec.rb | ERROR: rescuing Interrupt raises an Interrupt when sent a signal SIGINT: NoMethodError -- undefined method 'kill' for module Process |
| core/exception/interrupt_spec.rb | FAILED: is raised on the main Thread by the default SIGINT handler: expected "Interrupt: 2 |
| core/exception/interrupt_spec.rb | pass=4 fail=1 err=1 |
| core/exception/signal_exception_spec.rb | FAILED: expected ArgumentError to be raised |
| core/exception/signal_exception_spec.rb | ERROR: rescuing SignalException raises a SignalException when sent a signal: NoMethodError -- undefined method 'kill' for module Process |
| core/exception/signal_exception_spec.rb | ERROR: SignalException can be rescued: SystemExit -- exit |
| core/exception/signm_spec.rb | FAILED: raised NoMethodError, expected SignalException |
| core/exception/signm_spec.rb | pass=0 fail=1 err=0 |
| core/exception/signo_spec.rb | FAILED: raised NoMethodError, expected SignalException |
| core/exception/signo_spec.rb | pass=0 fail=1 err=0 |
| core/exception/system_exit_spec.rb | ERROR: #initialize sets the exit status and exits silently when raised: SystemExit -- SystemExit |
| core/exception/system_exit_spec.rb | ERROR: #initialize sets the exit status and exits silently when raised when subclassed: CustomExit -- CustomExit |
| core/exception/system_exit_spec.rb | pass=18 fail=0 err=2 |
| core/exception/top_level_spec.rb | FAILED: is printed on STDERR: expected "" to match |
| core/exception/top_level_spec.rb | FAILED: the Exception#cause is printed to STDERR with backtraces: expected nil to match |
| core/exception/top_level_spec.rb | ERROR: An Exception reaching the top level the Exception#cause is printed to STDERR with backtraces: RuntimeError -- wrapped |
| core/float/next_float_spec.rb | FAILED: returns a float the smallest possible step greater than the receiver: expected truthy from #< |
| core/float/next_float_spec.rb | FAILED: steps directly between MAX and INFINITY: expected -1.7976931348623157e+308, got -Infinity |
| core/float/next_float_spec.rb | pass=11 fail=2 err=0 |
| core/float/prev_float_spec.rb | FAILED: returns a float the smallest possible step smaller than the receiver: expected truthy from #> |
| core/float/prev_float_spec.rb | FAILED: steps directly between MAX and INFINITY: expected 1.7976931348623157e+308, got Infinity |
| core/float/prev_float_spec.rb | pass=11 fail=2 err=0 |
| core/float/round_spec.rb | ERROR: Float#round returns different rounded values depending on the half option: TypeError -- no implicit conversion of Hash into Integer |
| core/float/round_spec.rb | FAILED: raised TypeError, expected ArgumentError |
| core/float/round_spec.rb | FAILED: returns self for positive ndigits: expected "-0.0", got "0.0" |
| core/float/to_s_spec.rb | FAILED: uses non-e format for a positive value with whole part having 15 significant figures: expected "10000000000000.0", got "1.0e+13" |
| core/float/to_s_spec.rb | FAILED: uses non-e format for a negative value with whole part having 15 significant figures: expected "-10000000000000.0", got "-1.0e+13" |
| core/float/to_s_spec.rb | FAILED: uses non-e format for a positive value with whole part having 16 significant figures: expected "100000000000000.0", got "1.0e+14" |
| core/hash/compare_by_identity_spec.rb | ERROR: Hash#compare_by_identity does not call #hash on keys: RuntimeError -- #hash should not be called on compare_by_identity Hash |
| core/hash/compare_by_identity_spec.rb | pass=32 fail=0 err=1 |
| core/hash/element_set_spec.rb | FAILED: stores unequal keys that hash to the same value: expected to receive #hash |
| core/hash/element_set_spec.rb | FAILED: stores unequal keys that hash to the same value: expected to receive #hash |
| core/hash/element_set_spec.rb | ERROR: Hash#[]= does not dispatch to hash for Boolean, Integer, Float, String, or Symbol: NoMethodError -- undefined method 'fixture' for an instance of Object |
| core/hash/inspect_spec.rb | FAILED: returns a string representation with same order as each(): expected "{:a=>[1, 2], :b=>-2, :d=>-6, nil=>nil}", got "{a: [1, 2], b: -2, d: -6, nil => nil}" |
| core/hash/inspect_spec.rb | FAILED: calls #inspect on keys and values: expected "{key=>val}", got "{key => val}" |
| core/hash/inspect_spec.rb | FAILED: does not call #to_s on a String returned from #inspect: expected "{:a=>\"abc\"}", got "{a: \"abc\"}" |
| core/hash/rehash_spec.rb | FAILED: reorganizes the Hash by recomputing all key hash codes: expected false, got true |
| core/hash/rehash_spec.rb | ERROR: Hash#rehash reorganizes the Hash by recomputing all key hash codes: NoMethodError -- undefined method 'rehash' for an instance of Hash |
| core/hash/rehash_spec.rb | ERROR: Hash#rehash calls #hash for each key: NoMethodError -- undefined method 'rehash' for an instance of Hash |
| core/integer/chr_spec.rb | ERROR: and self is greater than 255 returns a String with the default internal encoding: RangeError -- 256 out of char range |
| core/integer/chr_spec.rb | ERROR: and self is greater than 255 returns a String encoding self interpreted as a codepoint in the default internal encoding: RangeError -- 256 out of char range |
| core/integer/chr_spec.rb | ERROR: Integer#chr with an encoding argument accepts a String as an argument: RuntimeError -- |
| core/integer/coerce_spec.rb | FAILED: expected TypeError to be raised |
| core/integer/coerce_spec.rb | FAILED: expected TypeError to be raised |
| core/integer/coerce_spec.rb | FAILED: expected TypeError to be raised |
| core/integer/element_reference_spec.rb | FAILED: calls #to_int to convert the argument to an Integer and returns 1 if the nth bit is set: expected 1, got nil |
| core/integer/element_reference_spec.rb | FAILED: calls #to_int to convert the argument to an Integer and returns 1 if the nth bit is set: expected to receive #to_int |
| core/integer/element_reference_spec.rb | FAILED: calls #to_int to convert the argument to an Integer and returns 0 if the nth bit is set: expected 0, got nil |
| core/integer/round_spec.rb | FAILED: raised NameError, expected RangeError |
| core/integer/round_spec.rb | ERROR: Integer#round calls #to_int on the argument to convert it to an Integer: TypeError -- no implicit conversion of Object into Integer |
| core/integer/round_spec.rb | FAILED: expected ArgumentError to be raised |
| core/integer/upto_spec.rb | FAILED: yields while increasing self until it is greater than floor of a Float endpoint: expected [9, 10, 11, 12, 13, -5, -4, -3, -2], got [9, 10, 11, 12, 13, -5, -4, -3, -2, -1] |
| core/integer/upto_spec.rb | FAILED: expected ArgumentError to be raised |
| core/integer/upto_spec.rb | FAILED: expected ArgumentError to be raised |
| core/kernel/Integer_spec.rb | FAILED: expected TypeError to be raised |
| core/kernel/Integer_spec.rb | pass=327 fail=1 err=0 |
| core/kernel/__dir___spec.rb | ERROR: Kernel#__dir__ returns the expanded path of the directory when used in the main script: NoMethodError -- undefined method 'fixture' for an instance of Object |
| core/kernel/__dir___spec.rb | FAILED: returns File.dirname(filename): expected ".", got "HOME" |
| core/kernel/__dir___spec.rb | FAILED: returns File.dirname(filename): expected "foo", got "HOME" |
| core/kernel/backtick_spec.rb | ERROR: Kernel#` lets the standard error stream pass through to the inherited stderr: NoMethodError -- undefined method 'ruby_cmd' for an instance of Object |
| core/kernel/backtick_spec.rb | FAILED: produces a String in the default external encoding: expected to be identical |
| core/kernel/backtick_spec.rb | FAILED: expected Errno::ENOENT to be raised |
| core/kernel/binding_spec.rb | ERROR: Kernel#binding encapsulates the execution context properly: NameError -- undefined local variable or method 'b' for an instance of KernelSpecs::Binding |
| core/kernel/binding_spec.rb | pass=9 fail=0 err=1 |
| core/kernel/block_given_spec.rb | FAILED: returns false when a method defined by define_method is called with a block: expected false, got true |
| core/kernel/block_given_spec.rb | FAILED: returns false outside of a method: expected false, got true |
| core/kernel/block_given_spec.rb | pass=11 fail=2 err=0 |
| core/kernel/caller_locations_spec.rb | FAILED: returns an Array of caller locations using a custom offset: expected truthy from #end_with? |
| core/kernel/caller_locations_spec.rb | FAILED: can be called with a range: expected ["TMPDIR 'Object#describe'", "TMPDIR 'Kernel#require'", "TMPDIR '<main>'"], got ["TMPDIR 'Kernel#require'", "TMPDIR '<main>'"] |
| core/kernel/caller_locations_spec.rb | FAILED: works with endless ranges: expected ["TMPDIR 'Kernel#require'", "TMPDIR '<main>'"], got ["TMPDIR 'Object#describe'", "TMPDIR 'Kernel#require'", "TMPDIR '<main>'"] |
| core/kernel/caller_spec.rb | FAILED: returns an Array of caller locations using a custom offset: expected "TMPDIR 'Object#describe'" to match |
| core/kernel/caller_spec.rb | FAILED: returns an Array of caller locations using a custom limit: expected 1, got 4 |
| core/kernel/caller_spec.rb | FAILED: returns an Array of caller locations using a range: expected 1, got 4 |
| core/kernel/chomp_spec.rb | ERROR: Kernel#chomp is a private method only when -n is passed: NoMethodError -- undefined method 'popen' for class IO |
| core/kernel/chomp_spec.rb | ERROR: Kernel#chomp removes the final newline of $_: NoMethodError -- undefined method 'popen' for class IO |
| core/kernel/chomp_spec.rb | ERROR: Kernel#chomp removes the final carriage return of $_: NoMethodError -- undefined method 'popen' for class IO |
| core/kernel/chop_spec.rb | ERROR: Kernel#chop is a private method only when -n is passed: NoMethodError -- undefined method 'popen' for class IO |
| core/kernel/chop_spec.rb | ERROR: Kernel#chop removes the final character of $_: NoMethodError -- undefined method 'popen' for class IO |
| core/kernel/chop_spec.rb | ERROR: Kernel#chop removes the final carriage return, newline of $_: NoMethodError -- undefined method 'popen' for class IO |
| core/kernel/define_singleton_method_spec.rb | FAILED: raised NoMethodError, expected TypeError |
| core/kernel/define_singleton_method_spec.rb | FAILED: raised NoMethodError, expected ArgumentError |
| core/kernel/define_singleton_method_spec.rb | FAILED: raised NoMethodError, expected ArgumentError |
| core/kernel/eval_spec.rb | ERROR: Kernel#eval evaluates within the scope of the eval: NameError -- uninitialized constant EvalSpecs::A::B |
| core/kernel/eval_spec.rb | ERROR: Kernel#eval evaluates such that constants are scoped to the class of the eval: NameError -- uninitialized constant EvalSpecs::A::C |
| core/kernel/eval_spec.rb | ERROR: Kernel#eval does not share locals across eval scopes: NoMethodError -- undefined method 'fixture' for an instance of Object |
| core/kernel/gets_spec.rb | FAILED: calls ARGF.gets: expected "spec", got nil |
| core/kernel/gets_spec.rb | FAILED: calls ARGF.gets: expected to receive #gets |
| core/kernel/gets_spec.rb | pass=2 fail=2 err=0 |
| core/kernel/inspect_spec.rb | FAILED: expected TypeError to be raised |
| core/kernel/inspect_spec.rb | pass=7 fail=1 err=0 |
| core/kernel/lambda_spec.rb | ERROR: Kernel#lambda strictly checks the arity when 0 or 2..inf args are specified: ArgumentError -- ArgumentError |
| core/kernel/lambda_spec.rb | FAILED: treats the block as a Proc when lambda is re-defined: expected 1, got 2 |
| core/kernel/lambda_spec.rb | FAILED: expected ArgumentError to be raised |
| core/kernel/loop_spec.rb | ERROR: Kernel#loop returns an enumerator if no block given: NameError -- undefined local variable or method 'loop' for an instance of Object |
| core/kernel/loop_spec.rb | ERROR: Kernel#loop rescues StopIteration's subclasses: #<Class:0xADDR> -- AnonClass_2 |
| core/kernel/loop_spec.rb | FAILED: returns StopIteration#result, the result value of a finished iterator: expected :stopped, got nil |
| core/kernel/method_spec.rb | FAILED: will see an alias of the original method as == when in a derived class: expected #<Method: KernelSpecs::A#pub_method() TMPDIR got #<Method: KernelSpecs::B#aliased_pub_method() TMPDIR |
| core/kernel/method_spec.rb | pass=11 fail=1 err=0 |
| core/kernel/open_spec.rb | ERROR: Kernel#open is a private method: NoMethodError -- undefined method 'tmp' for an instance of Object |
| core/kernel/open_spec.rb | ERROR: Kernel#open opens a file when given a valid filename: NoMethodError -- undefined method 'tmp' for an instance of Object |
| core/kernel/open_spec.rb | ERROR: Kernel#open opens a file when called with a block: NoMethodError -- undefined method 'tmp' for an instance of Object |
| core/kernel/public_method_spec.rb | FAILED: expected NameError to be raised |
| core/kernel/public_method_spec.rb | pass=4 fail=1 err=0 |
| core/kernel/raise_spec.rb | FAILED: re-raises a previously rescued exception without overwriting the cause when it's explicitly specified with :cause option and has nil value: expected #<RuntimeError: Error 1>, got nil |
| core/kernel/raise_spec.rb | FAILED: re-raises a previously rescued exception that doesn't have a cause and is a cause of other exception without setting a cause implicitly: expected #<RuntimeError: Error 1>, got #<RuntimeError: Error 1> |
| core/kernel/raise_spec.rb | FAILED: re-raises a previously rescued exception that doesn't have a cause and is a cause of other exception without setting a cause implicitly: expected nil, got #<RuntimeError: Error 2> |
| core/kernel/require_spec.rb | FAILED: provided features are already required: expected ["complex", "enumerator", "fiber", "pathname", "rational", "ruby2_keywords", "set", "thread"], got ["code_loading", "require", "require_spec", "spec_helper"] |
| core/kernel/require_spec.rb | pass=3 fail=1 err=0 |
| core/kernel/require_spec.rb | FAILED: provided features are already required: expected ["complex", "enumerator", "fiber", "pathname", "rational", "ruby2_keywords", "set", "thread"], got ["require"] |
| core/kernel/respond_to_missing_spec.rb | FAILED: is called with a 2nd argument of false when #respond_to? is: expected to receive #respond_to_missing? |
| core/kernel/respond_to_missing_spec.rb | FAILED: is called a 2nd argument of false when #respond_to? is called with only 1 argument: expected to receive #respond_to_missing? |
| core/kernel/respond_to_missing_spec.rb | FAILED: is called with true as the second argument when #respond_to? is: expected to receive #respond_to_missing? |
| core/kernel/select_spec.rb | ERROR: Kernel#select does not block when timeout is 0: NoMethodError -- undefined method 'pipe' for class IO |
| core/kernel/select_spec.rb | pass=2 fail=0 err=1 |
| core/kernel/singleton_class_spec.rb | ERROR: for an IO object with a replaced singleton class looks up singleton methods from the fresh singleton class after an object instance got a new one: NoMethodError -- undefined method 'reopen' for an instance of File |
| core/kernel/singleton_class_spec.rb | pass=12 fail=0 err=1 |
| core/kernel/sleep_spec.rb | FAILED: pauses execution indefinitely if not given a duration: expected 5, got nil |
| core/kernel/sleep_spec.rb | FAILED: sleeps with nanosecond precision: expected truthy from #> |
| core/kernel/sleep_spec.rb | ERROR: Kernel#sleep accepts a nil duration: TypeError -- can't convert nil into time interval |
| core/kernel/srand_spec.rb | FAILED: returns the previous seed value: expected 10, got 0 |
| core/kernel/srand_spec.rb | FAILED: seeds the RNG correctly and repeatably: expected 0.600358202, got 0.089427938 |
| core/kernel/srand_spec.rb | ERROR: Kernel#srand defaults number to a random value: RuntimeError -- |
| core/kernel/system_spec.rb | ERROR: Kernel#system executes the specified command in a subprocess: NoMethodError -- undefined method 'output_to_fd' for an instance of Object |
| core/kernel/system_spec.rb | ERROR: Kernel#system returns true when the command exits with a zero exit status: NoMethodError -- undefined method 'ruby_cmd' for an instance of Object |
| core/kernel/system_spec.rb | ERROR: Kernel#system returns false when the command exits with a non-zero exit status: NoMethodError -- undefined method 'ruby_cmd' for an instance of Object |
| core/kernel/test_spec.rb | ERROR: Kernel#test returns true when passed ?f if the argument is a regular file: NoMethodError -- undefined method 'test' for an instance of Object |
| core/kernel/test_spec.rb | ERROR: Kernel#test returns true when passed ?e if the argument is a file: NoMethodError -- undefined method 'test' for an instance of Object |
| core/kernel/test_spec.rb | ERROR: Kernel#test returns true when passed ?d if the argument is a directory: NoMethodError -- undefined method 'test' for an instance of Object |
| core/kernel/to_enum_spec.rb | FAILED: sets regexp matches in the caller: expected ["w", "a", "w", "a"], got ["a", "a", "a", "a"] |
| core/kernel/to_enum_spec.rb | ERROR: Kernel#to_enum uses the passed block's value to calculate the size of the enumerator: NoMethodError -- undefined method 'to_enum' for an instance of Object |
| core/kernel/to_enum_spec.rb | ERROR: Kernel#to_enum defers the evaluation of the passed block until #size is called: NoMethodError -- undefined method 'to_enum' for an instance of Object |
| core/kernel/trace_var_spec.rb | FAILED: accepts a String argument instead of a Proc or block: expected true, got nil |
| core/kernel/trace_var_spec.rb | FAILED: expected ArgumentError to be raised |
| core/kernel/trace_var_spec.rb | pass=4 fail=2 err=0 |
| core/kernel/warn_spec.rb | ERROR: Kernel#warn does not append line-end if last character is line-end: NoMethodError -- undefined method 'output' for an instance of Object |
| core/kernel/warn_spec.rb | ERROR: Kernel#warn calls #write on $stderr if $VERBOSE is true: NoMethodError -- undefined method 'output' for an instance of Object |
| core/kernel/warn_spec.rb | ERROR: Kernel#warn calls #write on $stderr if $VERBOSE is false: NoMethodError -- undefined method 'output' for an instance of Object |
| core/matchdata/element_reference_spec.rb | FAILED: returns matches in the String's encoding: expected #<Encoding:EUC-JP>, got #<Encoding:UTF-8> |
| core/matchdata/element_reference_spec.rb | pass=39 fail=1 err=0 |
| core/matchdata/post_match_spec.rb | FAILED: sets the encoding to the encoding of the source String: expected to be identical |
| core/matchdata/post_match_spec.rb | FAILED: sets an empty result to the encoding of the source String: expected to be identical |
| core/matchdata/post_match_spec.rb | pass=2 fail=2 err=0 |
| core/matchdata/pre_match_spec.rb | FAILED: sets the encoding to the encoding of the source String: expected to be identical |
| core/matchdata/pre_match_spec.rb | FAILED: sets an empty result to the encoding of the source String: expected to be identical |
| core/matchdata/pre_match_spec.rb | pass=2 fail=2 err=0 |
| core/method/call_spec.rb | FAILED: does not call the original method name even if it now exists: expected [:argument], got :not_called |
| core/method/call_spec.rb | pass=7 fail=1 err=0 |
| core/method/curry_spec.rb | FAILED: expected ArgumentError to be raised |
| core/method/curry_spec.rb | FAILED: expected ArgumentError to be raised |
| core/method/curry_spec.rb | FAILED: expected ArgumentError to be raised |
| core/method/equal_value_spec.rb | FAILED: calls respond_to_missing? with true to include private methods: #respond_to_missing? received with unexpected arguments |
| core/method/equal_value_spec.rb | ERROR: missing methods returns false if the argument is an unbound version of self: NameError -- undefined method 'load' for class 'Object' |
| core/method/equal_value_spec.rb | pass=15 fail=1 err=1 |
| core/method/parameters_spec.rb | FAILED: returns [:rest, :*], [:keyrest, :**], [:block, :&] for forward parameters operator: expected [[:rest, :*], [:keyrest, :**], [:block, :&]], got [[:rest, :__fwd], [:block, :&]] |
| core/method/parameters_spec.rb | FAILED: returns all parameters defined with the name _ as _: expected [[:req, :_], [:req, :_], [:opt, :_], [:rest, :_], [:keyreq, :_], [:key, :_], [:keyrest, :_], [:block, :_]], got [[:req, :_], [:req, :"_~1"], [:opt, :"_~2"], [:rest, :"_~3 ...[clipped] |
| core/method/parameters_spec.rb | ERROR: Method#parameters returns [[:rest]] for core methods with variable-length argument lists: NameError -- undefined method 'delete!' for class 'String' |
| core/method/source_location_spec.rb | pass=16 fail=0 err=0 |
| core/method/super_method_spec.rb | ERROR: Method#super_method returns the method that would be called by super in the method: NoMethodError -- undefined method 'owner' for nil |
| core/method/super_method_spec.rb | FAILED: returns nil when there's no super method in the parent: expected nil, got #<Method: Kernel#method()> |
| core/method/super_method_spec.rb | FAILED: returns the expected super_method: expected MethodSpecs::InheritedMethods::A, got MethodSpecs::InheritedMethods::B |
| core/method/to_proc_spec.rb | ERROR: Method#to_proc returns a proc that properly invokes module methods with super: NameError -- undefined method 'foo' for class '#<Class:0xADDR>' |
| core/method/to_proc_spec.rb | pass=36 fail=0 err=1 |
| core/method/unbind_spec.rb | FAILED: keeps the origin singleton class if there is one: expected truthy from #start_with? |
| core/method/unbind_spec.rb | pass=7 fail=1 err=0 |
| core/mutex/lock_spec.rb | ERROR: Mutex#lock blocks the caller if already locked: NameError -- undefined local variable or method 'block_caller' for an instance of Object |
| core/mutex/lock_spec.rb | ERROR: Mutex#lock does not block the caller if not locked: NameError -- undefined local variable or method 'block_caller' for an instance of Object |
| core/mutex/lock_spec.rb | FAILED: expected ThreadError to be raised |
| core/mutex/locked_spec.rb | FAILED: returns the status of the lock: expected false, got true |
| core/mutex/locked_spec.rb | pass=3 fail=1 err=0 |
| core/mutex/sleep_spec.rb | ERROR: when not locked by the current thread pauses execution for approximately the duration requested: NameError -- uninitialized constant TIME_TOLERANCE |
| core/mutex/sleep_spec.rb | FAILED: unlocks the mutex while sleeping: expected false, got true |
| core/mutex/sleep_spec.rb | ERROR: when not locked by the current thread relocks the mutex when woken by an exception being raised: Exception -- Exception |
| core/mutex/synchronize_spec.rb | FAILED: wraps the lock/unlock pair in an ensure: expected true, got false |
| core/mutex/synchronize_spec.rb | ERROR: Mutex#synchronize blocks the caller if already locked: NameError -- undefined local variable or method 'block_caller' for an instance of Object |
| core/mutex/synchronize_spec.rb | ERROR: Mutex#synchronize does not block the caller if not locked: NameError -- undefined local variable or method 'block_caller' for an instance of Object |
| core/numeric/step_spec.rb | FAILED: expected ArgumentError to be raised |
| core/numeric/step_spec.rb | FAILED: raised StandardError, expected ArgumentError |
| core/numeric/step_spec.rb | FAILED: raised StandardError, expected ArgumentError |
| core/proc/arity_spec.rb | FAILED: : expected 1, got -2 |
| core/proc/arity_spec.rb | FAILED: : expected 3, got -4 |
| core/proc/arity_spec.rb | FAILED: : expected 3, got -4 |
| core/proc/call_spec.rb | FAILED: doesn't duplicate frozen strings: expected true, got false |
| core/proc/call_spec.rb | pass=41 fail=1 err=0 |
| core/proc/curry_spec.rb | ERROR: Proc#curry can be called multiple times on the same Proc: RuntimeError -- |
| core/proc/curry_spec.rb | FAILED: can be passed superfluous arguments if created from a proc: expected 6, got 12 |
| core/proc/curry_spec.rb | FAILED: expected ArgumentError to be raised |
| core/proc/equal_value_spec.rb | FAILED: is a public method: expected truthy from #include? |
| core/proc/equal_value_spec.rb | FAILED: returns true if other is a dup of the original: expected true, got false |
| core/proc/equal_value_spec.rb | FAILED: returns true if other is a dup of the original: expected true, got false |
| core/proc/new_spec.rb | ERROR: called on a subclass of Proc returns an instance of the subclass: NoMethodError -- undefined method 'call' for an instance of #<Class:0xADDR> |
| core/proc/new_spec.rb | ERROR: using a reified block parameter returns an instance of the subclass: NoMethodError -- undefined method 'call' for an instance of #<Class:0xADDR> |
| core/proc/new_spec.rb | ERROR: called on a subclass of Proc that does not 'super' in 'initialize' still constructs a functional proc: NoMethodError -- undefined method 'call' for an instance of #<Class:0xADDR> |
| core/proc/parameters_spec.rb | FAILED: returns all parameters defined with the name _ as _: expected [[:opt, :_], [:opt, :_], [:opt, :_], [:rest, :_], [:keyreq, :_], [:key, :_], [:keyrest, :_], [:block, :_]], got [[:opt, :_], [:opt, :_], [:opt, :_], [:rest, :_], [:key, : ...[clipped] |
| core/proc/parameters_spec.rb | FAILED: returns all parameters defined with the name _ as _: expected [[:req, :_], [:req, :_], [:opt, :_], [:rest, :_], [:keyreq, :_], [:key, :_], [:keyrest, :_], [:block, :_]], got [[:opt, :_], [:opt, :_], [:opt, :_], [:rest, :_], [:key, : ...[clipped] |
| core/proc/parameters_spec.rb | FAILED: handles the usage of `it` as a parameter: expected [[:opt]], got [] |
| core/range/clone_spec.rb | FAILED: duplicates the range: expected not to be identical |
| core/range/clone_spec.rb | FAILED: duplicates the range: expected not to be identical |
| core/range/clone_spec.rb | pass=10 fail=2 err=0 |
| core/range/dup_spec.rb | FAILED: duplicates the range: expected not to be identical |
| core/range/dup_spec.rb | pass=6 fail=1 err=0 |
| core/range/max_spec.rb | ERROR: Range#max given an integer argument returns the n maximum values for beginless Integer ranges: RangeError -- cannot get the maximum of beginless range with custom comparison method |
| core/range/max_spec.rb | ERROR: Range#max given an integer argument returns the n maximum values (except the end point) for exclusive beginless Integer ranges: RangeError -- cannot get the maximum of beginless range with custom comparison method |
| core/range/max_spec.rb | FAILED: raised RangeError, expected TypeError |
| core/range/step_spec.rb | ERROR: Range#step does not iterate if step is 0 for bounded non-numeric ranges: ArgumentError -- step can't be 0 |
| core/range/step_spec.rb | ERROR: and String values calls #+ on begin and each element returned by #+: TypeError -- can't iterate from Object |
| core/range/step_spec.rb | ERROR: and String values iterates backward if the step is decreasing values, and the range is backward: TypeError -- can't iterate from Object |
| core/rational/exponent_spec.rb | FAILED: expected ZeroDivisionError to be raised |
| core/rational/exponent_spec.rb | pass=38 fail=1 err=0 |
| core/rational/round_spec.rb | ERROR: with half option returns an Integer when precision is not passed: TypeError -- not an integer |
| core/rational/round_spec.rb | FAILED: returns a Rational when the precision is greater than 0: expected (1/5), got (3/10) |
| core/rational/round_spec.rb | FAILED: returns a Rational when the precision is greater than 0: expected (1/5), got (3/10) |
| core/rational/to_f_spec.rb | FAILED: converts to a Float for large numerator and denominator: expected 500.0, got NaN |
| core/rational/to_f_spec.rb | pass=0 fail=1 err=0 |
| core/rational/to_r_spec.rb | FAILED: expected TypeError to be raised |
| core/rational/to_r_spec.rb | pass=4 fail=1 err=0 |
| core/regexp/encoding_spec.rb | FAILED: upgrades the encoding to that of an embedded String: expected #<Encoding:EUC-JP>, got #<Encoding:UTF-8> |
| core/regexp/encoding_spec.rb | pass=12 fail=1 err=0 |
| core/regexp/equal_value_spec.rb | FAILED: is true if self and other have the same character set code: expected false, got true |
| core/regexp/equal_value_spec.rb | pass=10 fail=1 err=0 |
| core/regexp/initialize_spec.rb | FAILED: raised FrozenError, expected TypeError |
| core/regexp/initialize_spec.rb | FAILED: raised NoMethodError, expected TypeError |
| core/regexp/initialize_spec.rb | pass=2 fail=2 err=0 |
| core/regexp/last_match_spec.rb | FAILED: expected IndexError to be raised |
| core/regexp/last_match_spec.rb | FAILED: coerces argument to an index using #to_int: expected "TEST123", got nil |
| core/regexp/last_match_spec.rb | FAILED: coerces argument to an index using #to_int: expected to receive #to_int |
| core/regexp/match_spec.rb | FAILED: expected ArgumentError to be raised |
| core/regexp/match_spec.rb | FAILED: expected ArgumentError to be raised |
| core/regexp/match_spec.rb | ERROR: when passed a block yields the MatchData: NoMethodError -- undefined method 'match' for an instance of Regexp |
| core/regexp/options_spec.rb | FAILED: expected not 0 |
| core/regexp/options_spec.rb | FAILED: expected not 0 |
| core/regexp/options_spec.rb | pass=18 fail=2 err=0 |
| core/regexp/timeout_spec.rb | ERROR: Regexp.timeout raises Regexp::TimeoutError after global timeout elapsed: NameError -- uninitialized constant Regexp::TimeoutError |
| core/regexp/timeout_spec.rb | ERROR: Regexp.timeout raises Regexp::TimeoutError after timeout keyword value elapsed: NameError -- uninitialized constant Regexp::TimeoutError |
| core/regexp/timeout_spec.rb | pass=3 fail=0 err=2 |
| core/regexp/union_spec.rb | FAILED: returns a Regexp with the encoding of an ASCII-incompatible String argument: expected #<Encoding:UTF-16LE>, got #<Encoding:US-ASCII> |
| core/regexp/union_spec.rb | FAILED: returns a Regexp with the encoding of a String containing non-ASCII-compatible characters: expected #<Encoding:ISO-8859-1>, got #<Encoding:UTF-8> |
| core/regexp/union_spec.rb | FAILED: returns a Regexp with the encoding of multiple non-conflicting ASCII-incompatible String arguments: expected #<Encoding:UTF-16LE>, got #<Encoding:US-ASCII> |
| core/string/append_as_bytes_spec.rb | FAILED: raised NoMethodError, expected FrozenError |
| core/string/append_as_bytes_spec.rb | ERROR: String#append_bytes allows creating broken strings in UTF8: NoMethodError -- undefined method 'append_as_bytes' for an instance of String |
| core/string/append_as_bytes_spec.rb | ERROR: String#append_bytes allows creating broken strings in UTF_32: NoMethodError -- undefined method 'append_as_bytes' for an instance of String |
| core/string/bytesplice_spec.rb | FAILED: raised ArgumentError, expected IndexError |
| core/string/bytesplice_spec.rb | FAILED: raised ArgumentError, expected IndexError |
| core/string/bytesplice_spec.rb | FAILED: raised ArgumentError, expected IndexError |
| core/string/index_spec.rb | FAILED: always clear $~: expected nil, got #<MatchData "a"> |
| core/string/index_spec.rb | pass=741 fail=1 err=0 |
| core/string/modulo_spec.rb | ERROR: output's encoding raises an ArgumentError for unused arguments when $DEBUG is true: NameError -- uninitialized constant IOStub |
| core/string/modulo_spec.rb | ERROR: output's encoding behaves as if calling Kernel#Integer for %b argument, if it does not respond to #to_ary: ArgumentError -- ArgumentError |
| core/string/modulo_spec.rb | ERROR: output's encoding behaves as if calling Kernel#Integer for %d argument, if it does not respond to #to_ary: ArgumentError -- ArgumentError |
| core/string/to_f_spec.rb | FAILED: expected Encoding::CompatibilityError to be raised |
| core/string/to_f_spec.rb | pass=82 fail=1 err=0 |
| core/string/uplus_spec.rb | ERROR: if file has "frozen_string_literal: true" magic comment returns mutable copy of a literal: NoMethodError -- undefined method 'fixture' for an instance of Object |
| core/string/uplus_spec.rb | FAILED: returns mutable copy of a literal: expected false, got true |
| core/string/uplus_spec.rb | pass=5 fail=1 err=1 |
| core/struct/deconstruct_keys_spec.rb | FAILED: tries to convert a key with #to_int if index is not a String nor a Symbol, but responds to #to_int: expected {#<MockObject to_int> => 2}, got {} |
| core/struct/deconstruct_keys_spec.rb | FAILED: tries to convert a key with #to_int if index is not a String nor a Symbol, but responds to #to_int: expected to receive #to_int |
| core/struct/deconstruct_keys_spec.rb | FAILED: raises a TypeError if the conversion with #to_int does not return an Integer: matcher did not match #<Proc> |
| core/struct/hash_spec.rb | FAILED: allows for overriding methods in an included module: expected "different", got 527 |
| core/struct/hash_spec.rb | ERROR: Struct#hash returns the same hash for recursive structs: SystemStackError -- stack level too deep |
| core/struct/hash_spec.rb | FAILED: expected not 528 |
| core/struct/initialize_spec.rb | FAILED: can be overridden: expected :value, got nil |
| core/struct/initialize_spec.rb | FAILED: can be initialized with keyword arguments: expected {version: "3.2", platform: "OS"}, got "3.2" |
| core/struct/initialize_spec.rb | FAILED: can be initialized with keyword arguments: expected nil, got "OS" |
| core/struct/new_spec.rb | ERROR: Struct.new overwrites previously defined constants with string as first argument: NoMethodError -- undefined method 'complain' for an instance of Object |
| core/struct/new_spec.rb | ERROR: with a block passes same struct class to the block: NoMethodError -- undefined method 'block_parameter' for class #<Class:0xADDR> |
| core/struct/new_spec.rb | FAILED: accepts keyword arguments to initialize: expected #<struct args=42>, got #<struct args={args: 42}> |
| core/symbol/all_symbols_spec.rb | ERROR: Symbol.all_symbols returns an array of Symbols: NoMethodError -- undefined method 'all_symbols' for class Symbol |
| core/symbol/all_symbols_spec.rb | ERROR: Symbol.all_symbols includes symbols that are strongly referenced: NoMethodError -- undefined method 'all_symbols' for class Symbol |
| core/symbol/all_symbols_spec.rb | ERROR: Symbol.all_symbols includes symbols that are referenced in source code but not yet executed: NoMethodError -- undefined method 'all_symbols' for class Symbol |
| core/symbol/casecmp_spec.rb | FAILED: returns nil when comparing characters with different encodings: expected nil, got false |
| core/symbol/casecmp_spec.rb | FAILED: returns nil when comparing characters with different encodings: expected nil, got false |
| core/symbol/casecmp_spec.rb | pass=45 fail=2 err=0 |
| core/symbol/element_reference_spec.rb | FAILED: converts the last value to an Integer: expected "sym", got "symbol" |
| core/symbol/element_reference_spec.rb | ERROR: with a Range subclass slice returns a slice: TypeError -- no implicit conversion of Object into Integer |
| core/symbol/element_reference_spec.rb | FAILED: returns a string for the matched capture at the given index: expected "ol", got nil |
| core/symbol/inspect_spec.rb | FAILED: quotes BINARY symbols: expected ":\"foo\xA4\"", got ":foo\xA4" |
| core/symbol/inspect_spec.rb | FAILED: quotes symbols in non-ASCII-compatible encodings: expected ":\"foo\"", got ":\"f\x00o\x00o\x00\"" |
| core/symbol/inspect_spec.rb | FAILED: quotes symbols in non-ASCII-compatible encodings: expected ":\"foo\"", got ":\"\x00f\x00o\x00o\"" |
| core/symbol/to_proc_spec.rb | FAILED: expected NoMethodError to be raised |
| core/symbol/to_proc_spec.rb | FAILED: only calls public methods: expected [:pub], got [:pub, :pro] |
| core/symbol/to_proc_spec.rb | FAILED: expected NoMethodError to be raised |
| core/unboundmethod/bind_call_spec.rb | ERROR: UnboundMethod#bind_call binds and calls the method on any object when UnboundMethod is unbound from a module: NoMethodError -- undefined method 'from_mod' for an instance of Object |
| core/unboundmethod/bind_call_spec.rb | pass=9 fail=0 err=1 |
| core/unboundmethod/bind_spec.rb | ERROR: UnboundMethod#bind allows calling super for module methods bound to hierarchies that do not already have that module: NoMethodError -- super: no superclass method 'foo_super' |
| core/unboundmethod/bind_spec.rb | pass=11 fail=0 err=1 |
| core/unboundmethod/equal_value_spec.rb | FAILED: returns false if both have same Module, same name, identical body but not the same: expected false, got true |
| core/unboundmethod/equal_value_spec.rb | ERROR: UnboundMethod#== considers methods through aliasing equal: NameError -- undefined method 'n' for class '#<Class:0xADDR>' |
| core/unboundmethod/equal_value_spec.rb | ERROR: UnboundMethod#== considers methods through visibility change equal: NameError -- undefined method 'new' for class 'Class' |
| core/unboundmethod/super_method_spec.rb | ERROR: after changing an inherited methods visibility returns the expected super_method: NoMethodError -- undefined method 'owner' for nil |
| core/unboundmethod/super_method_spec.rb | FAILED: returns the expected super_method: expected MethodSpecs::InheritedMethods::A, got MethodSpecs::InheritedMethods::B |
| core/unboundmethod/super_method_spec.rb | pass=5 fail=1 err=1 |
| language/alias_spec.rb | FAILED: expected TypeError to be raised |
| language/alias_spec.rb | FAILED: expected TypeError to be raised |
| language/alias_spec.rb | FAILED: expected NameError to be raised |
| language/assignments_spec.rb | FAILED: raised ArgumentError, expected SyntaxError |
| language/assignments_spec.rb | FAILED: expected SyntaxError to be raised |
| language/assignments_spec.rb | FAILED: raised ArgumentError, expected SyntaxError |
| language/block_spec.rb | FAILED: assigns elements to mixed argument types: expected [1, 2, [3], {x: 9}, 2, {}], got [[1, 2, 3, {x: 9}], 5, [], nil, 2, {}] |
| language/block_spec.rb | ERROR: Array does not call #to_hash on final argument to get keyword arguments and does not autosplat: NoMethodError -- undefined method 'suppress_keyword_warning' for #<Object:0xADDR> |
| language/block_spec.rb | ERROR: when non-symbol keys are in a keyword arguments Hash does not separate non-symbol keys and symbol keys and does not autosplat: NoMethodError -- undefined method 'suppress_keyword_warning' for #<Object:0xADDR> |
| language/break_spec.rb | FAILED: returns from the lambda: expected [:a, :d, :aaa, :b, :bbb, :e], got [:a, :d, :aaa, :b, :e] |
| language/break_spec.rb | ERROR: created at the toplevel returns a value when invoking from the toplevel: NoMethodError -- undefined method 'fixture' for an instance of Object |
| language/break_spec.rb | ERROR: created at the toplevel returns a value when invoking from a method: NoMethodError -- undefined method 'fixture' for an instance of Object |
| language/constants_spec.rb | ERROR: with statically assigned constants searches the superclass chain: NameError -- uninitialized constant ConstantSpecs::ContainerA::ChildA::CS_CONST13 |
| language/constants_spec.rb | ERROR: with statically assigned constants searches Object if no class or module qualifier is given: NameError -- uninitialized constant CS_CONST10 |
| language/constants_spec.rb | ERROR: with statically assigned constants searches Object after searching other scopes: NameError -- uninitialized constant CS_CONST10 |
| language/def_spec.rb | FAILED: expected SyntaxError to be raised |
| language/def_spec.rb | ERROR: A singleton method definition can be declared for a global variable: NoMethodError -- undefined method 'foo' for an instance of String |
| language/def_spec.rb | FAILED: expected FrozenError to be raised |
| language/defined_spec.rb | FAILED: returns 'method' if the method is defined: expected "method", got nil |
| language/defined_spec.rb | FAILED: calls #respond_to_missing?: expected "method", got nil |
| language/defined_spec.rb | FAILED: calls #respond_to_missing?: expected to receive #respond_to_missing? |
| language/delegation_spec.rb | ERROR: delegation with def(*) delegates rest: StandardError -- mere-ruby: unexpected token: ) in (eval)     def delegate(*) |
| language/ensure_spec.rb | FAILED: does not introduce extra backtrace entries: expected "TMPDIR '190.foo'" to match |
| language/ensure_spec.rb | FAILED: does not introduce extra backtrace entries: expected "TMPDIR 'Object#it'" to match |
| language/ensure_spec.rb | pass=34 fail=2 err=0 |
| language/execution_spec.rb | FAILED: can be redefined and receive a frozen string as argument: expected true, got false |
| language/execution_spec.rb | FAILED: can be redefined and receive a frozen string as argument: expected true, got false |
| language/execution_spec.rb | pass=16 fail=2 err=0 |
| language/hash_spec.rb | FAILED: freezes string keys on initialization: expected "bar", got nil |
| language/hash_spec.rb | FAILED: freezes string keys on initialization: expected "foo", got "oof" |
| language/hash_spec.rb | ERROR: Hash literal checks duplicated keys on initialization: NoMethodError -- undefined method 'complain' for an instance of Object |
| language/it_parameter_spec.rb | ERROR: The `it` parameter provides it in a block: ArgumentError -- wrong number of arguments (given 1, expected 0) |
| language/it_parameter_spec.rb | ERROR: The `it` parameter can be used in both outer and nested blocks at the same time: ArgumentError -- wrong number of arguments (given 1, expected 0) |
| language/it_parameter_spec.rb | FAILED: expected SyntaxError to be raised |
| language/lambda_spec.rb | FAILED: has its own scope for local variables: expected to be identical |
| language/lambda_spec.rb | FAILED: has its own scope for local variables: expected [9, 8, [7], [], 6, 5, 4, 3, {}, #<Proc:0xADDR TMPDIR (lambda)>], got [9, 8, [7], [], 6, 5, 4, 3, {}, #<Proc:0xADDR TMPDIR |
| language/lambda_spec.rb | FAILED: has its own scope for local variables: expected [1, 1, [], 2, 3, 2, 4, {h: 5, i: 6}, #<Proc:0xADDR TMPDIR (lambda)>], got [1, 1, [], 2, 3, 2, 4, {h: 5, i: 6}, #<Proc:0xADDR TMPDIR |
| language/module_spec.rb | ERROR: Assigning an anonymous module to a constant sets the name of a module scoped by an anonymous module: NoMethodError -- undefined method 'end_with?' |
| language/module_spec.rb | pass=15 fail=0 err=1 |
| language/numbered_parameters_spec.rb | ERROR: assigning to a numbered parameter does not affect binding local variables: NoMethodError -- undefined method 'local_variables' for an instance of Binding |
| language/numbered_parameters_spec.rb | FAILED: expected NameError to be raised |
| language/numbered_parameters_spec.rb | FAILED: expected NameError to be raised |
| language/predefined_spec.rb | FAILED: is set at the method-scoped level rather than block-scoped: expected #<MatchData "bar">, got #<MatchData "foo"> |
| language/predefined_spec.rb | FAILED: is set at the method-scoped level rather than block-scoped: expected #<MatchData "qux">, got #<MatchData "baz"> |
| language/predefined_spec.rb | FAILED: sets the encoding to the encoding of the source String: expected to be identical |
| language/proc_spec.rb | FAILED: expected ArgumentError to be raised |
| language/proc_spec.rb | FAILED: expected ArgumentError to be raised |
| language/proc_spec.rb | FAILED: expected ArgumentError to be raised |
| language/regexp_spec.rb | ERROR: Literal Regexps matches against $_ (last input) in a conditional if no explicit matchee provided: NoMethodError -- undefined method 'complain' for an instance of Object |
| language/regexp_spec.rb | ERROR: Literal Regexps supports paired delimiters with %r: SyntaxError -- syntax error |
| language/regexp_spec.rb | ERROR: Literal Regexps supports grouping constructs that are also paired delimiters: SyntaxError -- syntax error |
| language/rescue_spec.rb | FAILED: in a global variable: expected "some text", got "" |
| language/rescue_spec.rb | FAILED: converts the splatted list of exceptions using #to_a: expected to receive #to_a |
| language/rescue_spec.rb | FAILED: expected SyntaxError to be raised |
| language/send_spec.rb | FAILED: raises TypeError if 'to_proc' doesn't return a Proc: matcher did not match #<Proc> |
| language/send_spec.rb | FAILED: raised NoMethodError, expected TypeError |
| language/send_spec.rb | FAILED: calls #to_a to convert a final splatted Hash object to an Array: expected [1, 2, 3, :a, 1], got [1, 2, 3, [:a, 1]] |
| language/string_spec.rb | FAILED: backslashes follow the same rules as interpolation: expected " |
| language/string_spec.rb | FAILED: expected NoMethodError to be raised |
| language/string_spec.rb | ERROR: Ruby character strings allows a dynamic string to parse a nested do...end block as an argument to a call without parens, interpolated: SyntaxError -- syntax error |
| language/variables_spec.rb | ERROR: Local variable shadowing does not warn in verbose mode: NoMethodError -- undefined method 'complain' for an instance of Object |
| language/variables_spec.rb | FAILED: expected SyntaxError to be raised |
| language/variables_spec.rb | ERROR: when instance variable is uninitialized doesn't warn about accessing uninitialized instance variable: NoMethodError -- undefined method 'complain' for an instance of Object |

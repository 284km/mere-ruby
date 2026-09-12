# mere-ruby — the examples that actually fail

One row per recorded DIFF file, holding the first few FAILED / ERROR
lines the harness prints for it. `CAUSES.md` groups the record; this
runs the specs again, because a recorded row is the first DIVERGENCE in
a file and not the diagnosis.

Regenerate with `./mspec/examples.sh <spec-root>` (slow: it runs every
file below, both sides). Paths and addresses are masked by mask.sh.

Visited **150** of **150** recorded DIFF files.

| file | what fails |
|---|---|
| core/array/element_reference_spec.rb | ERROR: with a subclass of Array raises a RangeError when the start index is out of range of Fixnum: NameError -- undefined local variable or method 'max_long' for an instance of Object |
| core/array/element_reference_spec.rb | FAILED: expected RangeError to be raised |
| core/array/element_reference_spec.rb | FAILED: expected TypeError to be raised |
| core/array/initialize_spec.rb | ERROR: Array#initialize with no arguments does not use the given block: RuntimeError -- |
| core/array/initialize_spec.rb | ERROR: Array#initialize with (array) does not use the given block: RuntimeError -- |
| core/array/initialize_spec.rb | FAILED: uses the block value instead of using the default value: matcher did not match #<Proc> |
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
| core/enumerable/inject_spec.rb | FAILED: ignores the block if two arguments: matcher did not match #<Proc> |
| core/enumerable/inject_spec.rb | ERROR: Enumerable#inject ignores the block if two arguments: RuntimeError -- we never get here |
| core/enumerable/inject_spec.rb | FAILED: tolerates increasing a collection size during iterating Array: expected [0, 1, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 2, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 3, 30, 31, 32, 33, 34, 35, 36, 37, 38, 39, 4, 40, 41, 42, 43, 44, 45,  ...[clipped] |
| core/enumerable/map_spec.rb | FAILED: reports the same arity as the given block: expected [2], got [-2] |
| core/enumerable/map_spec.rb | FAILED: reports the same arity as the given block: expected [1], got [-2] |
| core/enumerable/map_spec.rb | ERROR: Enumerable#map yields 2 arguments for a Hash when block arity is 2: ArgumentError -- wrong number of arguments (given 1, expected 2) |
| core/enumerable/tally_spec.rb | FAILED: ignores the default value: expected {...}, got {...} |
| core/enumerable/tally_spec.rb | FAILED: ignores the default proc: expected {...}, got {...} |
| core/enumerable/tally_spec.rb | pass=14 fail=2 err=0 |
| core/enumerable/to_h_spec.rb | ERROR: Enumerable#to_h forwards arguments to #each: NoMethodError -- undefined method 'to_h' for #<Object:0xADDR> |
| core/enumerable/to_h_spec.rb | pass=13 fail=0 err=1 |
| core/enumerable/to_set_spec.rb | FAILED: instantiates an object of provided as the first argument set class: matcher did not match #<Proc> |
| core/enumerable/to_set_spec.rb | pass=5 fail=1 err=0 |
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
| core/exception/backtrace_spec.rb | pass=19 fail=0 err=0 |
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
| core/exception/syntax_error_spec.rb | FAILED: raised StandardError, expected SyntaxError |
| core/exception/syntax_error_spec.rb | pass=2 fail=1 err=0 |
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
| core/hash/element_reference_spec.rb | FAILED: does not dispatch to hash for Boolean, Integer, Float, String, or Symbol: expected "Ok. |
| core/hash/element_reference_spec.rb | pass=30 fail=1 err=0 |
| core/hash/element_set_spec.rb | FAILED: stores unequal keys that hash to the same value: expected to receive #hash |
| core/hash/element_set_spec.rb | FAILED: stores unequal keys that hash to the same value: expected to receive #hash |
| core/hash/element_set_spec.rb | FAILED: does not dispatch to hash for Boolean, Integer, Float, String, or Symbol: expected "OK |
| core/hash/inspect_spec.rb | FAILED: returns a string representation with same order as each(): expected "{:a=>[1, 2], :b=>-2, :d=>-6, nil=>nil}", got "{a: [1, 2], b: -2, d: -6, nil => nil}" |
| core/hash/inspect_spec.rb | FAILED: calls #inspect on keys and values: expected "{key=>val}", got "{key => val}" |
| core/hash/inspect_spec.rb | FAILED: does not call #to_s on a String returned from #inspect: expected "{:a=>\"abc\"}", got "{a: \"abc\"}" |
| core/hash/rehash_spec.rb | FAILED: reorganizes the Hash by recomputing all key hash codes: expected false, got true |
| core/hash/rehash_spec.rb | pass=22 fail=1 err=0 |
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
| core/kernel/__dir___spec.rb | FAILED: returns the expanded path of the directory when used in the main script: expected "__dir__.rb |
| core/kernel/__dir___spec.rb | FAILED: returns File.dirname(filename): expected ".", got "HOME" |
| core/kernel/__dir___spec.rb | FAILED: returns File.dirname(filename): expected "foo", got "HOME" |
| core/kernel/autoload_spec.rb | FAILED: is a private method: expected truthy from #include? |
| core/kernel/autoload_spec.rb | FAILED: raised LoadError, expected NameError |
| core/kernel/autoload_spec.rb | FAILED: should define on the new anonymous class: expected "bogus", got nil |
| core/kernel/backtick_spec.rb | ERROR: Kernel#` lets the standard error stream pass through to the inherited stderr: NoMethodError -- undefined method 'ruby_cmd' for an instance of Object |
| core/kernel/backtick_spec.rb | FAILED: produces a String in the default external encoding: expected to be identical |
| core/kernel/backtick_spec.rb | FAILED: expected Errno::ENOENT to be raised |
| core/kernel/binding_spec.rb | ERROR: Kernel#binding encapsulates the execution context properly: NameError -- undefined local variable or method 'b' for an instance of KernelSpecs::Binding |
| core/kernel/binding_spec.rb | pass=9 fail=0 err=1 |
| core/kernel/block_given_spec.rb | FAILED: returns false when a method defined by define_method is called with a block: expected false, got true |
| core/kernel/block_given_spec.rb | FAILED: returns false outside of a method: expected false, got true |
| core/kernel/block_given_spec.rb | pass=11 fail=2 err=0 |
| core/kernel/caller_locations_spec.rb | FAILED: returns an Array of caller locations using a custom offset: expected truthy from #end_with? |
| core/kernel/caller_locations_spec.rb | pass=24 fail=1 err=0 |
| core/kernel/caller_locations_spec.rb | FAILED: returns an Array of caller locations using a custom offset: expected truthy from #end_with? |
| core/kernel/caller_spec.rb | FAILED: returns an Array of caller locations using a custom offset: expected "TMPDIR 'Object#it'" to match |
| core/kernel/caller_spec.rb | FAILED: returns an Array with the block given to #at_exit at the base of the stack: expected 2, got 0 |
| core/kernel/caller_spec.rb | FAILED: returns an Array with the block given to #at_exit at the base of the stack: expected nil to match |
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
| core/kernel/eval_spec.rb | FAILED: does not share locals across eval scopes: expected "NameError", got "" |
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
| core/kernel/open_spec.rb | ERROR: Kernel#open is a private method: ArgumentError -- path component of HOME is a file |
| core/kernel/open_spec.rb | ERROR: Kernel#open opens a file when given a valid filename: ArgumentError -- path component of HOME is a file |
| core/kernel/open_spec.rb | ERROR: Kernel#open opens a file when called with a block: ArgumentError -- path component of HOME is a file |
| core/kernel/p_spec.rb | ERROR: Kernel#p flushes output if receiver is a File: ArgumentError -- path component of HOME is a file |
| core/kernel/p_spec.rb | ERROR: Kernel#p is not affected by setting $\, $/ or $,: NoMethodError -- undefined method 'output_to_fd' for an instance of Object |
| core/kernel/p_spec.rb | ERROR: Kernel#p prints nothing if no argument is given: NameError -- undefined local variable or method 'p' for an instance of Object |
| core/kernel/print_spec.rb | FAILED: prints $_ when no arguments are given: matcher did not match #<Proc> |
| core/kernel/print_spec.rb | pass=3 fail=1 err=0 |
| core/kernel/printf_spec.rb | ERROR: Kernel#printf is a private method: ArgumentError -- path component of HOME is a file |
| core/kernel/printf_spec.rb | ERROR: Kernel#printf writes to stdout when a string is the first argument: ArgumentError -- path component of HOME is a file |
| core/kernel/printf_spec.rb | ERROR: Kernel#printf calls write on the first argument when it is not a string: ArgumentError -- path component of HOME is a file |
| core/kernel/public_method_spec.rb | FAILED: expected NameError to be raised |
| core/kernel/public_method_spec.rb | pass=4 fail=1 err=0 |
| core/kernel/putc_spec.rb | ERROR: Kernel#putc is a private method: ArgumentError -- path component of HOME is a file |
| core/kernel/putc_spec.rb | pass=1 fail=0 err=1 |
| core/kernel/putc_spec.rb | ERROR: Kernel#putc is a private method: NoMethodError -- undefined method 'new_io' for an instance of Object |
| core/kernel/puts_spec.rb | ERROR: Kernel#puts is a private method: ArgumentError -- path component of HOME is a file |
| core/kernel/puts_spec.rb | ERROR: Kernel#puts delegates to $stdout.puts: ArgumentError -- path component of HOME is a file |
| core/kernel/puts_spec.rb | pass=1 fail=0 err=2 |
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
| core/kernel/srand_spec.rb | FAILED: seeds the RNG correctly and repeatably: expected 0.712948233, got 0.505604652 |
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
| core/kernel/warn_spec.rb | ERROR: Kernel#warn does not write strings when passed no arguments: NameError -- undefined local variable or method 'warn' for an instance of Object |
| core/kernel/warn_spec.rb | FAILED: prepends a message with specified line from the backtrace: matcher did not match #<Proc> |
| core/kernel/warn_spec.rb | FAILED: prepends a message with specified line from the backtrace: matcher did not match #<Proc> |
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
| core/proc/ruby2_keywords_spec.rb | FAILED: prints warning when a proc does not accept argument splat: matcher did not match #<Proc> |
| core/proc/ruby2_keywords_spec.rb | FAILED: prints warning when a proc accepts keywords: matcher did not match #<Proc> |
| core/proc/ruby2_keywords_spec.rb | FAILED: prints warning when a proc accepts keyword splat: matcher did not match #<Proc> |
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
| core/range/to_set_spec.rb | FAILED: instantiates an object of provided as the first argument set class and warns: matcher did not match #<Proc> |
| core/range/to_set_spec.rb | pass=8 fail=1 err=0 |
| core/rational/exponent_spec.rb | FAILED: expected ZeroDivisionError to be raised |
| core/rational/exponent_spec.rb | pass=38 fail=1 err=0 |
| core/rational/round_spec.rb | ERROR: with half option returns an Integer when precision is not passed: TypeError -- not an integer |
| core/rational/round_spec.rb | FAILED: returns a Rational when the precision is greater than 0: expected (1/5), got (3/10) |
| core/rational/round_spec.rb | FAILED: returns a Rational when the precision is greater than 0: expected (1/5), got (3/10) |
| core/rational/to_f_spec.rb | FAILED: converts to a Float for large numerator and denominator: expected 500.0, got NaN |
| core/rational/to_f_spec.rb | pass=0 fail=1 err=0 |
| core/rational/to_r_spec.rb | FAILED: expected TypeError to be raised |
| core/rational/to_r_spec.rb | pass=4 fail=1 err=0 |
| core/regexp/equal_value_spec.rb | FAILED: is true if self and other have the same character set code: expected false, got true |
| core/regexp/equal_value_spec.rb | pass=10 fail=1 err=0 |
| core/regexp/initialize_spec.rb | FAILED: raised FrozenError, expected TypeError |
| core/regexp/initialize_spec.rb | FAILED: raised NoMethodError, expected TypeError |
| core/regexp/initialize_spec.rb | pass=2 fail=2 err=0 |
| core/regexp/last_match_spec.rb | FAILED: expected IndexError to be raised |
| core/regexp/last_match_spec.rb | FAILED: coerces argument to an index using #to_int: expected "TEST123", got nil |
| core/regexp/last_match_spec.rb | FAILED: coerces argument to an index using #to_int: expected to receive #to_int |
| core/regexp/linear_time_spec.rb | FAILED: warns about flags being ignored for regexp arguments: matcher did not match #<Proc> |
| core/regexp/linear_time_spec.rb | pass=9 fail=1 err=0 |
| core/regexp/match_spec.rb | FAILED: expected ArgumentError to be raised |
| core/regexp/match_spec.rb | FAILED: expected ArgumentError to be raised |
| core/regexp/match_spec.rb | ERROR: when passed a block yields the MatchData: NoMethodError -- undefined method 'match' for an instance of Regexp |
| core/regexp/options_spec.rb | FAILED: expected not 0 |
| core/regexp/options_spec.rb | FAILED: expected not 0 |
| core/regexp/options_spec.rb | pass=18 fail=2 err=0 |
| core/regexp/timeout_spec.rb | ERROR: Regexp.timeout raises Regexp::TimeoutError after global timeout elapsed: NameError -- uninitialized constant Regexp::TimeoutError |
| core/regexp/timeout_spec.rb | ERROR: Regexp.timeout raises Regexp::TimeoutError after timeout keyword value elapsed: NameError -- uninitialized constant Regexp::TimeoutError |
| core/regexp/timeout_spec.rb | pass=3 fail=0 err=2 |
| core/string/bytesplice_spec.rb | FAILED: raised ArgumentError, expected IndexError |
| core/string/bytesplice_spec.rb | FAILED: raised ArgumentError, expected IndexError |
| core/string/bytesplice_spec.rb | FAILED: raised ArgumentError, expected IndexError |
| core/string/index_spec.rb | FAILED: always clear $~: expected nil, got #<MatchData "a"> |
| core/string/index_spec.rb | pass=741 fail=1 err=0 |
| core/string/uplus_spec.rb | FAILED: returns mutable copy of a literal: expected "mutable", got "" |
| core/string/uplus_spec.rb | FAILED: returns mutable copy of a literal: expected false, got true |
| core/string/uplus_spec.rb | pass=5 fail=2 err=0 |
| core/struct/deconstruct_keys_spec.rb | FAILED: tries to convert a key with #to_int if index is not a String nor a Symbol, but responds to #to_int: expected {#<MockObject to_int> => 2}, got {} |
| core/struct/deconstruct_keys_spec.rb | FAILED: tries to convert a key with #to_int if index is not a String nor a Symbol, but responds to #to_int: expected to receive #to_int |
| core/struct/deconstruct_keys_spec.rb | FAILED: raises a TypeError if the conversion with #to_int does not return an Integer: matcher did not match #<Proc> |
| core/struct/hash_spec.rb | FAILED: allows for overriding methods in an included module: expected "different", got 527 |
| core/struct/hash_spec.rb | ERROR: Struct#hash returns the same hash for recursive structs: SystemStackError -- stack level too deep |
| core/struct/hash_spec.rb | FAILED: expected not 528 |
| core/struct/initialize_spec.rb | FAILED: can be overridden: expected :value, got nil |
| core/struct/initialize_spec.rb | FAILED: can be initialized with keyword arguments: expected {version: "3.2", platform: "OS"}, got "3.2" |
| core/struct/initialize_spec.rb | FAILED: can be initialized with keyword arguments: expected nil, got "OS" |
| core/struct/new_spec.rb | FAILED: overwrites previously defined constants with string as first argument: matcher did not match #<Proc> |
| core/struct/new_spec.rb | ERROR: with a block passes same struct class to the block: NoMethodError -- undefined method 'block_parameter' for class #<Class:0xADDR> |
| core/struct/new_spec.rb | FAILED: accepts keyword arguments to initialize: expected #<struct args=42>, got #<struct args={args: 42}> |
| core/symbol/all_symbols_spec.rb | ERROR: Symbol.all_symbols returns an array of Symbols: NoMethodError -- undefined method 'all_symbols' for class Symbol |
| core/symbol/all_symbols_spec.rb | ERROR: Symbol.all_symbols includes symbols that are strongly referenced: NoMethodError -- undefined method 'all_symbols' for class Symbol |
| core/symbol/all_symbols_spec.rb | ERROR: Symbol.all_symbols includes symbols that are referenced in source code but not yet executed: NoMethodError -- undefined method 'all_symbols' for class Symbol |
| core/symbol/element_reference_spec.rb | FAILED: converts the last value to an Integer: expected "sym", got "symbol" |
| core/symbol/element_reference_spec.rb | ERROR: with a Range subclass slice returns a slice: TypeError -- no implicit conversion of Object into Integer |
| core/symbol/element_reference_spec.rb | FAILED: returns a string for the matched capture at the given index: expected "ol", got nil |
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
| language/block_spec.rb | FAILED: assigns the first variable named: expected 1, got 2 |
| language/block_spec.rb | FAILED: expected SyntaxError to be raised |
| language/break_spec.rb | FAILED: returns from the lambda: expected [:a, :d, :aaa, :b, :bbb, :e], got [:a, :d, :aaa, :b, :e] |
| language/break_spec.rb | FAILED: returns a value when invoking from the toplevel: expected "a,b,break,d", got "" |
| language/break_spec.rb | FAILED: returns a value when invoking from a method: expected "a,d,b,break,e,f", got "" |
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
| language/execution_spec.rb | FAILED: can be redefined and receive a frozen string as argument: expected true, got false |
| language/execution_spec.rb | FAILED: can be redefined and receive a frozen string as argument: expected true, got false |
| language/execution_spec.rb | pass=16 fail=2 err=0 |
| language/hash_spec.rb | FAILED: freezes string keys on initialization: expected "bar", got nil |
| language/hash_spec.rb | FAILED: freezes string keys on initialization: expected "foo", got "oof" |
| language/hash_spec.rb | FAILED: checks duplicated keys on initialization: matcher did not match #<Proc> |
| language/if_spec.rb | FAILED: warns when Integer literals are used instead of predicates: matcher did not match #<Proc> |
| language/if_spec.rb | FAILED: warns when Integer literals are used instead of predicates: expected [], got [0, 1, 2, 3, 4, 5, 6, 7, 8, 9] |
| language/if_spec.rb | pass=59 fail=2 err=0 |
| language/it_parameter_spec.rb | ERROR: The `it` parameter provides it in a block: ArgumentError -- wrong number of arguments (given 1, expected 0) |
| language/it_parameter_spec.rb | ERROR: The `it` parameter can be used in both outer and nested blocks at the same time: ArgumentError -- wrong number of arguments (given 1, expected 0) |
| language/it_parameter_spec.rb | FAILED: expected SyntaxError to be raised |
| language/lambda_spec.rb | FAILED: has its own scope for local variables: expected to be identical |
| language/lambda_spec.rb | FAILED: has its own scope for local variables: expected [9, 8, [7], [], 6, 5, 4, 3, {}, #<Proc:0xADDR TMPDIR (lambda)>], got [9, 8, [7], [], 6, 5, 4, 3, {}, #<Proc:0xADDR TMPDIR |
| language/lambda_spec.rb | FAILED: has its own scope for local variables: expected [1, 1, [], 2, 3, 2, 4, {h: 5, i: 6}, #<Proc:0xADDR TMPDIR (lambda)>], got [1, 1, [], 2, 3, 2, 4, {h: 5, i: 6}, #<Proc:0xADDR TMPDIR |
| language/method_spec.rb | FAILED: expected ArgumentError to be raised |
| language/method_spec.rb | FAILED: expected ArgumentError to be raised |
| language/method_spec.rb | FAILED: expected ArgumentError to be raised |
| language/module_spec.rb | ERROR: Assigning an anonymous module to a constant sets the name of a module scoped by an anonymous module: NoMethodError -- undefined method 'end_with?' |
| language/module_spec.rb | pass=15 fail=0 err=1 |
| language/predefined_spec.rb | FAILED: is set at the method-scoped level rather than block-scoped: expected #<MatchData "bar">, got #<MatchData "foo"> |
| language/predefined_spec.rb | FAILED: is set at the method-scoped level rather than block-scoped: expected #<MatchData "qux">, got #<MatchData "baz"> |
| language/predefined_spec.rb | ERROR: Predefined global $! is Fiber-local: NoMethodError -- undefined method 'yield' for class Fiber |
| language/proc_spec.rb | FAILED: expected ArgumentError to be raised |
| language/proc_spec.rb | FAILED: expected ArgumentError to be raised |
| language/proc_spec.rb | FAILED: expected ArgumentError to be raised |
| language/regexp_spec.rb | FAILED: expected not true |
| language/regexp_spec.rb | FAILED: matches against $_ (last input) in a conditional if no explicit matchee provided: matcher did not match #<Proc> |
| language/regexp_spec.rb | ERROR: Literal Regexps supports paired delimiters with %r: SyntaxError -- syntax error |
| language/rescue_spec.rb | FAILED: in a global variable: expected "some text", got "" |
| language/rescue_spec.rb | FAILED: converts the splatted list of exceptions using #to_a: expected to receive #to_a |
| language/rescue_spec.rb | FAILED: expected SyntaxError to be raised |
| language/return_spec.rb | ERROR: at top level stops file execution: ArgumentError -- path component of HOME is a file |
| language/return_spec.rb | ERROR: within if is allowed: ArgumentError -- path component of HOME is a file |
| language/return_spec.rb | ERROR: within while loop is allowed: ArgumentError -- path component of HOME is a file |
| language/send_spec.rb | FAILED: raises TypeError if 'to_proc' doesn't return a Proc: matcher did not match #<Proc> |
| language/send_spec.rb | FAILED: raised NoMethodError, expected TypeError |
| language/send_spec.rb | FAILED: calls #to_a to convert a final splatted Hash object to an Array: expected [1, 2, 3, :a, 1], got [1, 2, 3, [:a, 1]] |
| language/source_encoding_spec.rb | FAILED: can be parsed: expected "hello |
| language/source_encoding_spec.rb | FAILED: can be parsed: expected "hello |
| language/source_encoding_spec.rb | ERROR: encoded in UTF-16 LE with a BOM are invalid because they contain an invalid UTF-8 sequence before the encoding comment: ArgumentError -- path component of HOME is a file |
| language/string_spec.rb | FAILED: backslashes follow the same rules as interpolation: expected " |
| language/string_spec.rb | FAILED: expected NoMethodError to be raised |
| language/string_spec.rb | ERROR: Ruby character strings allows a dynamic string to parse a nested do...end block as an argument to a call without parens, interpolated: SyntaxError -- syntax error |
| language/variables_spec.rb | FAILED: expected SyntaxError to be raised |
| language/variables_spec.rb | FAILED: warns about accessing uninitialized global variable in verbose mode: matcher did not match #<Proc> |
| language/variables_spec.rb | pass=170 fail=2 err=0 |

# mere-ruby — the examples that actually fail

One row per recorded DIFF file, holding the first few FAILED / ERROR
lines the harness prints for it. `CAUSES.md` groups the record; this
runs the specs again, because a recorded row is the first DIVERGENCE in
a file and not the diagnosis.

Regenerate with `./mspec/examples.sh <spec-root>` (slow: it runs every
file below, both sides). Paths and addresses are masked by mask.sh.

Visited **148** of **148** recorded DIFF files.

| file | what fails |
|---|---|
| core/array/element_reference_spec.rb | pass=253 fail=2 err=10 pass=459 fail=0 err=1 |
| core/array/element_reference_spec.rb | ERROR: with a subclass of Array raises a RangeError when the start index is out of range of Fixnum: NameError -- undefined local variable or method 'max_long' for an instance of Object |
| core/array/element_reference_spec.rb | FAILED: expected RangeError to be raised |
| core/array/element_reference_spec.rb | FAILED: expected TypeError to be raised |
| core/array/initialize_spec.rb | pass=31 fail=1 err=2 pass=32 fail=0 err=2 |
| core/array/initialize_spec.rb | ERROR: Array#initialize with no arguments does not use the given block: RuntimeError -- |
| core/array/initialize_spec.rb | ERROR: Array#initialize with (array) does not use the given block: RuntimeError -- |
| core/array/initialize_spec.rb | FAILED: uses the block value instead of using the default value: matcher did not match #<Proc> |
| core/array/intersect_spec.rb | pass=12 fail=1 err=0 pass=13 fail=0 err=0 |
| core/array/shuffle_spec.rb | pass=42 fail=2 err=0 pass=44 fail=0 err=0 |
| core/array/shuffle_spec.rb | FAILED: matches CRuby with random:: expected [2, 6, 8, 5, 7, 10, 3, 1, 0, 4, 9], got [1, 8, 5, 9, 7, 3, 0, 4, 10, 2, 6] |
| core/complex/inspect_spec.rb | pass=7 fail=0 err=2 pass=9 fail=0 err=0 |
| core/complex/inspect_spec.rb | ERROR: Complex#inspect calls #inspect on real and imaginary: TypeError -- not a real |
| core/complex/to_s_spec.rb | pass=13 fail=0 err=1 pass=14 fail=0 err=0 |
| core/enumerable/chunk_spec.rb | pass=10 fail=1 err=0 pass=11 fail=0 err=0 |
| core/enumerable/inject_spec.rb | pass=41 fail=2 err=1 pass=45 fail=0 err=0 |
| core/enumerable/inject_spec.rb | FAILED: ignores the block if two arguments: matcher did not match #<Proc> |
| core/enumerable/inject_spec.rb | ERROR: Enumerable#inject ignores the block if two arguments: RuntimeError -- we never get here |
| core/enumerable/map_spec.rb | pass=13 fail=2 err=1 pass=16 fail=0 err=0 |
| core/enumerable/map_spec.rb | FAILED: reports the same arity as the given block: expected [2], got [-2] |
| core/enumerable/map_spec.rb | FAILED: reports the same arity as the given block: expected [1], got [-2] |
| core/enumerable/tally_spec.rb | pass=14 fail=2 err=0 pass=16 fail=0 err=0 |
| core/enumerable/tally_spec.rb | FAILED: ignores the default value: expected {...}, got {...} |
| core/enumerable/to_h_spec.rb | pass=13 fail=0 err=1 pass=14 fail=0 err=0 |
| core/enumerable/to_set_spec.rb | pass=5 fail=1 err=0 pass=6 fail=0 err=0 |
| core/env/each_pair_spec.rb | pass=33 fail=20 err=0 pass=53 fail=0 err=0 |
| core/env/each_pair_spec.rb | FAILED: transcodes from the locale encoding to Encoding.default_internal if set: expected to be identical |
| core/env/each_pair_spec.rb | FAILED: transcodes from the locale encoding to Encoding.default_internal if set: expected to be identical |
| core/env/each_pair_spec.rb | FAILED: transcodes from the locale encoding to Encoding.default_internal if set: expected to be identical |
| core/env/merge_spec.rb | pass=7 fail=6 err=5 pass=21 fail=0 err=0 |
| core/env/merge_spec.rb | FAILED: adds the multiple parameter hashes to ENV, returning ENV: expected "multi2", got nil |
| core/env/merge_spec.rb | ERROR: ENV.merge! yields key, the old value and the new value when replacing an entry: NotImplementedError -- mere-ruby: ENV.merge! is not implemented (it would change the environment) |
| core/env/merge_spec.rb | ERROR: ENV.merge! yields key, the old value and the new value when replacing an entry: NotImplementedError -- mere-ruby: ENV.merge! is not implemented (it would change the environment) |
| core/env/replace_spec.rb | pass=6 fail=9 err=0 pass=15 fail=0 err=0 |
| core/env/replace_spec.rb | FAILED: expected TypeError to be raised |
| core/env/replace_spec.rb | FAILED: raises TypeError if a key is not a String: expected {...}, got {...} |
| core/env/replace_spec.rb | FAILED: expected TypeError to be raised |
| core/env/shift_spec.rb | pass=6 fail=2 err=0 pass=8 fail=0 err=0 |
| core/env/shift_spec.rb | FAILED: transcodes from the locale encoding to Encoding.default_internal if set: expected to be identical |
| core/exception/backtrace_locations_spec.rb | pass=2 fail=1 err=0 pass=3 fail=0 err=0 |
| core/exception/backtrace_spec.rb | pass=19 fail=0 err=0 pass=21 fail=0 err=0 |
| core/exception/backtrace_spec.rb | (nothing failed -- the record may be stale) |
| core/exception/full_message_spec.rb | pass=25 fail=29 err=2 pass=46 fail=11 err=0 |
| core/exception/full_message_spec.rb | FAILED: supports :highlight option and adds escape sequences to highlight some strings: expected "\e[1mTraceback\e[m (most recent call last): |
| core/exception/full_message_spec.rb | FAILED: supports :highlight option and adds escape sequences to highlight some strings: expected "Traceback (most recent call last): |
| core/exception/interrupt_spec.rb | pass=4 fail=1 err=1 pass=7 fail=0 err=0 |
| core/exception/interrupt_spec.rb | ERROR: rescuing Interrupt raises an Interrupt when sent a signal SIGINT: NoMethodError -- undefined method 'kill' for module Process |
| core/exception/signal_exception_spec.rb | pass=22 fail=1 err=2 pass=26 fail=0 err=1 |
| core/exception/signal_exception_spec.rb | FAILED: expected ArgumentError to be raised |
| core/exception/signal_exception_spec.rb | ERROR: rescuing SignalException raises a SignalException when sent a signal: NoMethodError -- undefined method 'kill' for module Process |
| core/exception/signal_exception_spec.rb | ERROR: SignalException can be rescued: SystemExit -- exit |
| core/exception/signm_spec.rb | pass=0 fail=1 err=0 pass=1 fail=0 err=0 |
| core/exception/signo_spec.rb | pass=0 fail=1 err=0 pass=1 fail=0 err=0 |
| core/exception/syntax_error_spec.rb | pass=2 fail=1 err=0 pass=3 fail=0 err=0 |
| core/exception/system_exit_spec.rb | pass=18 fail=0 err=2 pass=18 fail=0 err=2 |
| core/exception/system_exit_spec.rb | ERROR: #initialize sets the exit status and exits silently when raised: SystemExit -- SystemExit |
| core/exception/system_exit_spec.rb | ERROR: #initialize sets the exit status and exits silently when raised when subclassed: CustomExit -- CustomExit |
| core/exception/system_exit_spec.rb | ERROR: #initialize sets the exit status and exits silently when raised: NoMethodError -- undefined method 'exitstatus' for nil |
| core/exception/top_level_spec.rb | pass=0 fail=5 err=1 pass=0 fail=5 err=1 |
| core/exception/top_level_spec.rb | FAILED: is printed on STDERR: expected "" to match |
| core/exception/top_level_spec.rb | FAILED: the Exception#cause is printed to STDERR with backtraces: expected nil to match |
| core/exception/top_level_spec.rb | ERROR: An Exception reaching the top level the Exception#cause is printed to STDERR with backtraces: RuntimeError -- wrapped |
| core/float/next_float_spec.rb | pass=11 fail=2 err=0 pass=13 fail=0 err=0 |
| core/float/next_float_spec.rb | FAILED: returns a float the smallest possible step greater than the receiver: expected truthy from #< |
| core/float/prev_float_spec.rb | pass=11 fail=2 err=0 pass=13 fail=0 err=0 |
| core/float/prev_float_spec.rb | FAILED: returns a float the smallest possible step smaller than the receiver: expected truthy from #> |
| core/float/round_spec.rb | pass=37 fail=2 err=2 pass=40 fail=0 err=0 |
| core/float/round_spec.rb | ERROR: Float#round returns different rounded values depending on the half option: TypeError -- no implicit conversion of Hash into Integer |
| core/float/round_spec.rb | FAILED: raised TypeError, expected ArgumentError |
| core/float/round_spec.rb | FAILED: returns self for positive ndigits: expected "-0.0", got "0.0" |
| core/float/to_s_spec.rb | pass=169 fail=6 err=0 pass=175 fail=0 err=0 |
| core/float/to_s_spec.rb | FAILED: uses non-e format for a positive value with whole part having 15 significant figures: expected "10000000000000.0", got "1.0e+13" |
| core/float/to_s_spec.rb | FAILED: uses non-e format for a negative value with whole part having 15 significant figures: expected "-10000000000000.0", got "-1.0e+13" |
| core/float/to_s_spec.rb | FAILED: uses non-e format for a positive value with whole part having 16 significant figures: expected "100000000000000.0", got "1.0e+14" |
| core/hash/compare_by_identity_spec.rb | pass=32 fail=0 err=1 pass=33 fail=0 err=0 |
| core/hash/element_reference_spec.rb | pass=30 fail=1 err=0 pass=31 fail=0 err=0 |
| core/hash/element_set_spec.rb | pass=17 fail=3 err=0 pass=18 fail=0 err=0 |
| core/hash/element_set_spec.rb | FAILED: stores unequal keys that hash to the same value: expected to receive #hash |
| core/hash/element_set_spec.rb | FAILED: stores unequal keys that hash to the same value: expected to receive #hash |
| core/hash/inspect_spec.rb | pass=7 fail=13 err=1 pass=9 fail=12 err=0 |
| core/hash/inspect_spec.rb | FAILED: returns a string representation with same order as each(): expected "{:a=>[1, 2], :b=>-2, :d=>-6, nil=>nil}", got "{a: [1, 2], b: -2, d: -6, nil => nil}" |
| core/hash/inspect_spec.rb | FAILED: calls #inspect on keys and values: expected "{key=>val}", got "{key => val}" |
| core/hash/inspect_spec.rb | FAILED: does not call #to_s on a String returned from #inspect: expected "{:a=>\"abc\"}", got "{a: \"abc\"}" |
| core/hash/rehash_spec.rb | pass=22 fail=1 err=0 pass=23 fail=0 err=0 |
| core/integer/coerce_spec.rb | pass=19 fail=5 err=0 pass=24 fail=0 err=0 |
| core/integer/coerce_spec.rb | FAILED: expected TypeError to be raised |
| core/integer/coerce_spec.rb | FAILED: expected TypeError to be raised |
| core/integer/coerce_spec.rb | FAILED: expected TypeError to be raised |
| core/integer/round_spec.rb | pass=5 fail=3 err=1 pass=7 fail=1 err=0 |
| core/integer/round_spec.rb | FAILED: raised NameError, expected RangeError |
| core/integer/round_spec.rb | ERROR: Integer#round calls #to_int on the argument to convert it to an Integer: TypeError -- no implicit conversion of Object into Integer |
| core/integer/round_spec.rb | FAILED: expected ArgumentError to be raised |
| core/integer/upto_spec.rb | pass=6 fail=11 err=0 pass=17 fail=0 err=0 |
| core/integer/upto_spec.rb | FAILED: yields while increasing self until it is greater than floor of a Float endpoint: expected [9, 10, 11, 12, 13, -5, -4, -3, -2], got [9, 10, 11, 12, 13, -5, -4, -3, -2, -1] |
| core/integer/upto_spec.rb | FAILED: expected ArgumentError to be raised |
| core/integer/upto_spec.rb | FAILED: expected ArgumentError to be raised |
| core/kernel/Integer_spec.rb | pass=327 fail=1 err=0 pass=328 fail=0 err=0 |
| core/kernel/__dir___spec.rb | pass=3 fail=4 err=0 pass=6 fail=1 err=0 |
| core/kernel/__dir___spec.rb | FAILED: returns the expanded path of the directory when used in the main script: expected "__dir__.rb |
| core/kernel/__dir___spec.rb | FAILED: returns File.dirname(filename): expected ".", got "HOME" |
| core/kernel/__dir___spec.rb | FAILED: returns File.dirname(filename): expected "foo", got "HOME" |
| core/kernel/autoload_spec.rb | pass=10 fail=14 err=6 pass=23 fail=1 err=8 |
| core/kernel/autoload_spec.rb | FAILED: is a private method: expected truthy from #include? |
| core/kernel/autoload_spec.rb | FAILED: raised LoadError, expected NameError |
| core/kernel/autoload_spec.rb | FAILED: should define on the new anonymous class: expected "bogus", got nil |
| core/kernel/backtick_spec.rb | pass=2 fail=4 err=1 pass=5 fail=0 err=1 |
| core/kernel/backtick_spec.rb | ERROR: Kernel#` lets the standard error stream pass through to the inherited stderr: NoMethodError -- undefined method 'ruby_cmd' for an instance of Object |
| core/kernel/backtick_spec.rb | FAILED: produces a String in the default external encoding: expected to be identical |
| core/kernel/backtick_spec.rb | FAILED: expected Errno::ENOENT to be raised |
| core/kernel/binding_spec.rb | pass=9 fail=0 err=1 pass=14 fail=0 err=0 |
| core/kernel/block_given_spec.rb | pass=11 fail=2 err=0 pass=13 fail=0 err=0 |
| core/kernel/block_given_spec.rb | FAILED: returns false when a method defined by define_method is called with a block: expected false, got true |
| core/kernel/caller_locations_spec.rb | pass=24 fail=1 err=0 pass=26 fail=1 err=0 |
| core/kernel/caller_locations_spec.rb | FAILED: returns an Array of caller locations using a custom offset: expected truthy from #end_with? |
| core/kernel/caller_spec.rb | pass=18 fail=6 err=0 pass=20 fail=4 err=0 |
| core/kernel/caller_spec.rb | FAILED: returns an Array of caller locations using a custom offset: expected "TMPDIR 'Object#it'" to match |
| core/kernel/caller_spec.rb | FAILED: returns an Array with the block given to #at_exit at the base of the stack: expected 2, got 0 |
| core/kernel/caller_spec.rb | FAILED: returns an Array with the block given to #at_exit at the base of the stack: expected nil to match |
| core/kernel/chomp_spec.rb | pass=2 fail=0 err=8 pass=2 fail=0 err=8 |
| core/kernel/chomp_spec.rb | ERROR: Kernel#chomp is a private method only when -n is passed: NoMethodError -- undefined method 'popen' for class IO |
| core/kernel/chomp_spec.rb | ERROR: Kernel#chomp removes the final newline of $_: NoMethodError -- undefined method 'popen' for class IO |
| core/kernel/chomp_spec.rb | ERROR: Kernel#chomp removes the final carriage return of $_: NoMethodError -- undefined method 'popen' for class IO |
| core/kernel/chop_spec.rb | pass=2 fail=0 err=5 pass=2 fail=0 err=5 |
| core/kernel/chop_spec.rb | ERROR: Kernel#chop is a private method only when -n is passed: NoMethodError -- undefined method 'popen' for class IO |
| core/kernel/chop_spec.rb | ERROR: Kernel#chop removes the final character of $_: NoMethodError -- undefined method 'popen' for class IO |
| core/kernel/chop_spec.rb | ERROR: Kernel#chop removes the final carriage return, newline of $_: NoMethodError -- undefined method 'popen' for class IO |
| core/kernel/define_singleton_method_spec.rb | pass=11 fail=3 err=1 pass=14 fail=0 err=1 |
| core/kernel/define_singleton_method_spec.rb | FAILED: raised NoMethodError, expected TypeError |
| core/kernel/define_singleton_method_spec.rb | FAILED: raised NoMethodError, expected ArgumentError |
| core/kernel/define_singleton_method_spec.rb | FAILED: raised NoMethodError, expected ArgumentError |
| core/kernel/eval_spec.rb | pass=81 fail=11 err=10 pass=99 fail=3 err=0 |
| core/kernel/eval_spec.rb | ERROR: Kernel#eval evaluates within the scope of the eval: NameError -- uninitialized constant EvalSpecs::A::B |
| core/kernel/eval_spec.rb | ERROR: Kernel#eval evaluates such that constants are scoped to the class of the eval: NameError -- uninitialized constant EvalSpecs::A::C |
| core/kernel/eval_spec.rb | FAILED: does not share locals across eval scopes: expected "NameError", got "" |
| core/kernel/gets_spec.rb | pass=2 fail=2 err=0 pass=3 fail=0 err=0 |
| core/kernel/gets_spec.rb | FAILED: calls ARGF.gets: expected "spec", got nil |
| core/kernel/inspect_spec.rb | pass=7 fail=1 err=0 pass=8 fail=0 err=0 |
| core/kernel/lambda_spec.rb | pass=19 fail=2 err=1 pass=21 fail=0 err=1 |
| core/kernel/lambda_spec.rb | ERROR: Kernel#lambda strictly checks the arity when 0 or 2..inf args are specified: ArgumentError -- ArgumentError |
| core/kernel/lambda_spec.rb | FAILED: treats the block as a Proc when lambda is re-defined: expected 1, got 2 |
| core/kernel/lambda_spec.rb | FAILED: expected ArgumentError to be raised |
| core/kernel/loop_spec.rb | pass=7 fail=1 err=3 pass=12 fail=0 err=0 |
| core/kernel/loop_spec.rb | ERROR: Kernel#loop returns an enumerator if no block given: NameError -- undefined local variable or method 'loop' for an instance of Object |
| core/kernel/loop_spec.rb | ERROR: Kernel#loop rescues StopIteration's subclasses: #<Class:0xADDR> -- AnonClass_2 |
| core/kernel/loop_spec.rb | FAILED: returns StopIteration#result, the result value of a finished iterator: expected :stopped, got nil |
| core/kernel/method_spec.rb | pass=11 fail=1 err=0 pass=12 fail=0 err=0 |
| core/kernel/open_spec.rb | pass=1 fail=0 err=15 pass=15 fail=0 err=7 |
| core/kernel/open_spec.rb | ERROR: Kernel#open is a private method: ArgumentError -- path component of HOME is a file |
| core/kernel/open_spec.rb | ERROR: Kernel#open opens a file when given a valid filename: ArgumentError -- path component of HOME is a file |
| core/kernel/open_spec.rb | ERROR: Kernel#open opens a file when called with a block: ArgumentError -- path component of HOME is a file |
| core/kernel/p_spec.rb | pass=7 fail=0 err=3 pass=9 fail=0 err=1 |
| core/kernel/p_spec.rb | ERROR: Kernel#p flushes output if receiver is a File: ArgumentError -- path component of HOME is a file |
| core/kernel/p_spec.rb | ERROR: Kernel#p is not affected by setting $\, $/ or $,: NoMethodError -- undefined method 'output_to_fd' for an instance of Object |
| core/kernel/p_spec.rb | ERROR: Kernel#p prints nothing if no argument is given: NameError -- undefined local variable or method 'p' for an instance of Object |
| core/kernel/print_spec.rb | pass=3 fail=1 err=0 pass=4 fail=0 err=0 |
| core/kernel/printf_spec.rb | pass=1 fail=0 err=4 pass=1 fail=0 err=4 |
| core/kernel/printf_spec.rb | ERROR: Kernel#printf is a private method: ArgumentError -- path component of HOME is a file |
| core/kernel/printf_spec.rb | ERROR: Kernel#printf writes to stdout when a string is the first argument: ArgumentError -- path component of HOME is a file |
| core/kernel/printf_spec.rb | ERROR: Kernel#printf calls write on the first argument when it is not a string: ArgumentError -- path component of HOME is a file |
| core/kernel/public_method_spec.rb | pass=4 fail=1 err=0 pass=5 fail=0 err=0 |
| core/kernel/putc_spec.rb | pass=1 fail=0 err=1 pass=1 fail=0 err=1 |
| core/kernel/putc_spec.rb | ERROR: Kernel#putc is a private method: ArgumentError -- path component of HOME is a file |
| core/kernel/puts_spec.rb | pass=1 fail=0 err=2 pass=1 fail=0 err=2 |
| core/kernel/puts_spec.rb | ERROR: Kernel#puts is a private method: ArgumentError -- path component of HOME is a file |
| core/kernel/puts_spec.rb | ERROR: Kernel#puts delegates to $stdout.puts: ArgumentError -- path component of HOME is a file |
| core/kernel/puts_spec.rb | ERROR: Kernel#puts is a private method: NoMethodError -- undefined method 'new_io' for an instance of Object |
| core/kernel/raise_spec.rb | pass=22 fail=6 err=0 pass=28 fail=0 err=0 |
| core/kernel/raise_spec.rb | FAILED: re-raises a previously rescued exception without overwriting the cause when it's explicitly specified with :cause option and has nil value: expected #<RuntimeError: Error 1>, got nil |
| core/kernel/raise_spec.rb | FAILED: re-raises a previously rescued exception that doesn't have a cause and is a cause of other exception without setting a cause implicitly: expected #<RuntimeError: Error 1>, got #<RuntimeError: Error 1> |
| core/kernel/raise_spec.rb | FAILED: re-raises a previously rescued exception that doesn't have a cause and is a cause of other exception without setting a cause implicitly: expected nil, got #<RuntimeError: Error 2> |
| core/kernel/require_spec.rb | pass=3 fail=1 err=0 pass=2 fail=2 err=0 |
| core/kernel/require_spec.rb | FAILED: provided features are already required: expected ["complex", "enumerator", "fiber", "pathname", "rational", "ruby2_keywords", "set", "thread"], got ["code_loading", "require", "require_spec", "spec_helper"] |
| core/kernel/require_spec.rb | FAILED: provided features are already required: expected ["complex", "enumerator", "fiber", "pathname", "rational", "ruby2_keywords", "set", "thread"], got ["require"] |
| core/kernel/respond_to_missing_spec.rb | pass=10 fail=11 err=0 pass=10 fail=8 err=0 |
| core/kernel/respond_to_missing_spec.rb | FAILED: is called with a 2nd argument of false when #respond_to? is: expected to receive #respond_to_missing? |
| core/kernel/respond_to_missing_spec.rb | FAILED: is called a 2nd argument of false when #respond_to? is called with only 1 argument: expected to receive #respond_to_missing? |
| core/kernel/respond_to_missing_spec.rb | FAILED: is called with true as the second argument when #respond_to? is: expected to receive #respond_to_missing? |
| core/kernel/select_spec.rb | pass=2 fail=0 err=1 pass=4 fail=0 err=0 |
| core/kernel/singleton_class_spec.rb | pass=12 fail=0 err=1 pass=14 fail=0 err=0 |
| core/kernel/sleep_spec.rb | pass=10 fail=2 err=4 pass=16 fail=0 err=0 |
| core/kernel/sleep_spec.rb | FAILED: pauses execution indefinitely if not given a duration: expected 5, got nil |
| core/kernel/sleep_spec.rb | FAILED: sleeps with nanosecond precision: expected truthy from #> |
| core/kernel/sleep_spec.rb | ERROR: Kernel#sleep accepts a nil duration: TypeError -- can't convert nil into time interval |
| core/kernel/srand_spec.rb | pass=4 fail=8 err=1 pass=11 fail=0 err=1 |
| core/kernel/srand_spec.rb | FAILED: returns the previous seed value: expected 10, got 0 |
| core/kernel/srand_spec.rb | FAILED: seeds the RNG correctly and repeatably: expected 0.640674151, got 0.882110366 |
| core/kernel/srand_spec.rb | ERROR: Kernel#srand defaults number to a random value: RuntimeError -- |
| core/kernel/system_spec.rb | pass=2 fail=3 err=6 pass=6 fail=1 err=5 |
| core/kernel/system_spec.rb | ERROR: Kernel#system executes the specified command in a subprocess: NoMethodError -- undefined method 'output_to_fd' for an instance of Object |
| core/kernel/system_spec.rb | ERROR: Kernel#system returns true when the command exits with a zero exit status: NoMethodError -- undefined method 'ruby_cmd' for an instance of Object |
| core/kernel/system_spec.rb | ERROR: Kernel#system returns false when the command exits with a non-zero exit status: NoMethodError -- undefined method 'ruby_cmd' for an instance of Object |
| core/kernel/test_spec.rb | pass=2 fail=0 err=13 pass=12 fail=0 err=0 |
| core/kernel/test_spec.rb | ERROR: Kernel#test returns true when passed ?f if the argument is a regular file: NoMethodError -- undefined method 'test' for an instance of Object |
| core/kernel/test_spec.rb | ERROR: Kernel#test returns true when passed ?e if the argument is a file: NoMethodError -- undefined method 'test' for an instance of Object |
| core/kernel/test_spec.rb | ERROR: Kernel#test returns true when passed ?d if the argument is a directory: NoMethodError -- undefined method 'test' for an instance of Object |
| core/kernel/to_enum_spec.rb | pass=8 fail=1 err=2 pass=12 fail=0 err=0 |
| core/kernel/to_enum_spec.rb | FAILED: sets regexp matches in the caller: expected ["w", "a", "w", "a"], got ["a", "a", "a", "a"] |
| core/kernel/to_enum_spec.rb | ERROR: Kernel#to_enum uses the passed block's value to calculate the size of the enumerator: NoMethodError -- undefined method 'to_enum' for an instance of Object |
| core/kernel/trace_var_spec.rb | pass=4 fail=2 err=0 pass=6 fail=0 err=0 |
| core/kernel/trace_var_spec.rb | FAILED: accepts a String argument instead of a Proc or block: expected true, got nil |
| core/kernel/warn_spec.rb | pass=25 fail=18 err=4 pass=37 fail=8 err=2 |
| core/kernel/warn_spec.rb | ERROR: Kernel#warn does not write strings when passed no arguments: NameError -- undefined local variable or method 'warn' for an instance of Object |
| core/kernel/warn_spec.rb | FAILED: prepends a message with specified line from the backtrace: matcher did not match #<Proc> |
| core/kernel/warn_spec.rb | FAILED: prepends a message with specified line from the backtrace: matcher did not match #<Proc> |
| core/method/call_spec.rb | pass=7 fail=1 err=0 pass=8 fail=0 err=0 |
| core/method/curry_spec.rb | pass=7 fail=3 err=0 pass=10 fail=0 err=0 |
| core/method/curry_spec.rb | FAILED: expected ArgumentError to be raised |
| core/method/curry_spec.rb | FAILED: expected ArgumentError to be raised |
| core/method/equal_value_spec.rb | pass=15 fail=1 err=1 pass=16 fail=0 err=0 |
| core/method/equal_value_spec.rb | FAILED: calls respond_to_missing? with true to include private methods: #respond_to_missing? received with unexpected arguments |
| core/method/parameters_spec.rb | pass=49 fail=2 err=1 pass=52 fail=0 err=0 |
| core/method/parameters_spec.rb | FAILED: returns [:rest, :*], [:keyrest, :**], [:block, :&] for forward parameters operator: expected [[:rest, :*], [:keyrest, :**], [:block, :&]], got [[:rest, :__fwd], [:block, :&]] |
| core/method/parameters_spec.rb | FAILED: returns all parameters defined with the name _ as _: expected [[:req, :_], [:req, :_], [:opt, :_], [:rest, :_], [:keyreq, :_], [:key, :_], [:keyrest, :_], [:block, :_]], got [[:req, :_], [:req, :"_~1"], [:opt, :"_~2"], [:rest, :"_~3 ...[clipped] |
| core/method/source_location_spec.rb | pass=16 fail=0 err=0 pass=17 fail=0 err=0 |
| core/method/source_location_spec.rb | (nothing failed -- the record may be stale) |
| core/method/super_method_spec.rb | pass=2 fail=3 err=1 pass=14 fail=0 err=0 |
| core/method/super_method_spec.rb | ERROR: Method#super_method returns the method that would be called by super in the method: NoMethodError -- undefined method 'owner' for nil |
| core/method/super_method_spec.rb | FAILED: returns nil when there's no super method in the parent: expected nil, got #<Method: Kernel#method()> |
| core/method/super_method_spec.rb | FAILED: returns the expected super_method: expected MethodSpecs::InheritedMethods::A, got MethodSpecs::InheritedMethods::B |
| core/method/to_proc_spec.rb | pass=36 fail=0 err=1 pass=37 fail=0 err=0 |
| core/method/unbind_spec.rb | pass=7 fail=1 err=0 pass=8 fail=0 err=0 |
| core/mutex/lock_spec.rb | pass=2 fail=1 err=4 pass=4 fail=0 err=3 |
| core/mutex/lock_spec.rb | ERROR: Mutex#lock blocks the caller if already locked: NameError -- undefined local variable or method 'block_caller' for an instance of Object |
| core/mutex/lock_spec.rb | ERROR: Mutex#lock does not block the caller if not locked: NameError -- undefined local variable or method 'block_caller' for an instance of Object |
| core/mutex/lock_spec.rb | FAILED: expected ThreadError to be raised |
| core/mutex/locked_spec.rb | pass=3 fail=1 err=0 pass=4 fail=0 err=0 |
| core/mutex/sleep_spec.rb | pass=7 fail=2 err=4 pass=10 fail=0 err=3 |
| core/mutex/sleep_spec.rb | ERROR: when not locked by the current thread pauses execution for approximately the duration requested: NameError -- uninitialized constant TIME_TOLERANCE |
| core/mutex/sleep_spec.rb | FAILED: unlocks the mutex while sleeping: expected false, got true |
| core/mutex/sleep_spec.rb | ERROR: when not locked by the current thread relocks the mutex when woken by an exception being raised: Exception -- Exception |
| core/mutex/synchronize_spec.rb | pass=4 fail=1 err=3 pass=5 fail=0 err=3 |
| core/mutex/synchronize_spec.rb | FAILED: wraps the lock/unlock pair in an ensure: expected true, got false |
| core/mutex/synchronize_spec.rb | ERROR: Mutex#synchronize blocks the caller if already locked: NameError -- undefined local variable or method 'block_caller' for an instance of Object |
| core/mutex/synchronize_spec.rb | ERROR: Mutex#synchronize does not block the caller if not locked: NameError -- undefined local variable or method 'block_caller' for an instance of Object |
| core/numeric/step_spec.rb | pass=8 fail=5 err=0 pass=13 fail=0 err=0 |
| core/numeric/step_spec.rb | FAILED: expected ArgumentError to be raised |
| core/numeric/step_spec.rb | FAILED: raised StandardError, expected ArgumentError |
| core/numeric/step_spec.rb | FAILED: raised StandardError, expected ArgumentError |
| core/proc/arity_spec.rb | pass=143 fail=7 err=0 pass=150 fail=0 err=0 |
| core/proc/arity_spec.rb | FAILED: : expected 1, got -2 |
| core/proc/arity_spec.rb | FAILED: : expected 3, got -4 |
| core/proc/arity_spec.rb | FAILED: : expected 3, got -4 |
| core/proc/call_spec.rb | pass=41 fail=1 err=0 pass=42 fail=0 err=0 |
| core/proc/curry_spec.rb | pass=31 fail=9 err=3 pass=40 fail=0 err=3 |
| core/proc/curry_spec.rb | ERROR: Proc#curry can be called multiple times on the same Proc: RuntimeError -- |
| core/proc/curry_spec.rb | FAILED: can be passed superfluous arguments if created from a proc: expected 6, got 12 |
| core/proc/curry_spec.rb | FAILED: expected ArgumentError to be raised |
| core/proc/equal_value_spec.rb | pass=13 fail=4 err=0 pass=17 fail=0 err=0 |
| core/proc/equal_value_spec.rb | FAILED: is a public method: expected truthy from #include? |
| core/proc/equal_value_spec.rb | FAILED: returns true if other is a dup of the original: expected true, got false |
| core/proc/equal_value_spec.rb | FAILED: returns true if other is a dup of the original: expected true, got false |
| core/proc/new_spec.rb | pass=22 fail=2 err=6 pass=36 fail=0 err=0 |
| core/proc/new_spec.rb | ERROR: called on a subclass of Proc returns an instance of the subclass: NoMethodError -- undefined method 'call' for an instance of #<Class:0xADDR> |
| core/proc/new_spec.rb | ERROR: using a reified block parameter returns an instance of the subclass: NoMethodError -- undefined method 'call' for an instance of #<Class:0xADDR> |
| core/proc/new_spec.rb | ERROR: called on a subclass of Proc that does not 'super' in 'initialize' still constructs a functional proc: NoMethodError -- undefined method 'call' for an instance of #<Class:0xADDR> |
| core/proc/parameters_spec.rb | pass=52 fail=4 err=0 pass=56 fail=0 err=0 |
| core/proc/parameters_spec.rb | FAILED: returns all parameters defined with the name _ as _: expected [[:opt, :_], [:opt, :_], [:opt, :_], [:rest, :_], [:keyreq, :_], [:key, :_], [:keyrest, :_], [:block, :_]], got [[:opt, :_], [:opt, :_], [:opt, :_], [:rest, :_], [:key, : ...[clipped] |
| core/proc/parameters_spec.rb | FAILED: returns all parameters defined with the name _ as _: expected [[:req, :_], [:req, :_], [:opt, :_], [:rest, :_], [:keyreq, :_], [:key, :_], [:keyrest, :_], [:block, :_]], got [[:opt, :_], [:opt, :_], [:opt, :_], [:rest, :_], [:key, : ...[clipped] |
| core/proc/parameters_spec.rb | FAILED: handles the usage of `it` as a parameter: expected [[:opt]], got [] |
| core/proc/ruby2_keywords_spec.rb | pass=6 fail=4 err=0 pass=10 fail=0 err=0 |
| core/proc/ruby2_keywords_spec.rb | FAILED: prints warning when a proc does not accept argument splat: matcher did not match #<Proc> |
| core/proc/ruby2_keywords_spec.rb | FAILED: prints warning when a proc accepts keywords: matcher did not match #<Proc> |
| core/proc/ruby2_keywords_spec.rb | FAILED: prints warning when a proc accepts keyword splat: matcher did not match #<Proc> |
| core/range/clone_spec.rb | pass=10 fail=2 err=0 pass=12 fail=0 err=0 |
| core/range/clone_spec.rb | FAILED: duplicates the range: expected not to be identical |
| core/range/dup_spec.rb | pass=6 fail=1 err=0 pass=7 fail=0 err=0 |
| core/range/max_spec.rb | pass=58 fail=2 err=2 pass=62 fail=0 err=0 |
| core/range/max_spec.rb | ERROR: Range#max given an integer argument returns the n maximum values for beginless Integer ranges: RangeError -- cannot get the maximum of beginless range with custom comparison method |
| core/range/max_spec.rb | ERROR: Range#max given an integer argument returns the n maximum values (except the end point) for exclusive beginless Integer ranges: RangeError -- cannot get the maximum of beginless range with custom comparison method |
| core/range/max_spec.rb | FAILED: raised RangeError, expected TypeError |
| core/range/step_spec.rb | pass=60 fail=2 err=6 pass=66 fail=0 err=2 |
| core/range/step_spec.rb | ERROR: Range#step does not iterate if step is 0 for bounded non-numeric ranges: ArgumentError -- step can't be 0 |
| core/range/step_spec.rb | ERROR: and String values calls #+ on begin and each element returned by #+: TypeError -- can't iterate from Object |
| core/range/step_spec.rb | ERROR: and String values iterates backward if the step is decreasing values, and the range is backward: TypeError -- can't iterate from Object |
| core/range/to_set_spec.rb | pass=8 fail=1 err=0 pass=9 fail=0 err=0 |
| core/rational/exponent_spec.rb | pass=38 fail=1 err=0 pass=39 fail=0 err=0 |
| core/rational/round_spec.rb | pass=37 fail=6 err=1 pass=51 fail=0 err=0 |
| core/rational/round_spec.rb | ERROR: with half option returns an Integer when precision is not passed: TypeError -- not an integer |
| core/rational/round_spec.rb | FAILED: returns a Rational when the precision is greater than 0: expected (1/5), got (3/10) |
| core/rational/round_spec.rb | FAILED: returns a Rational when the precision is greater than 0: expected (1/5), got (3/10) |
| core/rational/to_f_spec.rb | pass=0 fail=1 err=0 pass=1 fail=0 err=0 |
| core/rational/to_r_spec.rb | pass=4 fail=1 err=0 pass=5 fail=0 err=0 |
| core/regexp/equal_value_spec.rb | pass=10 fail=1 err=0 pass=11 fail=0 err=0 |
| core/regexp/initialize_spec.rb | pass=2 fail=2 err=0 pass=4 fail=0 err=0 |
| core/regexp/initialize_spec.rb | FAILED: raised FrozenError, expected TypeError |
| core/regexp/last_match_spec.rb | pass=8 fail=4 err=0 pass=11 fail=0 err=0 |
| core/regexp/last_match_spec.rb | FAILED: expected IndexError to be raised |
| core/regexp/last_match_spec.rb | FAILED: coerces argument to an index using #to_int: expected "TEST123", got nil |
| core/regexp/last_match_spec.rb | FAILED: coerces argument to an index using #to_int: expected to receive #to_int |
| core/regexp/linear_time_spec.rb | pass=9 fail=1 err=0 pass=10 fail=0 err=0 |
| core/regexp/match_spec.rb | pass=18 fail=4 err=4 pass=26 fail=0 err=0 |
| core/regexp/match_spec.rb | FAILED: expected ArgumentError to be raised |
| core/regexp/match_spec.rb | FAILED: expected ArgumentError to be raised |
| core/regexp/match_spec.rb | ERROR: when passed a block yields the MatchData: NoMethodError -- undefined method 'match' for an instance of Regexp |
| core/regexp/options_spec.rb | pass=18 fail=2 err=0 pass=20 fail=0 err=0 |
| core/regexp/options_spec.rb | FAILED: expected not 0 |
| core/regexp/timeout_spec.rb | pass=3 fail=0 err=2 pass=5 fail=0 err=0 |
| core/regexp/timeout_spec.rb | ERROR: Regexp.timeout raises Regexp::TimeoutError after global timeout elapsed: NameError -- uninitialized constant Regexp::TimeoutError |
| core/string/bytesplice_spec.rb | pass=57 fail=16 err=11 pass=118 fail=0 err=0 |
| core/string/bytesplice_spec.rb | FAILED: raised ArgumentError, expected IndexError |
| core/string/bytesplice_spec.rb | FAILED: raised ArgumentError, expected IndexError |
| core/string/bytesplice_spec.rb | FAILED: raised ArgumentError, expected IndexError |
| core/string/index_spec.rb | pass=741 fail=1 err=0 pass=742 fail=0 err=0 |
| core/string/uplus_spec.rb | pass=5 fail=2 err=0 pass=6 fail=1 err=0 |
| core/string/uplus_spec.rb | FAILED: returns mutable copy of a literal: expected "mutable", got "" |
| core/string/uplus_spec.rb | FAILED: returns mutable copy of a literal: expected false, got true |
| core/struct/deconstruct_keys_spec.rb | pass=22 fail=5 err=0 pass=25 fail=0 err=0 |
| core/struct/deconstruct_keys_spec.rb | FAILED: tries to convert a key with #to_int if index is not a String nor a Symbol, but responds to #to_int: expected {#<MockObject to_int> => 2}, got {} |
| core/struct/deconstruct_keys_spec.rb | FAILED: tries to convert a key with #to_int if index is not a String nor a Symbol, but responds to #to_int: expected to receive #to_int |
| core/struct/deconstruct_keys_spec.rb | FAILED: raises a TypeError if the conversion with #to_int does not return an Integer: matcher did not match #<Proc> |
| core/struct/hash_spec.rb | pass=7 fail=2 err=1 pass=10 fail=0 err=0 |
| core/struct/hash_spec.rb | FAILED: allows for overriding methods in an included module: expected "different", got 527 |
| core/struct/hash_spec.rb | ERROR: Struct#hash returns the same hash for recursive structs: SystemStackError -- stack level too deep |
| core/struct/initialize_spec.rb | pass=22 fail=3 err=0 pass=25 fail=0 err=0 |
| core/struct/initialize_spec.rb | FAILED: can be overridden: expected :value, got nil |
| core/struct/initialize_spec.rb | FAILED: can be initialized with keyword arguments: expected {version: "3.2", platform: "OS"}, got "3.2" |
| core/struct/new_spec.rb | pass=54 fail=3 err=2 pass=60 fail=0 err=0 |
| core/struct/new_spec.rb | FAILED: overwrites previously defined constants with string as first argument: matcher did not match #<Proc> |
| core/struct/new_spec.rb | ERROR: with a block passes same struct class to the block: NoMethodError -- undefined method 'block_parameter' for class #<Class:0xADDR> |
| core/struct/new_spec.rb | FAILED: accepts keyword arguments to initialize: expected #<struct args=42>, got #<struct args={args: 42}> |
| core/symbol/all_symbols_spec.rb | pass=0 fail=0 err=3 pass=2 fail=0 err=0 |
| core/symbol/all_symbols_spec.rb | ERROR: Symbol.all_symbols returns an array of Symbols: NoMethodError -- undefined method 'all_symbols' for class Symbol |
| core/symbol/all_symbols_spec.rb | ERROR: Symbol.all_symbols includes symbols that are strongly referenced: NoMethodError -- undefined method 'all_symbols' for class Symbol |
| core/symbol/element_reference_spec.rb | pass=51 fail=6 err=1 pass=58 fail=0 err=0 |
| core/symbol/element_reference_spec.rb | FAILED: converts the last value to an Integer: expected "sym", got "symbol" |
| core/symbol/element_reference_spec.rb | ERROR: with a Range subclass slice returns a slice: TypeError -- no implicit conversion of Object into Integer |
| core/symbol/element_reference_spec.rb | FAILED: returns a string for the matched capture at the given index: expected "ol", got nil |
| core/symbol/to_proc_spec.rb | pass=10 fail=3 err=1 pass=14 fail=0 err=0 |
| core/symbol/to_proc_spec.rb | FAILED: expected NoMethodError to be raised |
| core/symbol/to_proc_spec.rb | FAILED: only calls public methods: expected [:pub], got [:pub, :pro] |
| core/symbol/to_proc_spec.rb | FAILED: expected NoMethodError to be raised |
| core/unboundmethod/bind_call_spec.rb | pass=9 fail=0 err=1 pass=10 fail=0 err=0 |
| core/unboundmethod/bind_spec.rb | pass=11 fail=0 err=1 pass=12 fail=0 err=0 |
| core/unboundmethod/equal_value_spec.rb | pass=28 fail=1 err=3 pass=35 fail=0 err=0 |
| core/unboundmethod/equal_value_spec.rb | FAILED: returns false if both have same Module, same name, identical body but not the same: expected false, got true |
| core/unboundmethod/equal_value_spec.rb | ERROR: UnboundMethod#== considers methods through aliasing equal: NameError -- undefined method 'n' for class '#<Class:0xADDR>' |
| core/unboundmethod/equal_value_spec.rb | ERROR: UnboundMethod#== considers methods through visibility change equal: NameError -- undefined method 'new' for class 'Class' |
| core/unboundmethod/super_method_spec.rb | pass=5 fail=1 err=1 pass=7 fail=0 err=0 |
| core/unboundmethod/super_method_spec.rb | ERROR: after changing an inherited methods visibility returns the expected super_method: NoMethodError -- undefined method 'owner' for nil |
| language/alias_spec.rb | pass=34 fail=4 err=0 pass=37 fail=1 err=0 |
| language/alias_spec.rb | FAILED: expected TypeError to be raised |
| language/alias_spec.rb | FAILED: expected TypeError to be raised |
| language/alias_spec.rb | FAILED: expected NameError to be raised |
| language/assignments_spec.rb | pass=59 fail=4 err=0 pass=63 fail=0 err=0 |
| language/assignments_spec.rb | FAILED: raised ArgumentError, expected SyntaxError |
| language/assignments_spec.rb | FAILED: expected SyntaxError to be raised |
| language/assignments_spec.rb | FAILED: raised ArgumentError, expected SyntaxError |
| language/block_spec.rb | pass=213 fail=8 err=0 pass=221 fail=0 err=0 |
| language/block_spec.rb | FAILED: assigns elements to mixed argument types: expected [1, 2, [3], {x: 9}, 2, {}], got [[1, 2, 3, {x: 9}], 5, [], nil, 2, {}] |
| language/block_spec.rb | FAILED: assigns the first variable named: expected 1, got 2 |
| language/block_spec.rb | FAILED: expected SyntaxError to be raised |
| language/break_spec.rb | pass=49 fail=5 err=1 pass=51 fail=3 err=1 |
| language/break_spec.rb | FAILED: returns from the lambda: expected [:a, :d, :aaa, :b, :bbb, :e], got [:a, :d, :aaa, :b, :e] |
| language/break_spec.rb | FAILED: returns a value when invoking from the toplevel: expected "a,b,break,d", got "" |
| language/break_spec.rb | FAILED: returns a value when invoking from a method: expected "a,d,b,break,e,f", got "" |
| language/constants_spec.rb | pass=113 fail=17 err=13 pass=148 fail=0 err=0 |
| language/constants_spec.rb | ERROR: with statically assigned constants searches the superclass chain: NameError -- uninitialized constant ConstantSpecs::ContainerA::ChildA::CS_CONST13 |
| language/constants_spec.rb | ERROR: with statically assigned constants searches Object if no class or module qualifier is given: NameError -- uninitialized constant CS_CONST10 |
| language/constants_spec.rb | ERROR: with statically assigned constants searches Object after searching other scopes: NameError -- uninitialized constant CS_CONST10 |
| language/def_spec.rb | pass=111 fail=6 err=7 pass=135 fail=0 err=0 |
| language/def_spec.rb | FAILED: expected SyntaxError to be raised |
| language/def_spec.rb | ERROR: A singleton method definition can be declared for a global variable: NoMethodError -- undefined method 'foo' for an instance of String |
| language/def_spec.rb | FAILED: expected FrozenError to be raised |
| language/defined_spec.rb | pass=311 fail=11 err=0 pass=321 fail=0 err=0 |
| language/defined_spec.rb | FAILED: returns 'method' if the method is defined: expected "method", got nil |
| language/defined_spec.rb | FAILED: calls #respond_to_missing?: expected "method", got nil |
| language/defined_spec.rb | FAILED: calls #respond_to_missing?: expected to receive #respond_to_missing? |
| language/delegation_spec.rb | pass=12 fail=1 err=2 pass=15 fail=0 err=0 |
| language/delegation_spec.rb | ERROR: delegation with def(*) delegates rest: StandardError -- mere-ruby: unexpected token: ) in (eval)     def delegate(*) |
| language/execution_spec.rb | pass=16 fail=2 err=0 pass=18 fail=0 err=0 |
| language/execution_spec.rb | FAILED: can be redefined and receive a frozen string as argument: expected true, got false |
| language/hash_spec.rb | pass=74 fail=21 err=0 pass=93 fail=0 err=0 |
| language/hash_spec.rb | FAILED: freezes string keys on initialization: expected "bar", got nil |
| language/hash_spec.rb | FAILED: freezes string keys on initialization: expected "foo", got "oof" |
| language/hash_spec.rb | FAILED: checks duplicated keys on initialization: matcher did not match #<Proc> |
| language/if_spec.rb | pass=59 fail=2 err=0 pass=61 fail=0 err=0 |
| language/if_spec.rb | FAILED: warns when Integer literals are used instead of predicates: matcher did not match #<Proc> |
| language/it_parameter_spec.rb | pass=11 fail=14 err=4 pass=32 fail=0 err=0 |
| language/it_parameter_spec.rb | ERROR: The `it` parameter provides it in a block: ArgumentError -- wrong number of arguments (given 1, expected 0) |
| language/it_parameter_spec.rb | ERROR: The `it` parameter can be used in both outer and nested blocks at the same time: ArgumentError -- wrong number of arguments (given 1, expected 0) |
| language/it_parameter_spec.rb | FAILED: expected SyntaxError to be raised |
| language/lambda_spec.rb | pass=116 fail=14 err=0 pass=129 fail=0 err=0 |
| language/lambda_spec.rb | FAILED: has its own scope for local variables: expected to be identical |
| language/lambda_spec.rb | FAILED: has its own scope for local variables: expected [9, 8, [7], [], 6, 5, 4, 3, {}, #<Proc:0xADDR TMPDIR (lambda)>], got [9, 8, [7], [], 6, 5, 4, 3, {}, #<Proc:0xADDR TMPDIR |
| language/lambda_spec.rb | FAILED: has its own scope for local variables: expected [1, 1, [], 2, 3, 2, 4, {h: 5, i: 6}, #<Proc:0xADDR TMPDIR (lambda)>], got [1, 1, [], 2, 3, 2, 4, {h: 5, i: 6}, #<Proc:0xADDR TMPDIR |
| language/method_spec.rb | pass=293 fail=8 err=0 pass=301 fail=0 err=0 |
| language/method_spec.rb | FAILED: expected ArgumentError to be raised |
| language/method_spec.rb | FAILED: expected ArgumentError to be raised |
| language/method_spec.rb | FAILED: expected ArgumentError to be raised |
| language/module_spec.rb | pass=15 fail=0 err=1 pass=16 fail=0 err=0 |
| language/predefined_spec.rb | pass=206 fail=25 err=6 pass=221 fail=14 err=2 |
| language/predefined_spec.rb | FAILED: is set at the method-scoped level rather than block-scoped: expected #<MatchData "bar">, got #<MatchData "foo"> |
| language/predefined_spec.rb | FAILED: is set at the method-scoped level rather than block-scoped: expected #<MatchData "qux">, got #<MatchData "baz"> |
| language/predefined_spec.rb | ERROR: Predefined global $! is Fiber-local: NoMethodError -- undefined method 'yield' for class Fiber |
| language/proc_spec.rb | pass=41 fail=4 err=0 pass=45 fail=0 err=0 |
| language/proc_spec.rb | FAILED: expected ArgumentError to be raised |
| language/proc_spec.rb | FAILED: expected ArgumentError to be raised |
| language/proc_spec.rb | FAILED: expected ArgumentError to be raised |
| language/regexp_spec.rb | pass=30 fail=11 err=4 pass=74 fail=0 err=0 |
| language/regexp_spec.rb | FAILED: expected not true |
| language/regexp_spec.rb | FAILED: matches against $_ (last input) in a conditional if no explicit matchee provided: matcher did not match #<Proc> |
| language/regexp_spec.rb | ERROR: Literal Regexps supports paired delimiters with %r: SyntaxError -- syntax error |
| language/rescue_spec.rb | pass=91 fail=7 err=2 pass=100 fail=0 err=0 |
| language/rescue_spec.rb | FAILED: in a global variable: expected "some text", got "" |
| language/rescue_spec.rb | FAILED: converts the splatted list of exceptions using #to_a: expected to receive #to_a |
| language/rescue_spec.rb | FAILED: expected SyntaxError to be raised |
| language/return_spec.rb | pass=36 fail=0 err=16 pass=49 fail=2 err=2 |
| language/return_spec.rb | ERROR: at top level stops file execution: ArgumentError -- path component of HOME is a file |
| language/return_spec.rb | ERROR: within if is allowed: ArgumentError -- path component of HOME is a file |
| language/return_spec.rb | ERROR: within while loop is allowed: ArgumentError -- path component of HOME is a file |
| language/send_spec.rb | pass=140 fail=4 err=0 pass=143 fail=0 err=0 |
| language/send_spec.rb | FAILED: raises TypeError if 'to_proc' doesn't return a Proc: matcher did not match #<Proc> |
| language/send_spec.rb | FAILED: raised NoMethodError, expected TypeError |
| language/send_spec.rb | FAILED: calls #to_a to convert a final splatted Hash object to an Array: expected [1, 2, 3, :a, 1], got [1, 2, 3, [:a, 1]] |
| language/source_encoding_spec.rb | pass=2 fail=2 err=2 pass=2 fail=4 err=0 |
| language/source_encoding_spec.rb | FAILED: can be parsed: expected "hello |
| language/source_encoding_spec.rb | FAILED: can be parsed: expected "hello |
| language/source_encoding_spec.rb | ERROR: encoded in UTF-16 LE with a BOM are invalid because they contain an invalid UTF-8 sequence before the encoding comment: ArgumentError -- path component of HOME is a file |
| language/string_spec.rb | pass=66 fail=11 err=3 pass=74 fail=4 err=2 |
| language/string_spec.rb | FAILED: backslashes follow the same rules as interpolation: expected " |
| language/string_spec.rb | FAILED: expected NoMethodError to be raised |
| language/string_spec.rb | ERROR: Ruby character strings allows a dynamic string to parse a nested do...end block as an argument to a call without parens, interpolated: SyntaxError -- syntax error |
| language/variables_spec.rb | pass=170 fail=2 err=0 pass=172 fail=0 err=0 |
| language/variables_spec.rb | FAILED: expected SyntaxError to be raised |

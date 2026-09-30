# mere-ruby — the examples that actually fail

One row per recorded DIFF file, holding the first few FAILED / ERROR
lines the harness prints for it. `CAUSES.md` groups the record; this
runs the specs again, because a recorded row is the first DIVERGENCE in
a file and not the diagnosis.

Regenerate with `./mspec/examples.sh <spec-root>` (slow: it runs every
file below, both sides). Paths and addresses are masked by mask.sh.

Visited **218** of **218** recorded DIFF files.

| file | what fails |
|---|---|
| command_line/backtrace_limit_spec.rb | pass=0 fail=3 err=0 pass=3 fail=0 err=0 |
| command_line/dash_0_spec.rb | pass=0 fail=2 err=0 pass=2 fail=0 err=0 |
| command_line/dash_0_spec.rb | FAILED: sets $/ and $-0: expected ": |
| command_line/dash_c_spec.rb | pass=0 fail=2 err=0 pass=2 fail=0 err=0 |
| command_line/dash_c_spec.rb | FAILED: checks syntax in given file: expected "Syntax OK", got "" |
| command_line/dash_d_spec.rb | pass=0 fail=3 err=0 pass=3 fail=0 err=0 |
| command_line/dash_d_spec.rb | FAILED: sets $DEBUG to true: expected "$DEBUG true", got "" |
| command_line/dash_d_spec.rb | FAILED: sets $VERBOSE to true: expected "$VERBOSE true", got "" |
| command_line/dash_e_spec.rb | pass=5 fail=4 err=0 pass=9 fail=0 err=0 |
| command_line/dash_encoding_spec.rb | pass=0 fail=5 err=0 pass=4 fail=1 err=0 |
| command_line/dash_encoding_spec.rb | FAILED: does not accept a third encoding: expected "[\"UTF-8\", nil]" to match |
| command_line/dash_encoding_spec.rb | FAILED: if given a single encoding with an =: expected "[\"Big5\", nil]", got "" |
| command_line/dash_encoding_spec.rb | FAILED: if given a single encoding as a separate argument: expected "[\"Big5\", nil]", got "" |
| command_line/dash_external_encoding_spec.rb | pass=0 fail=2 err=0 pass=2 fail=0 err=0 |
| command_line/dash_external_encoding_spec.rb | FAILED: if given an encoding with an =: expected "Big5", got "" |
| command_line/dash_internal_encoding_spec.rb | pass=0 fail=2 err=0 pass=2 fail=0 err=0 |
| command_line/dash_internal_encoding_spec.rb | FAILED: if given an encoding with an =: expected "Big5", got "" |
| command_line/dash_r_spec.rb | pass=6 fail=3 err=0 pass=9 fail=0 err=0 |
| command_line/dash_r_spec.rb | FAILED: requires the file before parsing the main script: expected truthy from #include? |
| command_line/dash_r_spec.rb | FAILED: requires the file before parsing the main script: expected truthy from #include? |
| command_line/dash_s_spec.rb | pass=0 fail=8 err=0 pass=8 fail=0 err=0 |
| command_line/dash_s_spec.rb | FAILED: sets the value to true without an explicit value: expected "true", got "" |
| command_line/dash_s_spec.rb | FAILED: parses single letter args into globals: expected "blah", got "" |
| command_line/dash_upper_c_spec.rb | pass=0 fail=3 err=0 pass=3 fail=0 err=0 |
| command_line/dash_upper_c_spec.rb | FAILED: changes the PWD when using a file: expected "/privateTMPDIR got "" |
| command_line/dash_upper_c_spec.rb | FAILED: does not need a space after -C for the argument: expected "/privateTMPDIR got "" |
| command_line/dash_upper_e_spec.rb | pass=0 fail=7 err=0 pass=7 fail=0 err=0 |
| command_line/dash_upper_e_spec.rb | FAILED: sets the external encoding with '-E external': expected "EUC-JP", got "" |
| command_line/dash_upper_e_spec.rb | FAILED: also sets the filesystem encoding with '-E external': expected "EUC-JP", got "" |
| command_line/dash_upper_i_spec.rb | pass=3 fail=3 err=0 pass=6 fail=0 err=0 |
| command_line/dash_upper_i_spec.rb | FAILED: adds the path at the front of $LOAD_PATH: expected truthy from #< |
| command_line/dash_upper_i_spec.rb | FAILED: adds the path expanded from CWD to $LOAD_PATH: expected truthy from #include? |
| command_line/dash_upper_k_spec.rb | pass=0 fail=11 err=0 pass=11 fail=0 err=0 |
| command_line/dash_upper_k_spec.rb | FAILED: ignores unknown codes: expected "[\"UTF-8\", \"UTF-8\", nil]", got "" |
| command_line/dash_upper_k_spec.rb | FAILED: to Encoding::BINARY with -Ka: expected "[\"ASCII-8BIT\", \"ASCII-8BIT\", nil]", got "" |
| command_line/dash_upper_s_spec.rb | pass=2 fail=6 err=0 pass=2 fail=6 err=0 |
| command_line/dash_upper_s_spec.rb | FAILED: runs launcher found in RUBYPATH, but only code after the first /#!.*ruby.*/-ish line in target file: expected "mere-ruby: invalid option -S  (-h will show valid options) |
| command_line/dash_upper_s_spec.rb | FAILED: runs launcher found in PATH, but only code after the first /#!.*ruby.*/-ish line in target file: expected "mere-ruby: invalid option -S  (-h will show valid options) |
| command_line/dash_upper_s_spec.rb | FAILED: runs launcher found in RUBYPATH: expected "mere-ruby: invalid option -S  (-h will show valid options) |
| command_line/dash_upper_u_spec.rb | pass=0 fail=10 err=0 pass=10 fail=0 err=0 |
| command_line/dash_upper_u_spec.rb | FAILED: sets Encoding.default_internal to UTF-8: expected "UTF-8", got "" |
| command_line/dash_upper_u_spec.rb | FAILED: sets Encoding.default_internal to UTF-8 when RUBYOPT is empty or only spaces: expected "#<Encoding:UTF-8> |
| command_line/dash_upper_x_spec.rb | pass=0 fail=3 err=0 pass=3 fail=0 err=0 |
| command_line/dash_upper_x_spec.rb | FAILED: changes the PWD when using a file: expected "/privateTMPDIR got "" |
| command_line/dash_upper_x_spec.rb | FAILED: does not need a space after -C for the argument: expected "/privateTMPDIR got "" |
| command_line/dash_v_spec.rb | pass=1 fail=1 err=0 pass=2 fail=0 err=0 |
| command_line/dash_x_spec.rb | pass=0 fail=4 err=0 pass=4 fail=0 err=0 |
| command_line/dash_x_spec.rb | FAILED: runs code after the first /#!.*ruby.*/-ish line in target file: expected "success |
| command_line/dash_x_spec.rb | FAILED: changes the working directory when given: expected "/privateTMPDIR |
| command_line/feature_spec.rb | pass=10 fail=16 err=0 pass=24 fail=2 err=0 |
| command_line/feature_spec.rb | FAILED: can be used with gems: expected "\"constant\"", got "nil" |
| command_line/feature_spec.rb | FAILED: can be used with gems: expected "\"constant\"", got "nil" |
| command_line/feature_spec.rb | FAILED: can be used with gem: expected "\"constant\"", got "nil" |
| command_line/frozen_strings_spec.rb | pass=7 fail=10 err=0 pass=17 fail=0 err=0 |
| command_line/frozen_strings_spec.rb | FAILED: produce the same object each time: expected "true", got "false" |
| command_line/frozen_strings_spec.rb | FAILED: produce the same object for literals with the same content: expected "true", got "false" |
| command_line/frozen_strings_spec.rb | FAILED: produce the same object for literals with the same content in different files: expected "true", got "false" |
| command_line/rubylib_spec.rb | pass=9 fail=2 err=1 pass=10 fail=1 err=1 |
| command_line/rubylib_spec.rb | FAILED: adds the directory at the front of $LOAD_PATH: expected truthy from #< |
| command_line/rubylib_spec.rb | FAILED: adds the directory after directories added by -I within RUBYOPT: expected truthy from #include? |
| command_line/rubylib_spec.rb | ERROR: The RUBYLIB environment variable adds the directory after directories added by -I within RUBYOPT: ArgumentError -- comparison of NilClass with 0 failed |
| command_line/rubyopt_spec.rb | pass=5 fail=30 err=0 pass=35 fail=0 err=0 |
| command_line/rubyopt_spec.rb | FAILED: adds the -I path to $LOAD_PATH: expected "optrubyspecincl", got nil |
| command_line/rubyopt_spec.rb | FAILED: sets $DEBUG to true for '-d': expected "value of $DEBUG is false |
| command_line/rubyopt_spec.rb | FAILED: prints the version number for '-v': expected "ruby 4.0.6 (2026-07-14 revision 03b6d3f889) [arm64-darwin25]", got "" |
| command_line/syntax_error_spec.rb | pass=0 fail=2 err=0 pass=2 fail=0 err=0 |
| command_line/syntax_error_spec.rb | FAILED: prints an error when given a file with invalid syntax: expected truthy from #include? |
| core/basicobject/__id__spec.rb | pass=12 fail=1 err=0 pass=13 fail=0 err=0 |
| core/basicobject/basicobject_spec.rb | pass=7 fail=6 err=0 pass=13 fail=0 err=0 |
| core/basicobject/basicobject_spec.rb | FAILED: raises NoMethodError for nonexistent methods after #method_missing is removed: expected "NoMethodError", got "" |
| core/basicobject/basicobject_spec.rb | FAILED: raises NameError when referencing built-in constants: expected NameError to be raised |
| core/basicobject/basicobject_spec.rb | FAILED: does not define built-in constants (according to const_defined?): expected false, got true |
| core/basicobject/instance_eval_spec.rb | pass=53 fail=1 err=0 pass=54 fail=0 err=0 |
| core/basicobject/instance_exec_spec.rb | pass=21 fail=0 err=1 pass=22 fail=0 err=0 |
| core/binding/clone_spec.rb | pass=19 fail=1 err=0 pass=20 fail=0 err=0 |
| core/binding/dup_spec.rb | pass=23 fail=3 err=0 pass=26 fail=0 err=0 |
| core/binding/dup_spec.rb | FAILED: copies the finalizer: expected ["finalized |
| core/binding/dup_spec.rb | FAILED: retains original binding variables but the list is distinct: expected [:a, :bind1, :bind2], got [:a, :bind1] |
| core/binding/eval_spec.rb | pass=21 fail=0 err=1 pass=22 fail=0 err=0 |
| core/binding/local_variable_set_spec.rb | pass=12 fail=1 err=0 pass=13 fail=0 err=0 |
| core/binding/local_variables_spec.rb | pass=4 fail=2 err=0 pass=6 fail=0 err=0 |
| core/binding/local_variables_spec.rb | FAILED: includes local variables defined after calling binding.local_variables: expected [:a, :b], got [] |
| core/encoding/locale_charmap_spec.rb | pass=1 fail=1 err=0 pass=2 fail=0 err=0 |
| core/enumerable/inject_spec.rb | pass=41 fail=2 err=1 pass=45 fail=0 err=0 |
| core/enumerable/inject_spec.rb | FAILED: ignores the block if two arguments: matcher did not match #<Proc> |
| core/enumerable/inject_spec.rb | ERROR: Enumerable#inject ignores the block if two arguments: RuntimeError -- we never get here |
| core/enumerable/map_spec.rb | pass=15 fail=2 err=1 pass=18 fail=0 err=0 |
| core/enumerable/map_spec.rb | FAILED: reports the same arity as the given block: expected [2], got [-2] |
| core/enumerable/map_spec.rb | FAILED: reports the same arity as the given block: expected [1], got [-2] |
| core/enumerator/each_spec.rb | pass=24 fail=2 err=0 pass=26 fail=0 err=0 |
| core/enumerator/each_spec.rb | FAILED: yields the first value to a single-argument block: expected [1, 3], got [[1, 2], [3, 4]] |
| core/enumerator/initialize_spec.rb | pass=8 fail=1 err=0 pass=9 fail=0 err=0 |
| core/exception/interrupt_spec.rb | pass=7 fail=3 err=0 pass=10 fail=0 err=0 |
| core/exception/interrupt_spec.rb | FAILED: shows the backtrace and has a signaled exit status: expected 2, got nil |
| core/exception/interrupt_spec.rb | FAILED: shows the backtrace and has a signaled exit status: expected truthy from #include? |
| core/exception/receiver_spec.rb | pass=13 fail=0 err=1 pass=15 fail=0 err=0 |
| core/exception/signal_exception_spec.rb | pass=28 fail=3 err=0 pass=31 fail=0 err=0 |
| core/exception/signal_exception_spec.rb | FAILED: runs after at_exit: expected 9, got nil |
| core/exception/signal_exception_spec.rb | FAILED: cannot be trapped with Signal.trap: expected 27, got nil |
| core/exception/syntax_error_spec.rb | pass=4 fail=1 err=0 pass=5 fail=0 err=0 |
| core/exception/top_level_spec.rb | pass=7 fail=2 err=0 pass=9 fail=0 err=0 |
| core/exception/top_level_spec.rb | FAILED: with ensure on the root fiber: expected "current fiber ensure |
| core/fiber/raise_spec.rb | pass=68 fail=0 err=5 pass=81 fail=0 err=0 |
| core/fiber/raise_spec.rb | ERROR: Fiber#raise raises RuntimeError if no exception class is given: RuntimeError -- unhandled exception |
| core/fiber/raise_spec.rb | ERROR: with cause keyword argument uses the cause from the calling context: RuntimeError -- second error |
| core/fiber/raise_spec.rb | ERROR: with cause keyword argument accepts a cause keyword argument that overrides the last exception: RuntimeError -- second error |
| core/file/basename_spec.rb | pass=191 fail=0 err=1 pass=193 fail=0 err=0 |
| core/file/new_spec.rb | pass=41 fail=3 err=6 pass=54 fail=0 err=0 |
| core/file/new_spec.rb | ERROR: File.new returns a new File with modus num and permissions: NotImplementedError -- umask() function is unimplemented on this machine |
| core/file/new_spec.rb | ERROR: File.new returns a new File with modus fd: Errno::ENOENT -- No such file or directory @ rb_sysopen - |
| core/file/new_spec.rb | FAILED: raises an Errno::EEXIST if the file exists when create a new file with File::CREAT\|File::EXCL: expected Errno::EEXIST to be raised |
| core/file/open_spec.rb | pass=89 fail=21 err=10 pass=130 fail=0 err=0 |
| core/file/open_spec.rb | ERROR: File.open opens the file when passed mode, num and permissions: NotImplementedError -- umask() function is unimplemented on this machine |
| core/file/open_spec.rb | FAILED: opens the file when passed mode, num, permissions and block: expected "100755", got "100644" |
| core/file/open_spec.rb | FAILED: creates a new write-only file when invoked with 'w' and '0222': expected false, got true |
| core/file/size_spec.rb | pass=21 fail=0 err=1 pass=22 fail=0 err=0 |
| core/file/socket_spec.rb | pass=3 fail=0 err=1 pass=3 fail=0 err=1 |
| core/file/socket_spec.rb | ERROR: File.socket? returns true if the file is a socket: NotImplementedError -- UNIXSocket is not implemented (mere-ruby cannot pass a sockaddr_un to connect(2)) |
| core/file/stat/socket_spec.rb | pass=2 fail=0 err=1 pass=2 fail=0 err=1 |
| core/file/stat/socket_spec.rb | ERROR: File::Stat#socket? returns true if the file is a socket: NotImplementedError -- UNIXSocket is not implemented (mere-ruby cannot pass a sockaddr_un to connect(2)) |
| core/file/stat_spec.rb | pass=6 fail=0 err=1 pass=14 fail=0 err=0 |
| core/file/umask_spec.rb | pass=5 fail=0 err=1 pass=7 fail=0 err=0 |
| core/filetest/socket_spec.rb | pass=3 fail=0 err=1 pass=3 fail=0 err=1 |
| core/filetest/socket_spec.rb | ERROR: FileTest.socket? returns true if the file is a socket: NotImplementedError -- UNIXSocket is not implemented (mere-ruby cannot pass a sockaddr_un to connect(2)) |
| core/gc/config_spec.rb | pass=12 fail=0 err=0 pass=19 fail=0 err=0 |
| core/gc/config_spec.rb | (nothing failed -- the record may be stale) |
| core/gc/stat_spec.rb | pass=20 fail=0 err=1 pass=47 fail=0 err=0 |
| core/hash/inspect_spec.rb | pass=17 fail=3 err=1 pass=19 fail=2 err=0 |
| core/hash/inspect_spec.rb | FAILED: does not call #to_str on the object returned from #inspect when it is not a String: expected "{a: #<MockObject Hash#inspect/to_s does not call #to_str>}" to match |
| core/hash/inspect_spec.rb | FAILED: does not swallow exceptions raised by #to_s: expected Exception to be raised |
| core/hash/inspect_spec.rb | FAILED: can be evaled when Encoding.default_external is changed: expected "{\"\u3042\": 1}", got "{あ: 1}" |
| core/io/buffer/for_spec.rb | pass=24 fail=2 err=0 pass=26 fail=0 err=0 |
| core/io/buffer/for_spec.rb | FAILED: locks the original string to prevent modification: expected RuntimeError "can't modify string; temporarily locked" to be raised |
| core/io/buffer/map_spec.rb | pass=46 fail=0 err=0 pass=52 fail=0 err=0 |
| core/io/buffer/map_spec.rb | (nothing failed -- the record may be stale) |
| core/io/popen_spec.rb | pass=37 fail=1 err=1 pass=39 fail=0 err=0 |
| core/io/popen_spec.rb | FAILED: does not throw an exception if child exited and has been waited for: expected truthy from #signaled? |
| core/io/puts_spec.rb | pass=31 fail=1 err=0 pass=31 fail=1 err=0 |
| core/io/puts_spec.rb | FAILED: returns general object info if :to_s does not return a string: expected "#<MockObject> |
| core/io/reopen_spec.rb | pass=30 fail=0 err=1 pass=31 fail=0 err=0 |
| core/io/write_spec.rb | pass=73 fail=1 err=1 pass=76 fail=0 err=0 |
| core/io/write_spec.rb | FAILED: raises SignalException SIGPIPE if the stream is closed instead of Errno::EPIPE like other IOs: expected truthy from #signaled? |
| core/kernel/__dir___spec.rb | pass=3 fail=4 err=0 pass=7 fail=0 err=0 |
| core/kernel/__dir___spec.rb | FAILED: returns the real name of the directory containing the currently-executing file: expected "/privateTMPDIR got "TMPDIR |
| core/kernel/__dir___spec.rb | FAILED: returns File.dirname(filename): expected ".", got "TMPDIR" |
| core/kernel/__dir___spec.rb | FAILED: returns File.dirname(filename): expected "foo", got "TMPDIR" |
| core/kernel/at_exit_spec.rb | pass=15 fail=2 err=0 pass=17 fail=0 err=0 |
| core/kernel/at_exit_spec.rb | FAILED: runs handlers even if the main script fails to parse: expected truthy from #include? |
| core/kernel/autoload_spec.rb | pass=24 fail=0 err=1 pass=25 fail=0 err=0 |
| core/kernel/binding_spec.rb | pass=9 fail=0 err=1 pass=14 fail=0 err=0 |
| core/kernel/caller_locations_spec.rb | pass=29 fail=1 err=0 pass=31 fail=1 err=0 |
| core/kernel/caller_locations_spec.rb | FAILED: returns an Array of caller locations using a custom offset: expected truthy from #end_with? |
| core/kernel/caller_spec.rb | pass=22 fail=2 err=0 pass=25 fail=1 err=0 |
| core/kernel/caller_spec.rb | FAILED: returns an Array of caller locations using a custom offset: expected "TMPDIR 'BasicObject#instance_exec'" to match |
| core/kernel/caller_spec.rb | FAILED: returns an Array with the block given to #at_exit at the base of the stack: expected 2, got 3 |
| core/kernel/chomp_spec.rb | pass=9 fail=1 err=0 pass=10 fail=0 err=0 |
| core/kernel/chop_spec.rb | pass=6 fail=1 err=0 pass=7 fail=0 err=0 |
| core/kernel/eval_spec.rb | pass=91 fail=8 err=5 pass=104 fail=0 err=0 |
| core/kernel/eval_spec.rb | FAILED: does not share locals across eval scopes: expected "NameError", got "2" |
| core/kernel/eval_spec.rb | FAILED: includes file and line information in syntax error: expected "syntax error" to match |
| core/kernel/eval_spec.rb | FAILED: evaluates string with given filename and negative linenumber: expected "syntax error" to match |
| core/kernel/fork_spec.rb | pass=5 fail=0 err=0 pass=10 fail=0 err=0 |
| core/kernel/fork_spec.rb | (nothing failed -- the record may be stale) |
| core/kernel/instance_variable_get_spec.rb | pass=15 fail=0 err=3 pass=19 fail=0 err=0 |
| core/kernel/instance_variable_get_spec.rb | ERROR: Kernel#instance_variable_get raises a TypeError when the passed argument does not respond to #to_str: NameError -- '@' is not allowed as an instance variable name |
| core/kernel/instance_variable_get_spec.rb | ERROR: Kernel#instance_variable_get raises a TypeError when the passed argument can't be converted to a String: NameError -- '@' is not allowed as an instance variable name |
| core/kernel/load_spec.rb | pass=82 fail=6 err=6 pass=100 fail=0 err=0 |
| core/kernel/load_spec.rb | ERROR: (path resolution) accepts an Object with #to_path in $LOAD_PATH: LoadError -- cannot load such file -- load_fixture.rb |
| core/kernel/load_spec.rb | ERROR: with an unreadable file raises a LoadError: StandardError -- mere-ruby: (ruby exception raised) |
| core/kernel/load_spec.rb | FAILED: loads a file that recursively requires itself: matcher did not match #<Proc> |
| core/kernel/object_id_spec.rb | pass=12 fail=1 err=0 pass=13 fail=0 err=0 |
| core/kernel/open_spec.rb | pass=18 fail=1 err=0 pass=19 fail=0 err=0 |
| core/kernel/public_send_spec.rb | pass=33 fail=2 err=0 pass=35 fail=0 err=0 |
| core/kernel/public_send_spec.rb | FAILED: includes `public_send` in the backtrace when passed not enough arguments: expected "TMPDIR 'block (3 levels) in <top (required)>'" to match |
| core/kernel/require_relative_spec.rb | pass=96 fail=14 err=1 pass=112 fail=0 err=0 |
| core/kernel/require_relative_spec.rb | FAILED: raises a LoadError that includes the missing path: expected truthy from #include? |
| core/kernel/require_relative_spec.rb | FAILED: raises a LoadError that includes the missing path: expected "TMPDIR got "TMPDIR |
| core/kernel/require_relative_spec.rb | FAILED: stores the missing path in a LoadError object: expected "/privateTMPDIR got "TMPDIR |
| core/kernel/singleton_class_spec.rb | pass=13 fail=1 err=0 pass=14 fail=0 err=0 |
| core/kernel/sprintf_spec.rb | pass=1024 fail=0 err=2 pass=1027 fail=0 err=0 |
| core/kernel/sprintf_spec.rb | ERROR: Kernel#sprintf raises Encoding::CompatibilityError if both encodings are ASCII compatible and there are not ASCII characters: Encoding::UndefinedConversionError -- U+00C4 from UTF-8 to Windows-1252 |
| core/kernel/to_enum_spec.rb | pass=11 fail=1 err=0 pass=12 fail=0 err=0 |
| core/kernel/warn_spec.rb | pass=43 fail=3 err=0 pass=48 fail=0 err=0 |
| core/kernel/warn_spec.rb | FAILED: does not call Warning.warn if self is the Warning module: expected "Kernel#warn spec edge case |
| core/kernel/warn_spec.rb | FAILED: does not call Warning.warn if self is the Warning module: expected truthy from #success? |
| core/main/include_spec.rb | pass=1 fail=1 err=0 pass=2 fail=0 err=0 |
| core/main/using_spec.rb | pass=1 fail=2 err=8 pass=17 fail=0 err=0 |
| core/main/using_spec.rb | ERROR: main.using requires one Module argument: NameError -- undefined local variable or method 'using' for main |
| core/main/using_spec.rb | ERROR: main.using uses refinements from the given module only in the target file: StandardError -- mere-ruby: undefined method 'should' |
| core/main/using_spec.rb | FAILED: uses refinements from the given module for method calls in the target file: expected NoMethodError to be raised |
| core/marshal/dump_spec.rb | pass=226 fail=0 err=2 pass=228 fail=0 err=0 |
| core/marshal/dump_spec.rb | ERROR: with a Regexp dumps a Regexp with instance variables: FrozenError -- can't modify frozen Regexp: // |
| core/marshal/load_spec.rb | pass=316 fail=4 err=3 pass=325 fail=0 err=0 |
| core/marshal/load_spec.rb | FAILED: loads a Regexp subclass /i: expected #<UserRegexp:0xADDR @__rx_src="", @__rx_flags="i">, got #<UserRegexp:0xADDR @__rx_src="", @__rx_flags="i"> |
| core/marshal/load_spec.rb | FAILED: loads a Regexp subclass /i: expected #<UserRegexp:0xADDR @__rx_src="", @__rx_flags="i">, got #<UserRegexp:0xADDR @__rx_src="", @__rx_flags="i"> |
| core/marshal/load_spec.rb | ERROR: Marshal.load loads a Random: TypeError -- instance of Random needs to have method 'marshal_load' |
| core/method/clone_spec.rb | pass=4 fail=2 err=0 pass=6 fail=0 err=0 |
| core/method/clone_spec.rb | FAILED: copies instance variables: expected [:@ivar], got [] |
| core/method/dup_spec.rb | pass=4 fail=2 err=0 pass=6 fail=0 err=0 |
| core/method/dup_spec.rb | FAILED: copies instance variables: expected [:@ivar], got [] |
| core/method/source_location_spec.rb | pass=15 fail=1 err=0 pass=17 fail=0 err=0 |
| core/method/to_s_spec.rb | pass=25 fail=1 err=0 pass=26 fail=0 err=0 |
| core/module/attr_spec.rb | pass=42 fail=1 err=0 pass=43 fail=0 err=0 |
| core/module/autoload_spec.rb | pass=166 fail=0 err=1 pass=167 fail=0 err=0 |
| core/module/constants_spec.rb | pass=221 fail=0 err=0 pass=226 fail=0 err=0 |
| core/module/constants_spec.rb | (nothing failed -- the record may be stale) |
| core/module/define_method_spec.rb | pass=75 fail=11 err=9 pass=95 fail=0 err=0 |
| core/module/define_method_spec.rb | FAILED: sets visibility to private when method name is :initialize: expected truthy from #include? |
| core/module/define_method_spec.rb | FAILED: sets the visibility to private when method is named :initialize: expected truthy from #include? |
| core/module/define_method_spec.rb | FAILED: raises TypeError if name cannot converted to String: expected TypeError /is not a symbol nor a string/ to be raised |
| core/module/prepend_spec.rb | pass=74 fail=12 err=1 pass=88 fail=0 err=0 |
| core/module/refine_spec.rb | pass=30 fail=3 err=10 pass=46 fail=0 err=0 |
| core/module/refine_spec.rb | ERROR: Module#refine applies refinements to the module: NoMethodError -- undefined method 'foo?' for an instance of Array |
| core/module/refine_spec.rb | ERROR: Module#refine applies refinements to calls in the refine block: NoMethodError -- undefined method 'foo' for an instance of String |
| core/module/refine_spec.rb | FAILED: does not make available methods from another refinement module: expected NoMethodError to be raised |
| core/module/used_refinements_spec.rb | pass=3 fail=1 err=0 pass=4 fail=0 err=0 |
| core/module/using_spec.rb | pass=12 fail=5 err=3 pass=20 fail=0 err=0 |
| core/module/using_spec.rb | FAILED: does not accept class: expected TypeError to be raised |
| core/module/using_spec.rb | ERROR: Module#using raises TypeError if passed something other than module: RuntimeError -- Module#using is not called on self |
| core/module/using_spec.rb | FAILED: returns self: expected to be identical |
| core/objectspace/define_finalizer_spec.rb | pass=20 fail=2 err=0 pass=22 fail=0 err=0 |
| core/objectspace/define_finalizer_spec.rb | FAILED: warns if an exception is raised in finalizer: expected truthy from #include? |
| core/proc/clone_spec.rb | pass=10 fail=1 err=1 pass=12 fail=0 err=0 |
| core/proc/clone_spec.rb | ERROR: Proc#clone copies instance variables: FrozenError -- can't modify frozen Proc: #<Proc:0xADDR TMPDIR (lambda)> |
| core/proc/curry_spec.rb | pass=40 fail=6 err=0 pass=46 fail=0 err=0 |
| core/proc/curry_spec.rb | FAILED: can be passed superfluous arguments if created from a proc: expected 6, got 12 |
| core/proc/curry_spec.rb | FAILED: produces Procs that raise ArgumentError for #binding: expected ArgumentError to be raised |
| core/proc/curry_spec.rb | FAILED: produces Procs that can be passed as the block for instance_exec: expected 6, got nil |
| core/proc/dup_spec.rb | pass=10 fail=1 err=1 pass=12 fail=0 err=0 |
| core/proc/dup_spec.rb | ERROR: Proc#dup copies instance variables: FrozenError -- can't modify frozen Proc: #<Proc:0xADDR TMPDIR (lambda)> |
| core/proc/new_spec.rb | pass=22 fail=2 err=6 pass=36 fail=0 err=0 |
| core/proc/new_spec.rb | ERROR: called on a subclass of Proc returns an instance of the subclass: NoMethodError -- undefined method 'call' for an instance of #<Class:0xADDR> |
| core/proc/new_spec.rb | ERROR: using a reified block parameter returns an instance of the subclass: NoMethodError -- undefined method 'call' for an instance of #<Class:0xADDR> |
| core/proc/new_spec.rb | ERROR: called on a subclass of Proc that does not 'super' in 'initialize' still constructs a functional proc: NoMethodError -- undefined method 'call' for an instance of #<Class:0xADDR> |
| core/proc/parameters_spec.rb | pass=54 fail=2 err=0 pass=56 fail=0 err=0 |
| core/proc/parameters_spec.rb | FAILED: returns all parameters defined with the name _ as _: expected [[:opt, :_], [:opt, :_], [:opt, :_], [:rest, :_], [:keyreq, :_], [:key, :_], [:keyrest, :_], [:block, :_]], got [[:opt, :_], [:opt, :_], [:opt, :_], [:rest, :_], [:key, : ...[clipped] |
| core/proc/source_location_spec.rb | pass=16 fail=4 err=0 pass=20 fail=0 err=0 |
| core/proc/source_location_spec.rb | FAILED: sets the first value to the path of the file in which the proc was defined: expected "/privateTMPDIR got "TMPDIR |
| core/proc/source_location_spec.rb | FAILED: sets the first value to the path of the file in which the proc was defined: expected "/privateTMPDIR got "TMPDIR |
| core/proc/source_location_spec.rb | FAILED: sets the first value to the path of the file in which the proc was defined: expected "/privateTMPDIR got "TMPDIR |
| core/process/_fork_spec.rb | pass=1 fail=0 err=1 pass=2 fail=0 err=0 |
| core/process/daemon_spec.rb | pass=1 fail=0 err=1 pass=25 fail=0 err=0 |
| core/process/exec_spec.rb | pass=24 fail=3 err=0 pass=27 fail=0 err=0 |
| core/process/fork_spec.rb | pass=2 fail=0 err=1 pass=8 fail=0 err=0 |
| core/process/getpriority_spec.rb | pass=0 fail=0 err=4 pass=4 fail=0 err=0 |
| core/process/getpriority_spec.rb | ERROR: Process.getpriority coerces arguments to Integers: NoMethodError -- undefined method 'getpriority' for module Process |
| core/process/getpriority_spec.rb | ERROR: Process.getpriority gets the scheduling priority for a specified process: NoMethodError -- undefined method 'getpriority' for module Process |
| core/process/getpriority_spec.rb | ERROR: Process.getpriority gets the scheduling priority for a specified process group: NoMethodError -- undefined method 'getpriority' for module Process |
| core/process/getrlimit_spec.rb | pass=0 fail=0 err=9 pass=29 fail=0 err=0 |
| core/process/getrlimit_spec.rb | ERROR: Process.getrlimit returns a two-element Array of Integers: NoMethodError -- undefined method 'getrlimit' for module Process |
| core/process/getrlimit_spec.rb | ERROR: when passed an Object calls #to_int to convert to an Integer: NoMethodError -- undefined method 'getrlimit' for module Process |
| core/process/getrlimit_spec.rb | ERROR: when passed an Object raises a TypeError if #to_int does not return an Integer: NoMethodError -- undefined method 'getrlimit' for module Process |
| core/process/kill_spec.rb | pass=6 fail=12 err=0 pass=18 fail=0 err=0 |
| core/process/kill_spec.rb | FAILED: accepts a Symbol as a signal name: expected "signaled", got "" |
| core/process/kill_spec.rb | FAILED: accepts a String as signal name: expected "signaled", got "" |
| core/process/kill_spec.rb | FAILED: accepts a signal name without the 'SIG' prefix: expected "signaled", got "" |
| core/process/set_proctitle_spec.rb | pass=0 fail=0 err=2 pass=2 fail=0 err=0 |
| core/process/set_proctitle_spec.rb | ERROR: Process.setproctitle should set the process title: NoMethodError -- undefined method 'setproctitle' for module Process |
| core/process/setpgid_spec.rb | pass=0 fail=0 err=0 pass=3 fail=0 err=0 |
| core/process/setpgid_spec.rb | (nothing failed -- the record may be stale) |
| core/process/setpgrp_spec.rb | pass=0 fail=0 err=0 pass=1 fail=0 err=0 |
| core/process/setpgrp_spec.rb | (nothing failed -- the record may be stale) |
| core/process/setpriority_spec.rb | pass=0 fail=0 err=1 pass=2 fail=0 err=0 |
| core/process/setrlimit_spec.rb | pass=0 fail=0 err=30 pass=30 fail=0 err=0 |
| core/process/setrlimit_spec.rb | ERROR: when passed an Object calls #to_int to convert resource to an Integer: NoMethodError -- undefined method 'getrlimit' for module Process |
| core/process/setrlimit_spec.rb | ERROR: when passed an Object raises a TypeError if #to_int for resource does not return an Integer: NoMethodError -- undefined method 'getrlimit' for module Process |
| core/process/setrlimit_spec.rb | ERROR: when passed an Object calls #to_int to convert the soft limit to an Integer: NoMethodError -- undefined method 'getrlimit' for module Process |
| core/process/spawn_spec.rb | pass=96 fail=4 err=0 pass=100 fail=0 err=0 |
| core/process/status/exited_spec.rb | pass=1 fail=1 err=0 pass=2 fail=0 err=0 |
| core/process/status/exitstatus_spec.rb | pass=1 fail=1 err=0 pass=2 fail=0 err=0 |
| core/process/status/signaled_spec.rb | pass=1 fail=1 err=0 pass=2 fail=0 err=0 |
| core/process/status/success_spec.rb | pass=2 fail=1 err=0 pass=3 fail=0 err=0 |
| core/process/status/termsig_spec.rb | pass=1 fail=2 err=0 pass=3 fail=0 err=0 |
| core/process/status/termsig_spec.rb | FAILED: returns the signal: expected 15, got nil |
| core/process/status/wait_spec.rb | pass=16 fail=0 err=0 pass=18 fail=0 err=0 |
| core/process/status/wait_spec.rb | (nothing failed -- the record may be stale) |
| core/process/wait_spec.rb | pass=17 fail=0 err=0 pass=19 fail=0 err=0 |
| core/process/wait_spec.rb | (nothing failed -- the record may be stale) |
| core/queue/freeze_spec.rb | pass=0 fail=1 err=0 pass=1 fail=0 err=0 |
| core/queue/initialize_spec.rb | pass=19 fail=0 err=1 pass=20 fail=0 err=0 |
| core/range/clone_spec.rb | pass=10 fail=2 err=0 pass=12 fail=0 err=0 |
| core/range/clone_spec.rb | FAILED: duplicates the range: expected not to be identical |
| core/range/dup_spec.rb | pass=6 fail=1 err=0 pass=7 fail=0 err=0 |
| core/refinement/import_methods_spec.rb | pass=0 fail=0 err=15 pass=19 fail=0 err=0 |
| core/refinement/import_methods_spec.rb | ERROR: Refinement#import_methods warns if a module includes/prepends some other module: NoMethodError -- undefined method 'import_methods' for module #<refinement:String@#<Module:0xADDR>> |
| core/refinement/import_methods_spec.rb | ERROR: Refinement#import_methods doesn't import methods from included/prepended modules: NoMethodError -- undefined method 'import_methods' for module #<refinement:String@#<Module:0xADDR>> |
| core/refinement/import_methods_spec.rb | ERROR: Refinement#import_methods doesn't import any methods if one of the arguments is not a module: NoMethodError -- undefined method 'import_methods' for module #<refinement:String@#<Module:0xADDR>> |
| core/regexp/initialize_spec.rb | pass=3 fail=0 err=1 pass=4 fail=0 err=0 |
| core/regexp/last_match_spec.rb | pass=9 fail=2 err=0 pass=11 fail=0 err=0 |
| core/regexp/last_match_spec.rb | FAILED: raises an IndexError when given a missing name: expected IndexError to be raised |
| core/regexp/timeout_spec.rb | pass=3 fail=0 err=2 pass=5 fail=0 err=0 |
| core/regexp/timeout_spec.rb | ERROR: Regexp.timeout raises Regexp::TimeoutError after global timeout elapsed: NameError -- uninitialized constant Regexp::TimeoutError |
| core/signal/trap_spec.rb | pass=57 fail=1 err=0 pass=58 fail=0 err=0 |
| core/sizedqueue/freeze_spec.rb | pass=0 fail=1 err=0 pass=1 fail=0 err=0 |
| core/sizedqueue/max_spec.rb | pass=9 fail=6 err=0 pass=15 fail=0 err=0 |
| core/sizedqueue/max_spec.rb | FAILED: raises a TypeError when given a non-numeric value: expected TypeError to be raised |
| core/sizedqueue/max_spec.rb | FAILED: raises a TypeError when given a non-numeric value: expected TypeError to be raised |
| core/sizedqueue/max_spec.rb | FAILED: raises an argument error when set to zero: expected ArgumentError to be raised |
| core/sizedqueue/new_spec.rb | pass=3 fail=0 err=1 pass=7 fail=0 err=0 |
| core/string/encode_spec.rb | pass=176 fail=2 err=4 pass=182 fail=0 err=0 |
| core/string/encode_spec.rb | FAILED: replaces invalid characters when replacing Emacs-Mule encoded strings: expected "?", got "\x80" |
| core/string/encode_spec.rb | ERROR: when passed to, from transcodes between the encodings ignoring the String encoding: Encoding::UndefinedConversionError -- U+00FC to EUC-JP in conversion from ibm437 to UTF-8 to EUC-JP |
| core/string/encode_spec.rb | ERROR: when passed to, from calls #to_str to convert the from object to an Encoding: Encoding::UndefinedConversionError -- U+00FC to EUC-JP in conversion from ibm437 to UTF-8 to EUC-JP |
| core/string/modulo_spec.rb | pass=1042 fail=0 err=2 pass=1045 fail=0 err=0 |
| core/string/modulo_spec.rb | ERROR: String#% raises Encoding::CompatibilityError if both encodings are ASCII compatible and there are not ASCII characters: Encoding::UndefinedConversionError -- U+00C4 from UTF-8 to Windows-1252 |
| core/symbol/to_proc_spec.rb | pass=11 fail=3 err=0 pass=14 fail=0 err=0 |
| core/symbol/to_proc_spec.rb | FAILED: only calls public methods: expected NoMethodError /protected method [`']pro' called/ to be raised |
| core/symbol/to_proc_spec.rb | FAILED: only calls public methods: expected [:pub], got [:pub, :pro] |
| core/thread/backtrace/location/absolute_path_spec.rb | pass=5 fail=8 err=0 pass=13 fail=0 err=0 |
| core/thread/backtrace/location/absolute_path_spec.rb | FAILED: returns the absolute path of the call frame: expected "/privateTMPDIR got "TMPDIR |
| core/thread/backtrace/location/label_spec.rb | pass=46 fail=3 err=1 pass=51 fail=0 err=0 |
| core/thread/backtrace/location/label_spec.rb | ERROR: is Module#method for a core method defined natively: NameError -- undefined method 'instance_exec' for class 'BasicObject' |
| core/thread/backtrace/location/label_spec.rb | FAILED: a core method defined in Ruby: expected truthy from #source_location |
| core/thread/backtrace/location/label_spec.rb | FAILED: main.label_sdef_method_of_main: expected "label_sdef_method_of_main", got "Object#label_sdef_method_of_main" |
| core/thread/element_set_spec.rb | pass=8 fail=0 err=1 pass=9 fail=0 err=0 |
| core/thread/handle_interrupt_spec.rb | pass=21 fail=0 err=0 pass=21 fail=2 err=0 |
| core/thread/handle_interrupt_spec.rb | (nothing failed -- the record may be stale) |
| core/thread/list_spec.rb | pass=911 fail=0 err=0 pass=498571 fail=0 err=0 |
| core/thread/list_spec.rb | (nothing failed -- the record may be stale) |
| core/thread/native_thread_id_spec.rb | pass=0 fail=0 err=3 pass=5 fail=0 err=0 |
| core/thread/native_thread_id_spec.rb | ERROR: Thread#native_thread_id returns an integer when the thread is alive: NoMethodError -- undefined method 'native_thread_id' for an instance of Thread |
| core/thread/native_thread_id_spec.rb | ERROR: Thread#native_thread_id returns nil when the thread is not running: NoMethodError -- undefined method 'native_thread_id' for an instance of Thread |
| core/thread/raise_spec.rb | pass=101 fail=2 err=4 pass=115 fail=0 err=0 |
| core/thread/raise_spec.rb | FAILED: re-raises a previously rescued exception without overwriting the backtrace: expected ["TMPDIR 'block (2 levels) in <top (required)>'", "TMPDIR 'BasicObject#instance_exec'", "TMPDIR 'Object#__mspec_protect'", "TMPDIR 'Object#__mspec_ ...[clipped] |
| core/thread/raise_spec.rb | FAILED: re-raises a previously rescued exception without overwriting the backtrace: expected #<RuntimeError: raised>, got #<RuntimeError: raised> |
| core/thread/raise_spec.rb | ERROR: with cause keyword argument uses the cause from the calling context: RuntimeError -- second error |
| core/thread/thread_variable_get_spec.rb | pass=9 fail=0 err=1 pass=10 fail=0 err=0 |
| core/thread/thread_variable_set_spec.rb | pass=10 fail=0 err=1 pass=11 fail=0 err=0 |
| core/thread/thread_variable_spec.rb | pass=10 fail=0 err=1 pass=11 fail=0 err=0 |
| core/time/dup_spec.rb | pass=4 fail=0 err=1 pass=4 fail=0 err=0 |
| core/time/minus_spec.rb | pass=25 fail=3 err=0 pass=28 fail=0 err=0 |
| core/time/minus_spec.rb | FAILED: tracks microseconds: expected 123456, got 123455 |
| core/time/minus_spec.rb | FAILED: tracks microseconds: expected 123456, got 123455 |
| core/time/new_spec.rb | pass=2358 fail=8 err=0 pass=2366 fail=0 err=0 |
| core/time/new_spec.rb | FAILED: raises TypeError if timezone does not implement #local_to_utc method: expected TypeError /can't convert Object into an exact number/ to be raised |
| core/time/new_spec.rb | FAILED: cannot have arbitrary #utc_offset if it is an instance of Time: expected 32400, got 0 |
| core/time/new_spec.rb | FAILED: raises ArgumentError if difference between argument and result is too large: expected ArgumentError "utc_offset out of range" to be raised |
| core/time/plus_spec.rb | pass=26 fail=1 err=0 pass=27 fail=0 err=0 |
| core/time/strftime_spec.rb | pass=176 fail=1 err=0 pass=177 fail=0 err=0 |
| core/tracepoint/allow_reentry_spec.rb | pass=0 fail=1 err=1 pass=2 fail=0 err=0 |
| core/tracepoint/allow_reentry_spec.rb | FAILED: allows the reentrance in a given block: expected [18, nil, nil, 19, nil, nil], got [18, 18, 19, 19] |
| core/tracepoint/binding_spec.rb | pass=0 fail=2 err=1 pass=3 fail=0 err=0 |
| core/tracepoint/binding_spec.rb | FAILED: return the generated binding object from event: expected 1, got 0 |
| core/tracepoint/binding_spec.rb | FAILED: return the generated binding object from event: expected a Binding, got nil |
| core/tracepoint/enable_spec.rb | pass=26 fail=19 err=0 pass=45 fail=0 err=0 |
| core/tracepoint/enable_spec.rb | FAILED: traces all the events triggered in specified location: expected [:b_call, :b_return, :call, :line, :return], got [:call, :return] |
| core/tracepoint/enable_spec.rb | FAILED: traces some events in nested blocks: expected [227, 228, 229], got [] |
| core/tracepoint/enable_spec.rb | FAILED: raises ArgumentError if target object cannot trigger specified event: expected ArgumentError /can not enable any hooks/ to be raised |
| core/tracepoint/eval_script_spec.rb | pass=0 fail=1 err=0 pass=1 fail=0 err=0 |
| core/tracepoint/inspect_spec.rb | pass=3 fail=6 err=0 pass=9 fail=0 err=0 |
| core/tracepoint/inspect_spec.rb | FAILED: returns a String showing the event, method, path and line for a :call event: expected "#<TracePoint:call 'trace_point_spec_test_call' TMPDIR to match |
| core/tracepoint/inspect_spec.rb | FAILED: returns a String showing the event, method, path and line for a :return event: expected "#<TracePoint:return 'trace_point_spec_test_return' TMPDIR to match |
| core/tracepoint/inspect_spec.rb | FAILED: returns a String showing the event, method, path and line for a :c_call event: expected nil to match |
| core/tracepoint/parameters_spec.rb | pass=0 fail=2 err=0 pass=2 fail=0 err=0 |
| core/tracepoint/parameters_spec.rb | FAILED: returns the parameters of block: expected [[:opt, :x], [:opt, :y], [:opt, :z]], got nil |
| core/tracepoint/path_spec.rb | pass=1 fail=1 err=0 pass=2 fail=0 err=0 |
| core/unboundmethod/clone_spec.rb | pass=4 fail=2 err=0 pass=6 fail=0 err=0 |
| core/unboundmethod/clone_spec.rb | FAILED: copies instance variables: expected [:@ivar], got [] |
| core/unboundmethod/dup_spec.rb | pass=4 fail=2 err=0 pass=6 fail=0 err=0 |
| core/unboundmethod/dup_spec.rb | FAILED: copies instance variables: expected [:@ivar], got [] |
| core/unboundmethod/equal_value_spec.rb | pass=41 fail=0 err=3 pass=47 fail=0 err=0 |
| core/unboundmethod/equal_value_spec.rb | ERROR: UnboundMethod#== considers methods through aliasing equal: NameError -- undefined method 'n' for class '#<Class:0xADDR>' |
| core/unboundmethod/equal_value_spec.rb | ERROR: UnboundMethod#== considers methods through visibility change equal: NameError -- undefined method 'new' for class 'Class' |
| core/unboundmethod/source_location_spec.rb | pass=8 fail=1 err=0 pass=9 fail=0 err=0 |
| core/warning/element_set_spec.rb | pass=8 fail=1 err=0 pass=9 fail=0 err=0 |
| core/warning/performance_warning_spec.rb | pass=0 fail=1 err=0 pass=1 fail=0 err=0 |
| language/END_spec.rb | pass=16 fail=2 err=0 pass=18 fail=0 err=0 |
| language/END_spec.rb | FAILED: runs handlers even if the main script fails to parse: expected truthy from #include? |
| language/assignments_spec.rb | pass=59 fail=2 err=2 pass=63 fail=0 err=0 |
| language/assignments_spec.rb | ERROR: given block argument raises SyntaxError: ArgumentError -- wrong number of arguments (given 3, expected 2) |
| language/assignments_spec.rb | FAILED: raises SyntaxError when given keyword arguments in index assignments: expected SyntaxError /keywords are not allowed in index assignment expressions\|keyword arg given in index assignment/ to be raised |
| language/assignments_spec.rb | ERROR: given block argument raises SyntaxError: ArgumentError -- wrong number of arguments (given 2, expected 1) |
| language/block_spec.rb | pass=212 fail=8 err=1 pass=221 fail=0 err=0 |
| language/block_spec.rb | ERROR: Array raises error when required keyword arguments are present: ArgumentError -- missing keyword: :b |
| language/block_spec.rb | FAILED: assigns elements to mixed argument types: expected [1, 2, [3], {x: 9}, 2, {}], got [[1, 2, 3, {x: 9}], 5, [], nil, 2, {}] |
| language/block_spec.rb | FAILED: assigns the first variable named: expected 1, got 2 |
| language/break_spec.rb | pass=54 fail=2 err=0 pass=56 fail=0 err=0 |
| language/break_spec.rb | FAILED: returns from the lambda: expected [:a, :d, :aaa, :b, :bbb, :e], got [:a, :d, :aaa, :b, :e] |
| language/constants_spec.rb | pass=155 fail=0 err=1 pass=156 fail=0 err=0 |
| language/def_spec.rb | pass=126 fail=5 err=4 pass=137 fail=0 err=0 |
| language/def_spec.rb | FAILED: raises FrozenError with the correct class name: expected "can't modify frozen Module: ", got "can't modify frozen Module: #<Module:0xADDR>" |
| language/def_spec.rb | FAILED: raises FrozenError with the correct class name: expected "can't modify frozen Class: ", got "can't modify frozen Class: #<Class:0xADDR>" |
| language/def_spec.rb | FAILED: allows only a single * argument: expected SyntaxError to be raised |
| language/defined_spec.rb | pass=314 fail=8 err=0 pass=322 fail=0 err=0 |
| language/defined_spec.rb | FAILED: returns 'global-variable' for $&: expected "global-variable", got nil |
| language/defined_spec.rb | FAILED: returns 'global-variable' for $`: expected "global-variable", got nil |
| language/defined_spec.rb | FAILED: returns 'global-variable' for $': expected "global-variable", got nil |
| language/delegation_spec.rb | pass=11 fail=3 err=1 pass=15 fail=0 err=0 |
| language/delegation_spec.rb | ERROR: delegation with def(...) parses as open endless Range when brackets are omitted: StandardError -- mere-ruby: unexpected keyword: end in (eval)         def delegate(...) |
| language/delegation_spec.rb | FAILED: does not allow delegating rest: expected SyntaxError /anonymous rest parameter is also used within block/ to be raised |
| language/delegation_spec.rb | FAILED: does not allow delegating kwargs: expected SyntaxError /anonymous keyword rest parameter is also used within block/ to be raised |
| language/file_spec.rb | pass=9 fail=1 err=0 pass=10 fail=0 err=0 |
| language/hash_spec.rb | pass=95 fail=0 err=2 pass=97 fail=0 err=0 |
| language/hash_spec.rb | ERROR: hash with omitted value raises a SyntaxError when the hash key ends with `!`: SyntaxError -- syntax error |
| language/heredoc_spec.rb | pass=24 fail=1 err=0 pass=25 fail=0 err=0 |
| language/if_spec.rb | pass=59 fail=2 err=0 pass=61 fail=0 err=0 |
| language/if_spec.rb | FAILED: warns when Integer literals are used instead of predicates: matcher did not match #<Proc> |
| language/lambda_spec.rb | pass=119 fail=6 err=2 pass=129 fail=0 err=0 |
| language/lambda_spec.rb | FAILED: : expected to be identical |
| language/lambda_spec.rb | FAILED: : expected [9, 8, [7], [], 6, 5, 4, 3, {}, #<Proc:0xADDR TMPDIR (lambda)>], got [9, 8, [7], [], 6, 5, 4, 3, {}, #<Proc:0xADDR TMPDIR |
| language/lambda_spec.rb | FAILED: : expected [1, 1, [], 2, 3, 2, 4, {h: 5, i: 6}, #<Proc:0xADDR TMPDIR (lambda)>], got [1, 1, [], 2, 3, 2, 4, {h: 5, i: 6}, #<Proc:0xADDR TMPDIR |
| language/magic_comment_spec.rb | pass=23 fail=30 err=1 pass=54 fail=0 err=0 |
| language/magic_comment_spec.rb | FAILED: are case-insensitive: expected "Big5", got "UTF-8" |
| language/magic_comment_spec.rb | FAILED: can be after the shebang: expected "Big5", got "UTF-8" |
| language/magic_comment_spec.rb | FAILED: can take Emacs style: expected "Big5", got "UTF-8" |
| language/method_spec.rb | pass=296 fail=5 err=0 pass=301 fail=0 err=0 |
| language/method_spec.rb | FAILED: warns when passing a block argument to a method that never uses it: matcher did not match #<Proc> |
| language/method_spec.rb | FAILED: warns when passing a block argument to a method that calls #block_given?: matcher did not match #<Proc> |
| language/method_spec.rb | FAILED: warns only once per call site: matcher did not match #<Proc> |
| language/numbered_parameters_spec.rb | pass=39 fail=0 err=4 pass=43 fail=0 err=0 |
| language/numbered_parameters_spec.rb | ERROR: Numbered parameters can not be used in both outer and nested blocks at the same time: SyntaxError -- invalid numbered parameter |
| language/numbered_parameters_spec.rb | ERROR: Numbered parameters cannot be overwritten with local variable: SyntaxError -- invalid numbered parameter |
| language/numbered_parameters_spec.rb | ERROR: Numbered parameters errors when numbered parameter is overwritten with local variable: SyntaxError -- invalid numbered parameter |
| language/optional_assignments_spec.rb | pass=111 fail=3 err=0 pass=114 fail=0 err=0 |
| language/optional_assignments_spec.rb | FAILED: with \|\|= do not reassign: expected 20, got 10 |
| language/optional_assignments_spec.rb | FAILED: with &&= assignments will fail with non-existent constants: expected NameError to be raised |
| language/or_spec.rb | pass=20 fail=0 err=3 pass=23 fail=0 err=0 |
| language/or_spec.rb | ERROR: The or operator has a lower precedence than 'break' in 'break true or false': SyntaxError -- : syntax error, unexpected local variable or method, expecting end-of-input |
| language/or_spec.rb | ERROR: The or operator has a lower precedence than 'next' in 'next true or false': SyntaxError -- : syntax error, unexpected local variable or method, expecting end-of-input |
| language/pattern_matching_spec.rb | pass=146 fail=0 err=7 pass=154 fail=0 err=0 |
| language/pattern_matching_spec.rb | ERROR: Pattern matching cannot mix in and when operators: SyntaxError -- syntax error |
| language/pattern_matching_spec.rb | ERROR: Pattern matching does not allow calculation or method calls in a pattern: SyntaxError -- syntax error |
| language/pattern_matching_spec.rb | ERROR: variable pattern does not support using variable name (except _) several times: SyntaxError -- syntax error |
| language/predefined_spec.rb | pass=310 fail=12 err=7 pass=327 fail=1 err=1 |
| language/predefined_spec.rb | FAILED: is set at the method-scoped level rather than block-scoped: expected #<MatchData "bar">, got #<MatchData "foo"> |
| language/predefined_spec.rb | FAILED: is set at the method-scoped level rather than block-scoped: expected #<MatchData "qux">, got #<MatchData "baz"> |
| language/predefined_spec.rb | FAILED: warns if assigned non-nil: matcher did not match #<Proc> |
| language/regexp/encoding_spec.rb | pass=28 fail=6 err=1 pass=35 fail=0 err=0 |
| language/regexp/encoding_spec.rb | FAILED: supports /n (No encoding): expected ["\xC3"], got ["\xC3\xA9"] |
| language/regexp/encoding_spec.rb | FAILED: supports /n (No encoding) with interpolation: expected ["\xC3"], got ["\xC3\xA9"] |
| language/regexp/encoding_spec.rb | FAILED: supports /n (No encoding) with interpolation /o: expected ["\xC3"], got ["\xC3\xA9"] |
| language/regexp/repetition_spec.rb | pass=68 fail=1 err=0 pass=69 fail=0 err=0 |
| language/regexp/subexpression_call_spec.rb | pass=10 fail=0 err=2 pass=16 fail=0 err=0 |
| language/regexp/subexpression_call_spec.rb | ERROR: Regexps with subexpression calls allows recursive subexpression calls: NoMethodError -- undefined method '[]' for nil |
| language/rescue_spec.rb | pass=92 fail=7 err=3 pass=103 fail=0 err=0 |
| language/rescue_spec.rb | FAILED: converts the splatted list of exceptions using #to_a: expected to receive #to_a |
| language/rescue_spec.rb | FAILED: raises SyntaxError when else is used without rescue and ensure: expected SyntaxError /else without rescue is useless/ to be raised |
| language/rescue_spec.rb | FAILED: parses  'a += b rescue c' as 'a += (b rescue c)': expected "ac", got "c" |
| language/return_spec.rb | pass=49 fail=3 err=1 pass=54 fail=0 err=0 |
| language/return_spec.rb | FAILED: raises a SyntaxError: expected SyntaxError to be raised |
| language/return_spec.rb | FAILED: is not allowed: expected LocalJumpError to be raised |
| language/return_spec.rb | ERROR: within BEGIN is allowed: SyntaxError -- BEGIN is permitted only at toplevel |
| language/safe_navigator_spec.rb | pass=24 fail=1 err=0 pass=25 fail=0 err=0 |
| language/string_spec.rb | pass=76 fail=4 err=1 pass=81 fail=0 err=0 |
| language/string_spec.rb | FAILED: backslashes follow the same rules as interpolation: expected " |
| language/string_spec.rb | ERROR: Ruby character strings allows a dynamic string to parse a nested do...end block as an argument to a call without parens, interpolated: SyntaxError -- syntax error |
| language/string_spec.rb | FAILED: produce the same object each time: expected "true", got "false" |
| language/variables_spec.rb | pass=170 fail=2 err=0 pass=172 fail=0 err=0 |
| language/variables_spec.rb | FAILED: parses a non-ASCII upcased character as a constant identifier: expected SyntaxError /dynamic constant assignment/ to be raised |
| library/irb/irb_spec.rb | pass=0 fail=1 err=0 pass=1 fail=0 err=0 |
| library/logger/logger/new_spec.rb | pass=11 fail=3 err=1 pass=16 fail=0 err=0 |
| library/logger/logger/new_spec.rb | FAILED: receives a maximum logfile size as third argument: expected truthy from #exist? |
| library/logger/logger/new_spec.rb | ERROR: Logger#new receives a maximum logfile size as third argument: Errno::ENOENT -- No such file or directory @ rb_sysopen - TMPDIR ...[clipped] |
| library/logger/logger/new_spec.rb | FAILED: receives level symbol as keyword argument: expected 1, got :info |
| library/mkmf/mkmf_spec.rb | pass=0 fail=1 err=0 pass=1 fail=0 err=0 |
| library/openssl/kdf/pbkdf2_hmac_spec.rb | pass=0 fail=0 err=1 pass=25 fail=0 err=0 |
| library/openssl/x509/name/parse_spec.rb | pass=0 fail=0 err=4 pass=16 fail=0 err=0 |
| library/openssl/x509/name/parse_spec.rb | ERROR: OpenSSL::X509::Name.parse parses a /-delimited string of key-value pairs into a Name: NameError -- uninitialized constant OpenSSL::X509::Name |
| library/openssl/x509/name/parse_spec.rb | ERROR: OpenSSL::X509::Name.parse parses a comma-delimited string of key-value pairs into a name: NameError -- uninitialized constant OpenSSL::X509::Name |
| library/openssl/x509/name/parse_spec.rb | ERROR: OpenSSL::X509::Name.parse raises TypeError if the given string contains no key/value pairs: NameError -- uninitialized constant OpenSSL::X509::Name |
| library/openssl/x509/store/verify_spec.rb | pass=0 fail=0 err=3 pass=3 fail=0 err=0 |
| library/openssl/x509/store/verify_spec.rb | ERROR: OpenSSL::X509::Store#verify returns true for valid certificate: NameError -- uninitialized constant OpenSSL::PKey::RSA |
| library/openssl/x509/store/verify_spec.rb | ERROR: OpenSSL::X509::Store#verify returns false for an expired certificate: NameError -- uninitialized constant OpenSSL::PKey::RSA |
| library/rbconfig/rbconfig_spec.rb | pass=34 fail=5 err=2 pass=525 fail=0 err=0 |
| library/rbconfig/rbconfig_spec.rb | FAILED: has MAJOR, MINOR, TEENY, and PATCHLEVEL matching RUBY_VERSION and RUBY_PATCHLEVEL: expected ["4", "0", "6", "0"], got [nil, nil, nil, nil] |
| library/rbconfig/rbconfig_spec.rb | FAILED: ['rubylibdir'] returns the directory containing Ruby standard libraries: expected true, got false |
| library/rbconfig/rbconfig_spec.rb | FAILED: ['rubylibdir'] returns the directory containing Ruby standard libraries: expected truthy from #exist? |
| library/socket/ipsocket/addr_spec.rb | pass=8 fail=14 err=0 pass=22 fail=0 err=0 |
| library/socket/ipsocket/addr_spec.rb | FAILED: returns an array with the socket's information: expected "localhost", got "0.0.0.0" |
| library/socket/ipsocket/addr_spec.rb | FAILED: returns an array with the socket's information: expected "127.0.0.1", got "0.0.0.0" |
| library/socket/ipsocket/addr_spec.rb | FAILED: returns an address in the array if do_not_reverse_lookup is true: expected "127.0.0.1", got "0.0.0.0" |
| library/socket/ipsocket/inspect_spec.rb | pass=2 fail=0 err=2 pass=4 fail=0 err=0 |
| library/socket/ipsocket/inspect_spec.rb | ERROR: IPSocket#inspect returns a String with the fd, family, address and port for UDPSocket: NotImplementedError -- UDPSocket#bind is not implemented (mere-ruby cannot pass a sockaddr to bind(2)) |
| library/socket/ipsocket/recvfrom_spec.rb | pass=6 fail=0 err=8 pass=18 fail=0 err=0 |
| library/socket/ipsocket/recvfrom_spec.rb | ERROR: using IPv4 returns an empty String as received data: NotImplementedError -- UDPSocket#bind is not implemented (mere-ruby cannot pass a sockaddr to bind(2)) |
| library/socket/ipsocket/recvfrom_spec.rb | ERROR: using IPv6 returns an empty String as received data: NotImplementedError -- UDPSocket#bind is not implemented (mere-ruby cannot pass a sockaddr to bind(2)) |
| library/socket/ipsocket/recvfrom_spec.rb | ERROR: using IPv4 returns an Array containing up to N bytes and address information: NotImplementedError -- UDPSocket#bind is not implemented (mere-ruby cannot pass a sockaddr to bind(2)) |
| library/stringio/puts_spec.rb | pass=22 fail=1 err=0 pass=22 fail=1 err=0 |
| library/stringio/puts_spec.rb | FAILED: returns general object info if :to_s does not return a string: expected "#<MockObject> |
| library/tempfile/create_spec.rb | pass=30 fail=13 err=1 pass=44 fail=0 err=0 |
| library/tempfile/create_spec.rb | FAILED: returns a new, open regular File instance placed in tmpdir: expected true, got false |
| library/tempfile/create_spec.rb | FAILED: returns a private, readable and writable file: expected falsy from #world_readable? |
| library/tempfile/create_spec.rb | FAILED: raises ArgumentError if passed something else than a String or an array of Strings: expected ArgumentError "unexpected prefix: :create_spec" to be raised |
| library/tempfile/initialize_spec.rb | pass=3 fail=3 err=0 pass=6 fail=0 err=0 |
| library/tempfile/initialize_spec.rb | FAILED: sets the permissions on the tempfile to 0600: expected 33152, got 33188 |
| library/tempfile/initialize_spec.rb | FAILED: accepts encoding options: expected #<Encoding:Shift_JIS>, got nil |
| library/tempfile/open_spec.rb | pass=11 fail=2 err=0 pass=13 fail=0 err=0 |
| library/tempfile/open_spec.rb | FAILED: passes the third argument (options) to open: expected #<Encoding:IBM037 (dummy)>, got nil |
| library/tmpdir/dir/mktmpdir_spec.rb | pass=13 fail=2 err=0 pass=3 fail=0 err=6 |
| library/tmpdir/dir/mktmpdir_spec.rb | FAILED: creates the tmp-dir before yielding: expected to receive #tmpdir |
| library/tmpdir/dir/mktmpdir_spec.rb | FAILED: removes the tmp-dir after executing the block: expected to receive #remove_entry |
| library/tmpdir/dir/mktmpdir_spec.rb | ERROR: Dir.mktmpdir when passed no arguments creates a new writable directory in the path provided by Dir.tmpdir: NoMethodError -- undefined method 'mkdir' for class Dir |
| library/yaml/to_yaml_spec.rb | pass=28 fail=4 err=0 pass=32 fail=0 err=0 |
| library/yaml/to_yaml_spec.rb | FAILED: returns the YAML representation of an object: matcher did not match "--- !ruby/object:YAMLSpecs::Example |
| library/zlib/deflate/deflate_spec.rb | pass=4 fail=8 err=1 pass=13 fail=0 err=0 |
| library/zlib/deflate/deflate_spec.rb | FAILED: deflates some data: expected "x\x9Cc`\x80 |
| library/zlib/deflate/deflate_spec.rb | FAILED: deflates lots of data: expected "x\x9C\xED\xC1\x80\x90\xFE\xAF\xEE |
| library/zlib/deflate/deflate_spec.rb | ERROR: Zlib::Deflate.deflate deflates chunked data: NoMethodError -- undefined method 'deflate' for class Zlib::Deflate |
| library/zlib/deflate/set_dictionary_spec.rb | pass=0 fail=0 err=1 pass=1 fail=0 err=0 |
| library/zlib/deflate_spec.rb | pass=0 fail=1 err=0 pass=1 fail=0 err=0 |
| library/zlib/gzip_spec.rb | pass=0 fail=1 err=0 pass=1 fail=0 err=0 |
| library/zlib/gzipfile/close_spec.rb | pass=3 fail=1 err=0 pass=4 fail=0 err=0 |
| library/zlib/gzipreader/rewind_spec.rb | pass=7 fail=0 err=0 pass=4 fail=0 err=1 |

# mere-ruby — what the gap is made of

The records in `SPEC_STATUS.md` and `mspec/tags/`, grouped by CAUSE rather
than by group. A count is a number of spec FILES. The text is the first line
where mere-ruby and ruby disagree (DIFF) or the message it aborted with
(CRASH), with paths and addresses masked.

**KIND** masks the values and keeps the shape -- this is the column that says
what to work on. **CAUSE** is the line as recorded, for reproducing one.

Regenerate with `./mspec/causes.sh` (reads `mspec/tags/`, no sweep).

Classified: 815 files.

## DIFF — 815 files, 165 kinds

| files | kind |
|---|---|
| 227 | `ERROR NoMethodError` |
| 71 | `ERROR NameError` |
| 45 | `FAILED expected "S", got "S"` |
| 26 | `FAILED expected N, got N` |
| 22 | `FAILED expected true, got false` |
| 20 | `FAILED expected truthy from #include?` |
| 20 | `FAILED expected #<OBJ>, got #<OBJ>` |
| 19 | `FAILED expected ArgumentError to be raised` |
| 16 | `FAILED matcher did not match #<OBJ>` |
| 15 | `FAILED expected TypeError to be raised` |
| 15 | `FAILED expected N, got nil` |
| 15 | `ERROR ArgumentError` |
| 14 | `FAILED expected false, got true` |
| 12 | `FAILED expected to be identical` |
| 11 | `ERROR StandardError` |
| 10 | `FAILED expected "S", got nil` |
| 9 | `pass=N fail=N err=N` |
| 9 | `FAILED raised NoMethodError, expected TypeError` |
| 9 | `ERROR NotImplementedError` |
| 9 | `*.rb:N: warning: already initialized constant Digest::MN` |
| 8 | `FAILED expected NoMethodError to be raised` |
| 7 | `ERROR TypeError` |
| 6 | `FAILED expected falsy from #include?` |
| 6 | `ERROR SystemExit` |
| 5 | `FAILED expected IOError to be raised` |
| 4 | `FAILED raised NoMethodError, expected ArgumentError` |
| 4 | `FAILED expected nil, got "S"` |
| 4 | `FAILED expected SyntaxError to be raised` |
| 4 | `FAILED expected RangeError to be raised` |
| 4 | `FAILED expected NameError to be raised` |
| 4 | `FAILED expected "S" to match` |
| 3 | `FAILED expected not to be identical` |
| 3 | `FAILED expected false, got nil` |
| 3 | `FAILED expected [:SYM, :SYM], got nil` |
| 3 | `FAILED expected ["S"], got []` |
| 3 | `FAILED expected Math::DomainError to be raised` |
| 3 | `FAILED expected :SYM, got nil` |
| 3 | `FAILED expected "S", got "S"\"S"` |
| 2 | `TMPDIR` |
| 2 | `FAILED raised StandardError, expected FrozenError` |
| 2 | `FAILED raised NoMethodError, expected FrozenError` |
| 2 | `FAILED expected {...}, got {...}` |
| 2 | `FAILED expected to receive #to_str` |
| 2 | `FAILED expected to receive #rewind` |
| 2 | `FAILED expected a Integer, got N` |
| 2 | `FAILED expected [nil, N, N, N, N, nil, :SYM, [], [], [N], [N, N], [N, N, N]], got [nil, N, [N, N], [N, N, N], [N, N, N], nil, :SYM, [], [], [N], [N, N] ...[clipped]` |
| 2 | `FAILED expected [], got [N, N, N]` |
| 2 | `FAILED expected [N, N, N, N], got [N, N, N, N]` |
| 2 | `FAILED expected ThreadError to be raised` |
| 2 | `FAILED expected NNN N:N:N +N, got NNN N:N:N UTC` |
| 2 | `FAILED expected :SYM, got false` |
| 2 | `FAILED expected #<OBJ>, got nil` |
| 2 | `ERROR Zlib::GzipFile::Error` |
| 2 | `ERROR SystemStackError` |
| 2 | `ERROR Errno::ENOENT` |
| 1 | `This is experimental warning.` |
| 1 | `FAILED raised TypeError, expected ArgumentError` |
| 1 | `FAILED raised ThreadError, expected ArgumentError` |
| 1 | `FAILED raised StandardError, expected RuntimeError` |
| 1 | `FAILED raised StandardError, expected ArgumentError` |
| 1 | `FAILED raised NoMethodError, expected ThreadError` |
| 1 | `FAILED raised NoMethodError, expected LocalJumpError` |
| 1 | `FAILED raised NoMethodError, expected Date::Error` |
| 1 | `FAILED raised NameError, expected ArgumentError` |
| 1 | `FAILED raised LoadError, expected NameError` |
| 1 | `FAILED raised FrozenError, expected TypeError` |
| 1 | `FAILED raised ArgumentError, expected SyntaxError` |
| 1 | `FAILED raised ArgumentError, expected IOError` |
| 1 | `FAILED expected {year: N, month: N, day: N, yday: N, wday: N, hour: N, min: N, sec: N, sec_fraction: N, zone: "S"}, got {year: N, month: N, day: N, yday: N, wday: N}` |
| 1 | `FAILED expected {#<OBJ> => N}, got {}` |
| 1 | `FAILED expected truthy from #start_with?` |
| 1 | `FAILED expected truthy from #julian?` |
| 1 | `FAILED expected truthy from #exist?` |
| 1 | `FAILED expected truthy from #const_defined?` |
| 1 | `FAILED expected truthy from #>=` |
| 1 | `FAILED expected true, got nil` |
| 1 | `FAILED expected to receive #to_int` |
| 1 | `FAILED expected to receive #to_a` |
| 1 | `FAILED expected to receive #respond_to_missing?` |
| 1 | `FAILED expected not true` |
| 1 | `FAILED expected not nil` |
| 1 | `FAILED expected not N` |
| 1 | `FAILED expected nil, got NaN` |
| 1 | `FAILED expected nil to match` |
| 1 | `FAILED expected a Enumerable, got #<OBJ>` |
| 1 | `FAILED expected a Array, got nil` |
| 1 | `FAILED expected [nil, N, [N, N], [N, N, N], [N, N, N], nil, :SYM, [:SYM, :SYM], [], [N], [N, N], [N, N, N]], got [nil, N, [N, N], [N, N, N], [N, N, N], nil, :SYM, [], [], [N], [N, N], [N, ...[clipped]` |
| 1 | `FAILED expected [], got [:SYM]` |
| 1 | `FAILED expected [[:SYM, :SYM], [:SYM, :SYM], [:SYM, :SYM]], got nil` |
| 1 | `FAILED expected [[:SYM, :SYM], [:SYM, :SYM], [:SYM, :SYM], [:SYM, :SYM], [:SYM, :SYM], [:SYM, :SYM], [:SYM, :SYM], [:SYM, :SYM]], got [[:SYM, :SYM], [:SYM, :SYM], [:SYM, :SYM], [:SYM, :SYM], [:SYM, : ...[clipped]` |
| 1 | `FAILED expected [[:SYM, :*], [:SYM, :**], [:SYM, :&]], got [[:SYM, :SYM], [:SYM, :&]]` |
| 1 | `FAILED expected [[#<OBJ>, #<OBJ>], [#<OBJ>, #<OBJ>], [#<OBJ>, #<OBJ>]], got []` |
| 1 | `FAILED expected [["S", "S", "S"], ["S", "S"]], got []` |
| 1 | `FAILED expected [N], got [N]` |
| 1 | `FAILED expected [N, nil, nil, N, nil, nil], got []` |
| 1 | `FAILED expected [N, N], got [N, "S", N, "S", "S", nil, nil, nil]` |
| 1 | `FAILED expected [N, N, [N], {x: N}, N, {}], got [[N, N, N, {x: N}], N, [], nil, N, {}]` |
| 1 | `FAILED expected [N, N, N], got []` |
| 1 | `FAILED expected [N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, ...[clipped]` |
| 1 | `FAILED expected [CoreClassSpecs::Inherited::D, #<OBJ>], got [#<OBJ>]` |
| 1 | `FAILED expected [:SYM], got [:SYM, :SYM]` |
| 1 | `FAILED expected [:SYM, N, :SYM, N, :SYM, N, :SYM, N], got []` |
| 1 | `FAILED expected [:SYM, :SYM], got []` |
| 1 | `FAILED expected [:SYM, :SYM], got [:SYM]` |
| 1 | `FAILED expected [:SYM, :SYM, :SYM, :SYM, :SYM], got []` |
| 1 | `FAILED expected [:SYM, :SYM, :SYM, :SYM, :SYM, :SYM], got [:SYM, :SYM, :SYM, :SYM, :SYM]` |
| 1 | `FAILED expected [#<OBJ>], got []` |
| 1 | `FAILED expected [#<OBJ>, ModuleSpecs::Nesting, ModuleSpecs], got [#<OBJ>, ModuleSpecs::Nesting, ModuleSpecs]` |
| 1 | `FAILED expected ["S"], got ["S"]` |
| 1 | `FAILED expected ["S"], got ["S", "S"]` |
| 1 | `FAILED expected ["S", "S"], got []` |
| 1 | `FAILED expected ["S", "S"], got ["S"]` |
| 1 | `FAILED expected ["S", "S", "S", "S"], got []` |
| 1 | `FAILED expected ["S", "S", "S", "S"], got ["S", "S", "S", "S"]` |
| 1 | `FAILED expected ["S", "S", "S", "S", "S"], got ["S", "S", "S", "S", "S"]` |
| 1 | `FAILED expected ["S", "S", "S", "S", "S", "S"], got [#<OBJ>>, #<Enumerator::Lazy: #<Enumerator: "S":SYM ...[clipped]` |
| 1 | `FAILED expected ["S", "S", "S", "S", "S", "S", "S", "S"], got ["S", "S", "S", "S"]` |
| 1 | `FAILED expected ["S", "S", "S", "S", "S", "S", "S", "S", "S", "S", "S", "su ...[clipped]` |
| 1 | `FAILED expected ["S", "S", "S", "S", "S", "S", "S", "S", "S", "S", "S", "S", "sp ...[clipped]` |
| 1 | `FAILED expected ["S", "S", "S", "S", "S", "S", "S", "S", "S", "S", "S", "S", "S", "S", "subdir_tw ...[clipped]` |
| 1 | `FAILED expected [" def foo` |
| 1 | `FAILED expected SystemCallError to be raised` |
| 1 | `FAILED expected StringScanner::Error to be raised` |
| 1 | `FAILED expected RuntimeError to be raised` |
| 1 | `FAILED expected NNN N:N:N UTC, got NNN N:N:N UTC` |
| 1 | `FAILED expected N, got Infinity` |
| 1 | `FAILED expected IndexError to be raised` |
| 1 | `FAILED expected Errno::EINVAL to be raised` |
| 1 | `FAILED expected :SYM, got :SYM` |
| 1 | `FAILED expected (N/N), got (N/N)` |
| 1 | `FAILED expected #<UnboundMethod: Zlib::GzipReader#pos() TMPDIR got #<UnboundMethod: Zlib::GzipReader#tell() TMPDIR` |
| 1 | `FAILED expected #<UnboundMethod: Zlib::GzipReader#eof?() TMPDIR got #<UnboundMethod: Zlib::GzipReader#eof() TMPDIR` |
| 1 | `FAILED expected #<UnboundMethod: Date#xmlschema() TMPDIR got #<UnboundMethod: Date#isoN() TMPDIR` |
| 1 | `FAILED expected #<UnboundMethod: Date#second() TMPDIR got #<UnboundMethod: Date#sec() TMPDIR` |
| 1 | `FAILED expected #<UnboundMethod: Date#minute() TMPDIR got #<UnboundMethod: Date#min() TMPDIR` |
| 1 | `FAILED expected #<OBJ>, got #<Digest::SHAN:NxA ...[clipped]` |
| 1 | `FAILED expected #<OBJ>, got "S"` |
| 1 | `FAILED expected #<Method: Time.rfcN(str) TMPDIR got #<Method: Time.rfcN(str) TMPDIR` |
| 1 | `FAILED expected #<Method: Date.valid_date?(y, m, d, _start=...) TMPDIR got #<Method: Date.valid_civil?(y, m, d, _start=...) TMPDIR` |
| 1 | `FAILED expected "x\xNCc\xN` |
| 1 | `FAILED expected "x\xNCN\xN` |
| 1 | `FAILED expected "\xDN\xNC\xDN\xNF\xBN\xEN\xN` |
| 1 | `FAILED expected "TMPDIR got nil` |
| 1 | `FAILED expected "TMPDIR` |
| 1 | `FAILED expected "S"km\"S", got "S"km\"S"` |
| 1 | `FAILED expected "S"abcde\"S", got "S"` |
| 1 | `FAILED expected "S"\uN\"S", got "S"` |
| 1 | `FAILED expected "S"This ...\"S", got "S"` |
| 1 | `FAILED expected "S", got N` |
| 1 | `FAILED expected "S", got "v\xNN{` |
| 1 | `FAILED expected "S", got "eeNbNddNafNeNaaNaNeeNcNaeNfNeNfNaNdNeNdbN ...[clipped]` |
| 1 | `FAILED expected "S", got "\xNF\xN\xDN\xN\xNL}e\xNA/\xEA\xAN\xCNZ\xDN\xAN\xBFO\e+\xN,\xDN]l\xBN\xFN` |
| 1 | `FAILED expected "S", got "\xEE&\xBN\xDDJ\xFN\xENI\xAA\x ...[clipped]` |
| 1 | `FAILED expected "S", got "#<Digest::SHAN:NxADDR @buf= ...[clipped]` |
| 1 | `FAILED expected "NMLJNI\xND$` |
| 1 | `FAILED expected "Another Test!` |
| 1 | `FAILED expected "(N&!ANF-DN` |
| 1 | `FAILED expected "` |
| 1 | `FAILED calls respond_to_missing? with true to include private methods: #respond_to_missing? received with unexpected arguments` |
| 1 | `ERROR fatal` |
| 1 | `ERROR SignalException` |
| 1 | `ERROR RuntimeError` |
| 1 | `ERROR RangeError` |
| 1 | `ERROR FrozenError` |
| 1 | `ERROR Encoding::UndefinedConversionError` |

<details><summary>the same rows by exact cause (top 40)</summary>

| files | cause |
|---|---|
| 19 | `FAILED: expected ArgumentError to be raised` |
| 15 | `FAILED: expected TypeError to be raised` |
| 9 | `FAILED: raised NoMethodError, expected TypeError` |
| 9 | `*.rb:N: warning: already initialized constant Digest::M32` |
| 8 | `FAILED: expected NoMethodError to be raised` |
| 5 | `FAILED: expected IOError to be raised` |
| 4 | `FAILED: raised NoMethodError, expected ArgumentError` |
| 4 | `FAILED: is a private method: expected truthy from #include?` |
| 4 | `FAILED: expected SyntaxError to be raised` |
| 4 | `FAILED: expected RangeError to be raised` |
| 4 | `FAILED: expected NameError to be raised` |
| 3 | `FAILED: returns the day of the reform if date falls within calendar reform: expected #<Date: 1582-10-04>, got #<Date: 1582-10-09>` |
| 3 | `FAILED: is not defined: expected falsy from #include?` |
| 3 | `FAILED: is a public method: expected truthy from #include?` |
| 3 | `FAILED: includes Enumerable: expected true, got false` |
| 3 | `FAILED: expected Math::DomainError to be raised` |
| 2 | `pass=7 fail=0 err=0` |
| 2 | `TMPDIR` |
| 2 | `FAILED: uses the passed Object as the StringIO backend: expected to be identical` |
| 2 | `FAILED: round-trips a string through pack and unpack: expected ["hello"], got []` |
| 2 | `FAILED: returns a US_ASCII encoded string: expected #<Encoding:US-ASCII>, got #<Encoding:BINARY (ASCII-8BIT)>` |
| 2 | `FAILED: raised StandardError, expected FrozenError` |
| 2 | `FAILED: raised NoMethodError, expected FrozenError` |
| 2 | `FAILED: keeps size: expected 100, got nil` |
| 2 | `FAILED: is delegated: expected :foo, got false` |
| 2 | `FAILED: includes all public methods of the delegated class: expected truthy from #include?` |
| 2 | `FAILED: expected ThreadError to be raised` |
| 2 | `FAILED: duplicates the range: expected not to be identical` |
| 2 | `FAILED: converts a key that is neither String nor Symbol with #to_str: expected true, got false` |
| 2 | `FAILED: converts a key that is neither String nor Symbol with #to_str: expected 49, got nil` |
| 2 | `FAILED: converts a key that is neither String nor Symbol with #to_str: expected 1, got nil` |
| 2 | `FAILED: calls the enclosed object's rewind method if one exists: expected to receive #rewind` |
| 2 | `FAILED: calls the block with initial values when yield with multiple arguments: expected [nil, 0, 0, 0, 0, nil, :default_arg, [], [], [0], [0, 1], [0, 1, 2]], got [nil, 0, [0, 1], [0, 1, 2], [0, 1, 2], nil, :default_arg, [], [], [0], [0, 1] ...[clipped]` |
| 2 | `FAILED: calls supplied block if the key is not found: expected 5, got nil` |
| 2 | `FAILED: calls #to_str to convert an Object to a String: expected "abcdef", got ""` |
| 2 | `ERROR: for a child that exited normally returns true: SystemExit` |
| 2 | `ERROR: Encoding::UndefinedConversionError#source_encoding_name returns a String: NoMethodError` |
| 1 | `pass=6 fail=0 err=0` |
| 1 | `pass=3 fail=0 err=0` |
| 1 | `pass=24 fail=1 err=0` |

</details>

## The absent names

Files whose FIRST divergence is NoMethodError or NameError, keyed by the
method the spec file is named for. Not every row is a missing method --
a spec can raise NoMethodError from a helper -- but most are, and the
class column says where the weight sits.

| class | absent names (from the spec filenames) |
|---|---|
| buffer (21) | `and empty external for free initialize internal locked map mapped not null or private readonly resize shared string transfer valid xor` |
| process (15) | `argv0 clock_getres detach egid euid gid kill last_status spawn times uid wait2 wait waitall warmup` |
| io (15) | `binmode close_read close close_write copy_stream fsync pid popen pread pwrite readbyte stat sysopen sysread syswrite` |
| stringscanner (14) | `append beginning_of_line bol charpos concat fixed_anchor matched must_C_version named_captures pos rest scan_full terminate values_at` |
| module (14) | `alias_method const_defined const_missing const_set const_source_location deprecate_constant included initialize module_exec name public_instance_method refine remove_class_variable remove_const` |
| file (13) | `absolute_path atime chmod constants ctime flock initialize mtime new rename reopen truncate umask` |
| converter (12) | `asciicompat_encoding convert convpath destination_encoding finish last_error new primitive_errinfo putback replacement search_convpath source_encoding` |
| thread (10) | `backtrace_locations backtrace current each_caller_location fetch handle_interrupt ignore_deadlock keys pending_interrupt thread_variables` |
| time (9) | `_dump at ceil deconstruct_keys dup floor round to_date to_datetime` |
| kernel (9) | `autoload binding chomp chop open select singleton_class system test` |
| fiber (9) | `alive blocking current kill new resume storage transfer yield` |
| invalid_byte_sequence_error (7) | `destination_encoding_name destination_encoding error_bytes incomplete_input readagain_bytes source_encoding_name source_encoding` |
| gzipreader (7) | `each_byte each_char each_line each getc mtime rewind` |
| gc (7) | `auto_compact config count garbage_collect measure_total_time stat total_time` |
| argf (7) | `argv each eof path tell to_a to_i` |
| enumerator (6) | `each each_with_object feed initialize new product` |
| encoding (6) | `aliases compatible find list name_list names` |
| dir (6) | `delete each_child empty fileno foreach mktmpdir` |
| yaml (5) | `dump load_file parse_file parse to_yaml` |
| undefined_conversion_error (5) | `destination_encoding_name destination_encoding error_char source_encoding_name source_encoding` |
| profiler (5) | `disable enable enabled result total_time` |
| tms (4) | `cstime cutime stime utime` |
| stat (4) | `comparison gid mode new` |
| sha512 (4) | `digest_bang hexdigest_bang length size` |
| sha384 (4) | `digest_bang hexdigest_bang length size` |
| sha256 (4) | `digest_bang hexdigest_bang length size` |
| md5 (4) | `digest_bang hexdigest_bang length size` |
| gzipfile (4) | `close closed comment orig_name` |
| date (4) | `constants infinity iso8601 rfc3339` |
| binding (4) | `implicit_parameter_defined implicit_parameter_get implicit_parameters source_location` |
| zstream (3) | `avail_in avail_out data_type` |
| securerandom (3) | `base64 hex random_bytes` |
| regexp (3) | `timeout escapes subexpression_call` |
| pathname (3) | `empty glob realdirpath` |
| objectspace (3) | `_id2ref each_object garbage_collect` |
| gzipwriter (3) | `append mtime write` |
| warning (2) | `categories warn` |
| stringio (2) | `eof seek` |
| singleton (2) | `dump load` |
| refinement (2) | `import_methods target` |
| random (2) | `equal_value urandom` |
| openssl (2) | `fixed_length_secure_compare secure_compare` |
| io-wait (2) | `wait_readable wait_writable` |
| inflate (2) | `finish inflate` |
| etc (2) | `sysconfdir uname` |
| deflate (2) | `params set_dictionary` |
| datetime (2) | `new second_fraction` |
| zlib (1) | `zlib_version` |
| weakkeymap (1) | `clear` |
| unboundmethod (1) | `super_method` |
| tracepoint (1) | `trace` |
| tempfile (1) | `initialize` |
| store (1) | `verify` |
| status (1) | `wait` |
| proc (1) | `new` |
| name (1) | `parse` |
| monitor (1) | `synchronize` |
| method (1) | `super_method` |
| main (1) | `define_method` |
| location (1) | `base_label` |
| lazy (1) | `chunk` |
| language (1) | `module` |
| irb (1) | `irb` |
| instance (1) | `update` |
| enumerable (1) | `to_h` |
| delegate_class (1) | `instance_method` |
| class (1) | `allocate` |
| basicobject (1) | `not_equal` |

_Generated by `mspec/causes.sh`._

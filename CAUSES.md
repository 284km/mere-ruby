# mere-ruby — what the gap is made of

The records in `SPEC_STATUS.md` and `mspec/tags/`, grouped by CAUSE rather
than by group. A count is a number of spec FILES. The text is the first line
where mere-ruby and ruby disagree (DIFF) or the message it aborted with
(CRASH), with paths and addresses masked.

**KIND** masks the values and keeps the shape -- this is the column that says
what to work on. **CAUSE** is the line as recorded, for reproducing one.

Regenerate with `./mspec/causes.sh` (reads `mspec/tags/`, no sweep).

Classified: 526 files.

## DIFF — 526 files, 117 kinds

| files | kind |
|---|---|
| 186 | `ERROR NoMethodError` |
| 46 | `ERROR NameError` |
| 20 | `FAILED expected "S", got "S"` |
| 19 | `FAILED expected N, got N` |
| 17 | `FAILED expected #<OBJ>, got #<OBJ>` |
| 14 | `FAILED expected true, got false` |
| 11 | `FAILED expected ArgumentError to be raised` |
| 10 | `FAILED expected truthy from #include?` |
| 10 | `ERROR ArgumentError` |
| 9 | `FAILED matcher did not match #<OBJ>` |
| 9 | `FAILED expected TypeError to be raised` |
| 8 | `FAILED expected false, got true` |
| 7 | `FAILED expected to be identical` |
| 7 | `ERROR NotImplementedError` |
| 6 | `FAILED expected falsy from #include?` |
| 5 | `pass=N fail=N err=N` |
| 4 | `FAILED raised NoMethodError, expected TypeError` |
| 4 | `FAILED raised NoMethodError, expected ArgumentError` |
| 4 | `FAILED expected RangeError to be raised` |
| 4 | `FAILED expected NoMethodError to be raised` |
| 4 | `FAILED expected NameError to be raised` |
| 4 | `FAILED expected IOError to be raised` |
| 4 | `FAILED expected "S", got nil` |
| 3 | `FAILED expected not to be identical` |
| 3 | `FAILED expected false, got nil` |
| 3 | `FAILED expected [:SYM, :SYM], got nil` |
| 3 | `FAILED expected SyntaxError to be raised` |
| 3 | `FAILED expected Math::DomainError to be raised` |
| 3 | `FAILED expected :SYM, got nil` |
| 3 | `ERROR StandardError` |
| 2 | `FAILED raised StandardError, expected FrozenError` |
| 2 | `FAILED expected to receive #to_str` |
| 2 | `FAILED expected ThreadError to be raised` |
| 2 | `FAILED expected N, got nil` |
| 2 | `FAILED expected #<OBJ>, got nil` |
| 2 | `ERROR TypeError` |
| 1 | `This is experimental warning.` |
| 1 | `TMPDIR` |
| 1 | `FAILED raised TypeError, expected ArgumentError` |
| 1 | `FAILED raised NoMethodError, expected NotImplementedError` |
| 1 | `FAILED raised NoMethodError, expected LocalJumpError` |
| 1 | `FAILED raised NoMethodError, expected IOError` |
| 1 | `FAILED raised NoMethodError, expected FrozenError` |
| 1 | `FAILED raised NoMethodError, expected EOFError` |
| 1 | `FAILED raised NameError, expected ArgumentError` |
| 1 | `FAILED raised LoadError, expected NameError` |
| 1 | `FAILED raised FrozenError, expected TypeError` |
| 1 | `FAILED raised ArgumentError, expected SyntaxError` |
| 1 | `FAILED expected {...}, got {...}` |
| 1 | `FAILED expected {#<OBJ> => N}, got {}` |
| 1 | `FAILED expected truthy from #start_with?` |
| 1 | `FAILED expected true, got nil` |
| 1 | `FAILED expected to receive #to_int` |
| 1 | `FAILED expected to receive #to_a` |
| 1 | `FAILED expected to receive #rewind` |
| 1 | `FAILED expected to receive #respond_to_missing?` |
| 1 | `FAILED expected not true` |
| 1 | `FAILED expected not N` |
| 1 | `FAILED expected nil, got "S"` |
| 1 | `FAILED expected nil to match` |
| 1 | `FAILED expected a Integer, got N` |
| 1 | `FAILED expected a Enumerable, got #<OBJ>` |
| 1 | `FAILED expected [], got [N, N, N]` |
| 1 | `FAILED expected [], got [:SYM]` |
| 1 | `FAILED expected [[:SYM, :SYM], [:SYM, :SYM], [:SYM, :SYM], [:SYM, :SYM], [:SYM, :SYM], [:SYM, :SYM], [:SYM, :SYM], [:SYM, :SYM]], got [[:SYM, :SYM], [:SYM, :SYM], [:SYM, :SYM], [:SYM, :SYM], [:SYM, : ...[clipped]` |
| 1 | `FAILED expected [[:SYM, :*], [:SYM, :**], [:SYM, :&]], got [[:SYM, :SYM], [:SYM, :&]]` |
| 1 | `FAILED expected [[#<OBJ>, #<OBJ>], [#<OBJ>, #<OBJ>], [#<OBJ>, #<OBJ>]], got []` |
| 1 | `FAILED expected [["S", "S", "S"], ["S", "S"]], got []` |
| 1 | `FAILED expected [N], got [N]` |
| 1 | `FAILED expected [N, N, [N], {x: N}, N, {}], got [[N, N, N, {x: N}], N, [], nil, N, {}]` |
| 1 | `FAILED expected [N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, N, ...[clipped]` |
| 1 | `FAILED expected [CoreClassSpecs::Inherited::D, #<OBJ>], got [#<OBJ>]` |
| 1 | `FAILED expected [:SYM, :SYM], got []` |
| 1 | `FAILED expected [:SYM, :SYM], got [:SYM]` |
| 1 | `FAILED expected [:SYM, :SYM, :SYM, :SYM, :SYM], got []` |
| 1 | `FAILED expected [:SYM, :SYM, :SYM, :SYM, :SYM, :SYM], got [:SYM, :SYM, :SYM, :SYM, :SYM]` |
| 1 | `FAILED expected [#<OBJ>], got []` |
| 1 | `FAILED expected [#<OBJ>, ModuleSpecs::Nesting, ModuleSpecs], got [#<OBJ>, ModuleSpecs::Nesting, ModuleSpecs]` |
| 1 | `FAILED expected ["S", "S"], got ["S"]` |
| 1 | `FAILED expected ["S", "S", "S", "S"], got ["S", "S", "S", "S"]` |
| 1 | `FAILED expected ["S", "S", "S", "S", "S", "S", "S", "S"], got ["S", "S", "S", "S"]` |
| 1 | `FAILED expected ["S", "S", "S", "S", "S", "S", "S", "S", "S", "S", "S", "su ...[clipped]` |
| 1 | `FAILED expected ["S", "S", "S", "S", "S", "S", "S", "S", "S", "S", "S", "S", "sp ...[clipped]` |
| 1 | `FAILED expected ["S", "S", "S", "S", "S", "S", "S", "S", "S", "S", "S", "S", "S", "S", "subdir_tw ...[clipped]` |
| 1 | `FAILED expected SystemCallError to be raised` |
| 1 | `FAILED expected RuntimeError to be raised` |
| 1 | `FAILED expected N, got Infinity` |
| 1 | `FAILED expected IndexError to be raised` |
| 1 | `FAILED expected Errno::EINVAL to be raised` |
| 1 | `FAILED expected :SYM, got :SYM` |
| 1 | `FAILED expected #<UnboundMethod: StringIO#tty?() TMPDIR got #<UnboundMethod: StringIO#isatty() TMPDIR` |
| 1 | `FAILED expected #<UnboundMethod: StringIO#length() TMPDIR got #<UnboundMethod: StringIO#size() TMPDIR` |
| 1 | `FAILED expected #<UnboundMethod: StringIO#each_line(sep=...) TMPDIR got #<UnboundMethod: StringIO#each(sep=..., &block) TMPDIR` |
| 1 | `FAILED expected #<UnboundMethod: Pathname#+(other) TMPDIR got #<UnboundMethod: Pathname#/(other) TMPDIR` |
| 1 | `FAILED expected #<UnboundMethod: Dir#to_path() TMPDIR got #<UnboundMethod: Dir#path() TMPDIR` |
| 1 | `FAILED expected #<OBJ>, got #<UnboundMethod: StringIO#tell() TMPDIR` |
| 1 | `FAILED expected #<OBJ>, got "S"` |
| 1 | `FAILED expected #<Method: Time.xmlschema(str) TMPDIR got #<Method: Time.isoN(str) TMPDIR` |
| 1 | `FAILED expected #<Method: Time.rfcN(str) TMPDIR got #<Method: Time.rfcN(str) TMPDIR` |
| 1 | `FAILED expected "x\xNCN\xN` |
| 1 | `FAILED expected "TMPDIR` |
| 1 | `FAILED expected "S"km\"S", got "S"km\"S"` |
| 1 | `FAILED expected "S"abcde\"S", got "S"` |
| 1 | `FAILED expected "S"\uN\"S", got "S"` |
| 1 | `FAILED expected "S", got N` |
| 1 | `FAILED expected "S" to match` |
| 1 | `FAILED expected "NMLJNI\xND$` |
| 1 | `FAILED expected "Another Test!` |
| 1 | `FAILED expected "` |
| 1 | `FAILED calls respond_to_missing? with true to include private methods: #respond_to_missing? received with unexpected arguments` |
| 1 | `ERROR fatal` |
| 1 | `ERROR SystemStackError` |
| 1 | `ERROR SystemExit` |
| 1 | `ERROR SignalException` |
| 1 | `ERROR RuntimeError` |
| 1 | `ERROR RangeError` |
| 1 | `ERROR Errno::ENOENT` |

<details><summary>the same rows by exact cause (top 40)</summary>

| files | cause |
|---|---|
| 11 | `FAILED: expected ArgumentError to be raised` |
| 9 | `FAILED: expected TypeError to be raised` |
| 4 | `FAILED: raised NoMethodError, expected TypeError` |
| 4 | `FAILED: raised NoMethodError, expected ArgumentError` |
| 4 | `FAILED: expected RangeError to be raised` |
| 4 | `FAILED: expected NoMethodError to be raised` |
| 4 | `FAILED: expected NameError to be raised` |
| 4 | `FAILED: expected IOError to be raised` |
| 3 | `FAILED: is not defined: expected falsy from #include?` |
| 3 | `FAILED: includes Enumerable: expected true, got false` |
| 3 | `FAILED: expected SyntaxError to be raised` |
| 3 | `FAILED: expected Math::DomainError to be raised` |
| 2 | `FAILED: uses the passed Object as the StringIO backend: expected to be identical` |
| 2 | `FAILED: returns the day of the reform if date falls within calendar reform: expected #<Date: 1582-10-04>, got #<Date: 1582-10-09>` |
| 2 | `FAILED: returns a US_ASCII encoded string: expected #<Encoding:US-ASCII>, got #<Encoding:BINARY (ASCII-8BIT)>` |
| 2 | `FAILED: raised StandardError, expected FrozenError` |
| 2 | `FAILED: is a public method: expected truthy from #include?` |
| 2 | `FAILED: is a private method: expected truthy from #include?` |
| 2 | `FAILED: expected ThreadError to be raised` |
| 2 | `FAILED: duplicates the range: expected not to be identical` |
| 1 | `pass=3 fail=0 err=0` |
| 1 | `pass=24 fail=1 err=0` |
| 1 | `pass=2 fail=0 err=0` |
| 1 | `pass=19 fail=0 err=0` |
| 1 | `pass=16 fail=0 err=0` |
| 1 | `This is experimental warning.` |
| 1 | `TMPDIR` |
| 1 | `FAILED: yields each directory entry in succession: expected [".", "..", ".dotfile", ".dotsubdir", "brace", "deeply", "dir", "dir_filename_ordering", "file_one.ext", "file_two.ext", "nested", "nondotfile", "special", "subdir_one", "subdir_tw ...[clipped]` |
| 1 | `FAILED: writes the passed char before the current position: expected "A234", got "1234"` |
| 1 | `FAILED: writes the passed argument onto self: expected "just testing", got "examplejust testing"` |
| 1 | `FAILED: writes $_.to_s followed by $\ (if any) to the stream if no arguments given: expected "mockmockmock->", got ""` |
| 1 | `FAILED: wraps the lock/unlock pair in an ensure: expected true, got false` |
| 1 | `FAILED: works when creating subclasses concurrently: expected 16000, got 0` |
| 1 | `FAILED: with a relative path: expected #<Pathname:/foo>, got #<Pathname:/usr/../foo>` |
| 1 | `FAILED: will not acquire a monitor already held by another thread: expected false, got true` |
| 1 | `FAILED: warns when passing a block argument to a method that never uses it: matcher did not match #<Proc>` |
| 1 | `FAILED: warns when Integer literals are used instead of predicates: matcher did not match #<Proc>` |
| 1 | `FAILED: uses the block value instead of using the default value: matcher did not match #<Proc>` |
| 1 | `FAILED: updates $. with each yield: expected 1, got 0` |
| 1 | `FAILED: unlocks the mutex while sleeping: expected false, got true` |

</details>

## The absent names

Files whose FIRST divergence is NoMethodError or NameError, keyed by the
method the spec file is named for. Not every row is a missing method --
a spec can raise NoMethodError from a helper -- but most are, and the
class column says where the weight sits.

| class | absent names (from the spec filenames) |
|---|---|
| date (34) | `accessor add_month add asctime boat commercial constants conversions ctime deconstruct_keys downto eql gregorian_leap gregorian hash infinity iso8601 jd julian_leap julian minus_month minus ordinal plus relationship rfc3339 step strftime upto valid_civil valid_commercial valid_date valid_jd valid_ordinal` |
| time (29) | `_dump asctime at ceil ctime deconstruct_keys dup floor getgm gm gmt_offset gmt gmtime gmtoff isdst iso8601 mday mktime mon nsec round strftime subsec to_r tv_nsec tv_sec tv_usec xmlschema zone` |
| stringio (24) | `binmode close_read close_write closed_read closed closed_write each_byte each_char each_codepoint eof fsync getbyte lineno pid putc read_nonblock readbyte readchar reopen rewind seek set_encoding_by_bom ungetbyte write_nonblock` |
| file (20) | `absolute_path atime chmod constants ctime flock grpowned initialize mtime new owned pipe rename reopen setuid socket truncate umask world_readable world_writable` |
| io (19) | `binmode close_read close close_write copy_stream dup fsync pid popen pos pread pwrite readbyte stat sysopen sysread syswrite tell to_i` |
| module (14) | `alias_method const_defined const_missing const_set const_source_location deprecate_constant included initialize module_exec name public_instance_method refine remove_class_variable remove_const` |
| kernel (9) | `autoload binding chomp chop open select singleton_class system test` |
| fiber (9) | `alive blocking current kill new resume storage transfer yield` |
| gc (7) | `auto_compact config count garbage_collect measure_total_time stat total_time` |
| enumerator (7) | `each each_with_object feed initialize new product with_object` |
| encoding (7) | `aliases compatible find list name_list names to_s` |
| argf (7) | `argv each eof path tell to_a to_i` |
| dir (6) | `delete empty fileno foreach pos tell` |
| yaml (5) | `dump load_file parse_file parse to_yaml` |
| pathname (4) | `case_compare empty glob realdirpath` |
| binding (4) | `implicit_parameter_defined implicit_parameter_get implicit_parameters source_location` |
| securerandom (3) | `base64 hex random_bytes` |
| objectspace (3) | `_id2ref each_object garbage_collect` |
| warning (2) | `categories warn` |
| refinement (2) | `import_methods target` |
| random (2) | `equal_value urandom` |
| filetest (2) | `grpowned socket` |
| etc (2) | `sysconfdir uname` |
| zlib (1) | `zlib_version` |
| unboundmethod (1) | `super_method` |
| tempfile (1) | `initialize` |
| regexp (1) | `timeout` |
| proc (1) | `new` |
| monitor (1) | `synchronize` |
| method (1) | `super_method` |
| main (1) | `define_method` |
| language (1) | `module` |
| enumerable (1) | `to_h` |
| class (1) | `allocate` |
| basicobject (1) | `not_equal` |

_Generated by `mspec/causes.sh`._

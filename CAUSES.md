# mere-ruby — what the gap is made of

The records in `SPEC_STATUS.md` and `mspec/tags/`, grouped by CAUSE rather
than by group. A count is a number of spec FILES. The text is the first line
where mere-ruby and ruby disagree (DIFF) or the message it aborted with
(CRASH), with paths and addresses masked.

**KIND** masks the values and keeps the shape -- this is the column that says
what to work on. **CAUSE** is the line as recorded, for reproducing one.

Regenerate with `./mspec/causes.sh` (reads `mspec/tags/`, no sweep).

Classified: 186 files.

## CRASH — 3 files, 2 kinds

| files | kind |
|---|---|
| 2 | `(unclassified: swept before causes were recorded)` |
| 1 | `fail: mere-ruby: (exception re-raised past all rescues)` |

<details><summary>the same rows by exact cause (top 40)</summary>

| files | cause |
|---|---|
| 2 | `(unclassified)` |
| 1 | `fail: mere-ruby: (exception re-raised past all rescues)` |

</details>

## DIFF — 183 files, 88 kinds

| files | kind |
|---|---|
| 12 | `pass=N fail=N err=N` |
| 10 | `ERROR NameError` |
| 9 | `FAILED expected "S", got "S"` |
| 9 | `ERROR NoMethodError` |
| 7 | `FAILED expected "S"TMPDIR` |
| 6 | `FAILED expected [:@ivar], got []` |
| 6 | `FAILED expected N, got N` |
| 5 | `FAILED matcher did not match #<OBJ>` |
| 5 | `FAILED expected truthy from #include?` |
| 5 | `FAILED expected true, got false` |
| 4 | `ERROR TypeError` |
| 4 | `ERROR SyntaxError` |
| 4 | `ERROR NotImplementedError` |
| 4 | `ERROR ArgumentError` |
| 3 | `FAILED expected not to be identical` |
| 3 | `FAILED expected N, got nil` |
| 3 | `ERROR LoadError` |
| 3 | `ERROR Encoding::UndefinedConversionError` |
| 2 | `FAILED expected truthy from #start_with?` |
| 2 | `FAILED expected truthy from #signaled?` |
| 2 | `FAILED expected truthy from #<` |
| 2 | `FAILED expected not N` |
| 2 | `FAILED expected ["finalized` |
| 2 | `FAILED expected TypeError "S" to be raised` |
| 2 | `FAILED expected #<OBJ>, got #<OBJ>` |
| 2 | `FAILED expected "S" to match` |
| 2 | `ERROR FrozenError` |
| 2 | `ERROR Errno::ENOENT` |
| 2 | `(tallies differ, lines identical)` |
| 1 | `fail: mere-ruby: (ruby exception raised)` |
| 1 | `FAILED matcher did not match "--- !ruby/object:YAMLSpecs::Example` |
| 1 | `FAILED expected truthy from #exist?` |
| 1 | `FAILED expected to receive #to_a` |
| 1 | `FAILED expected to receive #tmpdir` |
| 1 | `FAILED expected to be identical` |
| 1 | `FAILED expected nil, got false` |
| 1 | `FAILED expected nil, got N` |
| 1 | `FAILED expected falsy from #include?` |
| 1 | `FAILED expected false, got true` |
| 1 | `FAILED expected [[:SYM, :SYM], [:SYM, :SYM], [:SYM, :SYM]], got nil` |
| 1 | `FAILED expected [[:SYM, :SYM], [:SYM, :SYM], [:SYM, :SYM], [:SYM, :SYM], [:SYM, :SYM], [:SYM, :SYM], [:SYM, :SYM], [:SYM, :SYM]], got [[:SYM, :SYM], [:SYM, :SYM], [:SYM, :SYM], [:SYM, :SYM], [:SYM, : ...[clipped]` |
| 1 | `FAILED expected [N], got [N]` |
| 1 | `FAILED expected [N, nil, nil, N, nil, nil], got [N, N, N, N]` |
| 1 | `FAILED expected [N, N], got [[N, N], [N, N]]` |
| 1 | `FAILED expected [N, N, N, N], got N` |
| 1 | `FAILED expected [:SYM, :SYM], got []` |
| 1 | `FAILED expected [:SYM, :SYM, :SYM, :SYM, :SYM], got [:SYM, :SYM]` |
| 1 | `FAILED expected [:SYM, :SYM, :SYM, :SYM, :SYM, :SYM], got [:SYM, :SYM, :SYM, :SYM, :SYM]` |
| 1 | `FAILED expected ["S"], got ["S"]` |
| 1 | `FAILED expected ["S"./file_fixture.rb"]` |
| 1 | `FAILED expected ["S", "S"], got ["S", "S"]` |
| 1 | `FAILED expected ["S", "S", "S", "TMPDIR 'Object#__mspec_ ...[clipped]` |
| 1 | `FAILED expected ["S", "S", "S", "S"], got ["S", "S", "S", "S"]` |
| 1 | `FAILED expected [" def foo` |
| 1 | `FAILED expected TypeError to be raised` |
| 1 | `FAILED expected TypeError /can't convert Object into an exact number/ to be raised` |
| 1 | `FAILED expected SyntaxError to be raised` |
| 1 | `FAILED expected SyntaxError /dynamic constant assignment/ to be raised` |
| 1 | `FAILED expected SyntaxError /anonymous rest parameter is also used within block/ to be raised` |
| 1 | `FAILED expected RuntimeError "S" to be raised` |
| 1 | `FAILED expected NoMethodError /protected method ['S' called/ to be raised` |
| 1 | `FAILED expected IndexError to be raised` |
| 1 | `FAILED expected ArgumentError /Can't import method which is not defined with Ruby code: Zlib#*/ to be raised` |
| 1 | `FAILED expected :+, got nil` |
| 1 | `FAILED expected (N/N), got (N/N)` |
| 1 | `FAILED expected #<OBJ>, got nil` |
| 1 | `FAILED expected "x\xNCc\xN` |
| 1 | `FAILED expected "x\xNCN\xN` |
| 1 | `FAILED expected "true` |
| 1 | `FAILED expected "top` |
| 1 | `FAILED expected "current fiber ensure` |
| 1 | `FAILED expected "S"constant\"S", got "S"` |
| 1 | `FAILED expected "S"\uN\"S", got "S"` |
| 1 | `FAILED expected "S", got nil` |
| 1 | `FAILED expected "NMLJNI\xND$` |
| 1 | `FAILED expected "Kernel#warn spec edge case` |
| 1 | `FAILED expected "#<TracePoint:SYM 'S' TMPDIR to match` |
| 1 | `FAILED expected "` |
| 1 | `ERROR RuntimeError` |
| 1 | `ERROR Errno::ENOTCONN` |
| 1 | `ERROR Errno::EINVAL` |
| 1 | `<internal:SYM>:N:SYM 'S': No such file or directory @ rb_sysopen - (Errno::ENOENT)` |
| 1 | `<internal:SYM>:N:SYM 'S': Broken pipe (Errno::EPIPE)` |
| 1 | `<internal:SYM>:N:SYM 'S': Bad file descriptor (Errno::EBADF)` |
| 1 | `/privateTMPDIR 'S': undefined method 'S' for an instance of Binding (NoMethodError)` |
| 1 | `/privateTMPDIR 'S': method 'S' not defined in BasicObject (NameError)` |
| 1 | `-e:N:SYM 'S': super: no superclass method 'S' for an instance of Integer (NoMethodError)` |
| 1 | `#<OBJ> terminated with exception (report_on_exception is true):` |

<details><summary>the same rows by exact cause (top 40)</summary>

| files | cause |
|---|---|
| 6 | `FAILED: copies instance variables: expected [:@ivar], got []` |
| 2 | `pass=0 fail=0 err=0` |
| 2 | `FAILED: sets the first value to the path of the file in which the method was defined: expected "/privateTMPDIR got "TMPDIR` |
| 2 | `FAILED: runs handlers even if the main script fails to parse: expected truthy from #include?` |
| 2 | `FAILED: is a public method only when -n is passed: expected true, got false` |
| 2 | `FAILED: expected not 0` |
| 2 | `FAILED: duplicates the range: expected not to be identical` |
| 2 | `FAILED: copies the finalizer: expected ["finalized` |
| 2 | `(tallies differ, lines identical)` |
| 1 | `pass=911 fail=0 err=0` |
| 1 | `pass=7 fail=0 err=0` |
| 1 | `pass=5 fail=0 err=0` |
| 1 | `pass=46 fail=0 err=0` |
| 1 | `pass=29 fail=1 err=0` |
| 1 | `pass=221 fail=0 err=0` |
| 1 | `pass=21 fail=0 err=0` |
| 1 | `pass=17 fail=0 err=0` |
| 1 | `pass=16 fail=0 err=0` |
| 1 | `pass=12 fail=0 err=0` |
| 1 | `fail: mere-ruby: (ruby exception raised)` |
| 1 | `FAILED: yields the first value to a single-argument block: expected [1, 3], got [[1, 2], [3, 4]]` |
| 1 | `FAILED: with \|\|= do not reassign: expected 20, got 10` |
| 1 | `FAILED: with ensure on the root fiber: expected "current fiber ensure` |
| 1 | `FAILED: with a boolean argument emits a warning when $VERBOSE is true: matcher did not match #<Proc>` |
| 1 | `FAILED: warns when passing a block argument to a method that never uses it: matcher did not match #<Proc>` |
| 1 | `FAILED: tracks microseconds: expected 123456, got 123455` |
| 1 | `FAILED: traces all the events triggered in specified location: expected [:b_call, :b_return, :call, :line, :return], got [:call, :return]` |
| 1 | `FAILED: supports /n (No encoding): expected ["\xC3"], got ["\xC3\xA9"]` |
| 1 | `FAILED: shows the metaclass and the owner for a Module instance method retrieved from a class: expected truthy from #start_with?` |
| 1 | `FAILED: shows the backtrace and has a signaled exit status: expected 2, got nil` |
| 1 | `FAILED: sets visibility to private when method name is :initialize: expected truthy from #include?` |
| 1 | `FAILED: sets the permissions on the tempfile to 0600: expected 33152, got 33188` |
| 1 | `FAILED: sets the first value to the path of the file in which the proc was defined: expected "/privateTMPDIR got "TMPDIR` |
| 1 | `FAILED: sets regexp matches in the caller: expected ["w", "a", "w", "a"], got ["a", "a", "a", "a"]` |
| 1 | `FAILED: runs after at_exit: expected 9, got nil` |
| 1 | `FAILED: returns true: expected true, got false` |
| 1 | `FAILED: returns the signal: expected 15, got nil` |
| 1 | `FAILED: returns the real name of the directory containing the currently-executing file: expected "/privateTMPDIR got "TMPDIR` |
| 1 | `FAILED: returns the parameters of block: expected [[:opt, :x], [:opt, :y], [:opt, :z]], got nil` |
| 1 | `FAILED: returns the file path that raised an exception: expected "/privateTMPDIR got "TMPDIR` |

</details>

## The absent names

Files whose FIRST divergence is NoMethodError or NameError, keyed by the
method the spec file is named for. Not every row is a missing method --
a spec can raise NoMethodError from a helper -- but most are, and the
class column says where the weight sits.

| class | absent names (from the spec filenames) |
|---|---|
| process (4) | `_fork daemon fork set_proctitle` |
| regexp (2) | `timeout subexpression_call` |
| kernel (2) | `binding instance_variable_get` |
| unboundmethod (1) | `equal_value` |
| time (1) | `dup` |
| thread (1) | `native_thread_id` |
| store (1) | `verify` |
| proc (1) | `new` |
| name (1) | `parse` |
| location (1) | `label` |
| language (1) | `constants` |
| kdf (1) | `pbkdf2_hmac` |
| exception (1) | `receiver` |
| basicobject (1) | `instance_exec` |

_Generated by `mspec/causes.sh`._

# mere-ruby — the core-class names it does not answer

The reference ruby's own lists (`instance_methods(false)`, Kernel's private
instance methods, each class's singleton methods) called on a sample receiver
under mere-ruby. The LIST comes from ruby, so the reference version decides how
many names there are -- pin it the way every other gate does, or the total
moves and the count reads as movement in mere-ruby:

    . ./tools/ref_ruby.sh
    ruby tools/missing_names.rb list > /tmp/names.txt
    ./mere-ruby tools/missing_names.rb probe /tmp/names.txt

Every name is asked twice, because the two spellings are two questions:
`recv.name` as a program writes it, and `recv.__send__(:name)` through the
dispatcher; each with no argument, then with one. Only "undefined method"
counts. **ABSENT** is neither spelling -- a name to implement. **SEND-ONLY**
is a name the sender cannot reach though the direct call can, which is a
dispatcher gap rather than a missing method.

Asking only one of the two is how the first version of this file reported
`Math.log` and `Time#strftime` as dispatcher gaps when they are simply absent.

Read a bucket before believing it. This is an upper bound: a method that
rejects a wrong-typed argument with NoMethodError is counted, and the probe
runs at the top level, so the Kernel names that read the current method frame
(`__method__`, `block_given?`, ...) are counted too. The `name=` writers under
SEND-ONLY are the probe's own artifact -- `eval("recv.name=")` is not a call.

What it is good for is the shape: which classes are thin, and whether a day's
work moved the number.

```
ABSENT: 185 of 1413 names
  IO (43): advise autoclose? binmode binmode? close_on_exec? close_read close_write copy_stream eof eof? fcntl fdatasync for_fd fsync ioctl lineno open pid popen pos pread printf pwrite read_nonblock reopen rewind seek set_encoding_by_bom stat sysopen sysseek syswrite tell timeout to_i to_io try_convert ungetbyte ungetc wait_priority wait_readable wait_writable write_nonblock
  File (32): absolute_path? atime birthtime blockdev? chardev? chmod chown ctime flock ftype grpowned? lchmod lchown link lstat lutime mkfifo mtime owned? pipe? readlink rename setgid? setuid? socket? stat sticky? truncate umask utime world_readable? world_writable?
  Process (25): _fork argv0 clock_getres egid euid getpgid getpgrp getpriority getrlimit getsid gid groups initgroups last_status maxgroups setpgid setpgrp setpriority setproctitle setrlimit setsid uid waitall waitpid2 warmup
  Kernel (24): !~ === __callee__ __dir__ __method__ autoload autoload? block_given? define_singleton_method format gem gem_original_require global_variables lambda load local_variables open printf proc singleton_method sprintf test then yield_self
  Dir (13): chroot close each_child empty? fchdir fileno for_fd foreach pos rewind seek tell to_path
  GC (13): auto_compact compact config count garbage_collect latest_compact_info latest_gc_info measure_total_time stat stat_heap total_time verify_compaction_references verify_internal_consistency
  Thread (10): add_trace_func backtrace backtrace_locations each_caller_location handle_interrupt ignore_deadlock keys native_thread_id pending_interrupt? thread_variables
  ObjectSpace (6): _id2ref count_objects define_finalizer each_object garbage_collect undefine_finalizer
  Module (5): class_exec const_source_location define_method module_exec used_modules
  Encoding (5): _dump _load aliases compatible? name_list
  Time (4): ceil floor iso8601 xmlschema
  Enumerator (2): produce product
  Random (2): seed urandom
  Exception (1): exception

SEND-ONLY: 17 of 1413 names
  Process (6): egid= euid= gid= groups= maxgroups= uid=
  IO (5): autoclose= close_on_exec= lineno= pos= timeout=
  Kernel (2): public_send send
  GC (2): auto_compact= measure_total_time=
  Dir (1): pos=
  Thread (1): ignore_deadlock=
```

2026-09-19: **185 ABSENT of 1413**, same reference (4.0.6) and the same binary
as the record above. The drop from 222 is three arcs and one door: File and Dir
gained the predicates and the class methods their groups asked for (empty?,
identical?, the _real? spellings, each_child, foreach); Module gained the ones
its own reflection lists name (included_modules, public_class_method,
public_instance_method, protected_instance_methods, refinements,
set_temporary_name, undefined_instance_methods, nesting); Class gained
subclasses and attached_object; and ⚠ SEVEN Kernel names were never absent at
all -- `obj.__send__(:rand)` could not reach Kernel's private instance methods,
though writing `rand` bare has always worked. `send` bypasses privacy, so the
probe is right to ask that way; the door it asked through had not been told.
Twenty-four of Kernel's thirty-one remain, and reading the bucket says they
are FOUR different gaps and not one: twelve are unimplemented, eight more are
the same door (bare works, `send` does not), two are syntax rather than
methods (`!~`, `===`), and two are counted only because the probe calls them
without a block (`then`, `yield_self`).
[`KNOWN_GAPS.md`](KNOWN_GAPS.md) lists them by name.

2026-09-08: **222 ABSENT of 1413**, same reference (4.0.6) and the same binary
as that day's spec rows. The one that went is `Kernel#respond_to_missing?`: it was
consulted by the conversion protocol all along and had no definition of its own, so
an override had nowhere to `super` to and a plain call reported the method missing
where ruby says it is private.

2026-09-06 (third): **223 ABSENT of 1413**. `Array#fetch_values`, `Proc#binding`
and `Method#super_method` landed with the streaming Enumerable; the number
barely moves because the names this file counts are not where that work was.

2026-09-06 (later): **224 ABSENT of 1413**, same reference and the same binary
as that day's other rows. The forty-two that went are one arc's worth of
surface: Regexp's class methods and predicates (`casefold?`,
`fixed_encoding?`, `.try_convert`, `.timeout`, `.linear_time?`), the Errno
family (every name the platform has, each with its number), Kernel's
`#then` / `#yield_self`, Enumerable's `#chunk` and the four grouping names,
and the exception readers (`#errno`, `#reason`, `#tag`, `#value`).

2026-09-06: **266 ABSENT of 1413**, same reference (4.0.6), same binary as the
day's other rows. The sixteen that went are the MatchData, Method, Regexp and
Integer names the last two days added (`MatchData#==`, `#byteoffset`,
`#deconstruct`, `#match`; `Method#<<`, `#>>`, `#curry`; `Regexp#named_captures`,
`#names`; `Integer#ceildiv`, `.try_convert`, and their neighbours), plus
`Struct#[]=` leaving SEND-ONLY: this file had not been re-measured since they
landed. Nothing was removed from mere-ruby to make the number fall.

2026-09-05: 282 ABSENT of 1413, against ruby **4.0.6** (the reference moved; see
tools/ref_ruby.sh). The denominator grew by the ten names 4.0 added -- Array#find,
#detect and #rfind as Array's own, Kernel#Pathname and Kernel.Pathname,
Kernel#instance_variables_to_inspect, Math.log1p and .expm1, Method#box,
Range#to_set -- and none of the ten is absent. The numerator fell by six that
this file had not been re-measured for since 232c169 (IO#external_encoding,
#internal_encoding, #set_encoding, Range#overlap?, Symbol#id2name, #name):
the row before this one was measured on an older binary. Pinned to 4.0.6 from
here on.

2026-09-04 (later): 288 ABSENT of 1403. The count went UP by ten and nothing
regressed: the earlier run's list had 1389 names because it was taken from a
different ruby. This file's numerator and denominator are both measured, and
only the denominator is ruby's -- so a row is comparable with the one above it
only when the reference is the same. Pinned to 3.4.9 from here on (4.0.6 above).

2026-09-04: 298 -> 278 ABSENT. Math is libm's now, through `extern fn` -- the
identities that derive it from the builtins are exact in real arithmetic and
wrong in the last bit, which this repository's standard counts as wrong.

2026-09-03: 339 ABSENT. Operators called in method form (`"s".==("t")`,
`[1].+([2])`, `5.~`) were every one a NoMethodError -- they live in eval_e's
EBin arm and the dispatcher never looked there -- and `x.===(y)` was worse:
`is_setter_name` counted `===` as an attribute writer, so it assigned to
`x.==` and answered the argument. Both fixed; 41 names went with them.

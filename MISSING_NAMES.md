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
ABSENT: 282 of 1413 names
  IO (44): advise autoclose? binmode binmode? close_on_exec? close_read close_write copy_stream eof eof? fcntl fdatasync for_fd foreach fsync ioctl lineno open pid popen pos pread printf pwrite read_nonblock reopen rewind seek set_encoding_by_bom stat sysopen sysseek syswrite tell timeout to_i to_io try_convert ungetbyte ungetc wait_priority wait_readable wait_writable write_nonblock
  File (39): absolute_path? atime birthtime blockdev? chardev? chmod chown ctime empty? executable_real? flock ftype grpowned? identical? lchmod lchown link lstat lutime mkfifo mtime owned? pipe? readable_real? readlink rename setgid? setuid? socket? stat sticky? symlink truncate umask utime world_readable? world_writable? writable_real? zero?
  Kernel (32): !~ === __callee__ __dir__ __method__ autoload autoload? block_given? caller caller_locations define_singleton_method format gem gem_original_require global_variables iterator? lambda load local_variables open printf proc rand respond_to_missing? set_trace_func singleton_method sprintf test then trace_var untrace_var yield_self
  Time (31): asctime ceil ctime deconstruct_keys dst? floor friday? getgm gmt? gmt_offset gmtime gmtoff isdst iso8601 monday? nsec saturday? strftime subsec sunday? thursday? to_a to_r tuesday? tv_nsec tv_sec tv_usec utc_offset wednesday? xmlschema zone
  Process (25): _fork argv0 clock_getres egid euid getpgid getpgrp getpriority getrlimit getsid gid groups initgroups last_status maxgroups setpgid setpgrp setpriority setproctitle setrlimit setsid uid waitall waitpid2 warmup
  Dir (19): chdir chroot close delete each_child empty? fchdir fileno for_fd foreach inspect path pos rewind rmdir seek tell to_path unlink
  Module (14): class_exec const_source_location define_method included_modules module_exec nesting protected_instance_methods public_class_method public_instance_method refinements set_temporary_name undefined_instance_methods used_modules used_refinements
  GC (13): auto_compact compact config count garbage_collect latest_compact_info latest_gc_info measure_total_time stat stat_heap total_time verify_compaction_references verify_internal_consistency
  Thread (11): add_trace_func backtrace backtrace_locations each_caller_location handle_interrupt ignore_deadlock keys native_thread_id pending_interrupt? set_trace_func thread_variables
  MatchData (9): == bytebegin byteend byteoffset deconstruct deconstruct_keys match match_length regexp
  Regexp (7): casefold? fixed_encoding? linear_time? named_captures names timeout try_convert
  Encoding (6): _dump _load aliases compatible? name_list names
  ObjectSpace (6): _id2ref count_objects define_finalizer each_object garbage_collect undefine_finalizer
  Enumerator (4): feed produce product with_object
  Enumerable (4): inject reduce slice_after slice_before
  Method (3): << >> curry
  Random (3): new_seed seed urandom
  Integer (2): ceildiv try_convert
  Exception (2): exception to_tty?
  Class (2): attached_object subclasses
  String (1): append_as_bytes
  Array (1): fetch_values
  Hash (1): rehash
  Symbol (1): all_symbols
  Proc (1): ==
  Numeric (1): singleton_method_added

SEND-ONLY: 21 of 1413 names
  Process (6): egid= euid= gid= groups= maxgroups= uid=
  IO (5): autoclose= close_on_exec= lineno= pos= timeout=
  Kernel (3): public_send respond_to? send
  GC (2): auto_compact= measure_total_time=
  Regexp (1): timeout=
  Struct (1): []=
  Exception (1): respond_to?
  Dir (1): pos=
  Thread (1): ignore_deadlock=
```

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

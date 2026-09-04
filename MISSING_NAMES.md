# mere-ruby — the core-class names it does not answer

Ruby 3.2.2's own lists (`instance_methods(false)`, Kernel's private instance
methods, each class's singleton methods -- 1,548 names) called on a sample
receiver under mere-ruby. Regenerate:

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
ABSENT: 278 of 1389 names
  IO (47): advise autoclose? binmode binmode? close_on_exec? close_read close_write copy_stream eof eof? external_encoding fcntl fdatasync for_fd foreach fsync internal_encoding ioctl lineno open pid popen pos pread printf pwrite read_nonblock reopen rewind seek set_encoding set_encoding_by_bom stat sysopen sysseek syswrite tell timeout to_i to_io try_convert ungetbyte ungetc wait_priority wait_readable wait_writable write_nonblock
  File (39): absolute_path? atime birthtime blockdev? chardev? chmod chown ctime empty? executable_real? flock ftype grpowned? identical? lchmod lchown link lstat lutime mkfifo mtime owned? pipe? readable_real? readlink rename setgid? setuid? socket? stat sticky? symlink truncate umask utime world_readable? world_writable? writable_real? zero?
  Kernel (32): !~ === __callee__ __dir__ __method__ autoload autoload? block_given? caller caller_locations define_singleton_method format gem gem_original_require global_variables iterator? lambda load local_variables open printf proc rand respond_to_missing? set_trace_func singleton_method sprintf test then trace_var untrace_var yield_self
  Time (29): asctime ceil ctime deconstruct_keys dst? floor friday? getgm gmt? gmt_offset gmtime gmtoff isdst monday? nsec saturday? strftime subsec sunday? thursday? to_a to_r tuesday? tv_nsec tv_sec tv_usec utc_offset wednesday? zone
  Process (24): _fork argv0 clock_getres egid euid getpgid getpgrp getpriority getrlimit getsid gid groups initgroups last_status maxgroups setpgid setpgrp setpriority setproctitle setrlimit setsid uid waitall waitpid2
  Dir (17): chdir chroot close delete each_child empty? fileno foreach inspect path pos rewind rmdir seek tell to_path unlink
  GC (14): auto_compact compact count garbage_collect latest_compact_info latest_gc_info measure_total_time stat stat_heap total_time using_rvargc? verify_compaction_references verify_internal_consistency verify_transient_heap_internal_consistency
  Module (13): class_exec const_source_location define_method included_modules module_exec nesting protected_instance_methods public_class_method public_instance_method refinements undefined_instance_methods used_modules used_refinements
  Thread (11): add_trace_func backtrace backtrace_locations each_caller_location handle_interrupt ignore_deadlock keys native_thread_id pending_interrupt? set_trace_func thread_variables
  Regexp (7): casefold? fixed_encoding? linear_time? named_captures names timeout try_convert
  MatchData (7): == byteoffset deconstruct deconstruct_keys match match_length regexp
  Encoding (7): _dump _load aliases compatible? name_list names replicate
  ObjectSpace (6): _id2ref count_objects define_finalizer each_object garbage_collect undefine_finalizer
  Enumerator (4): feed produce product with_object
  Enumerable (4): inject reduce slice_after slice_before
  Symbol (3): all_symbols id2name name
  Method (3): << >> curry
  Random (3): new_seed seed urandom
  Integer (2): ceildiv try_convert
  Exception (2): exception to_tty?
  Class (2): attached_object subclasses
  Hash (1): rehash
  Numeric (1): singleton_method_added

SEND-ONLY: 21 of 1389 names
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

2026-09-04: 298 -> 278 ABSENT. Math is libm's now, through `extern fn` -- the
identities that derive it from the builtins are exact in real arithmetic and
wrong in the last bit, which this repository's standard counts as wrong.

2026-09-03: 339 ABSENT. Operators called in method form (`"s".==("t")`,
`[1].+([2])`, `5.~`) were every one a NoMethodError -- they live in eval_e's
EBin arm and the dispatcher never looked there -- and `x.===(y)` was worse:
`is_setter_name` counted `===` as an attribute writer, so it assigned to
`x.==` and answered the argument. Both fixed; 41 names went with them.

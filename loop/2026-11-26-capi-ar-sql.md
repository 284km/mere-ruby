# What activerecord's SQL costs, and the C API's part of it

activerecord's migration_test spends its time in SQL statements, and 0e
measured one at about a hundred times ruby's cost even after #284. This
measures where that time goes on main, takes what the C API can take, and
records the rest.

## Measured

main 6a46f649, mere 9dec2ff6, reference ruby 4.0.10, activerecord 8.1.4.1 on
sqlite3 2.10.2 (railstest/framework's gem homes, installed by this build),
`select 1` on the test connection. Each operation is warmed once first.

| per operation | mere-ruby | ruby 4.0.10 |
|---|---|---|
| raw `execute("select 1")` | 0.589 ms | 0.0027 ms |
| prepared `reset!; step` | 0.0136 ms | 0.0002 ms |
| `select_value("select 1")`, logger off | 3.30 ms | 0.008 ms |

`sample` of each loop (the interpreter's thread; inclusive samples):

- **execute**: 52% inside a C method (`mr_capi_enter`), and nearly all of it
  in the up-calls C makes back into the interpreter (`mr_call`). 36% of the
  loop is one of them: `String#-@` on each column name, which sqlite3's C
  sends (`rb_funcall(str, "-@")`). The other 48% is sqlite3's own Ruby
  (Database#execute, Statement, ResultSet).
- **step**: 45% in C, most of it the two up-calls below.
- **select_value**: 14% in C; 22% in the same `-@`/`dup` walk (from C and
  from activerecord's Ruby alike); the rest is activerecord's and
  activesupport's Ruby.

The up-calls each makes, counted with lldb at `mr_call` (its name argument),
less a run that does the setup and no loop:

| per operation | Thread.current | Thread#[] | String#-@ |
|---|---|---|---|
| execute | 3 | 3 | 1 |
| step | 1 | 1 | 0 |
| select_value | 3 | 3 | 1 |

Thread.current and Thread#[] are sqlite3's callback frame
(`rb_sqlite3_push_callback_frame`), asked around every prepare and step.

### The largest part is not the C API's

`String#-@`, `dup` and `clone` of a String, an Array or a Hash walk the whole
instance-variable table once any String, Array or Hash has ever been given an
instance variable (m_state.mere's `hiv_made`; main.mere's `-@` arm, the
`dup`/`clone` ivar copies, `$/`'s assignment). activerecord's load gives one,
and the table is large then:

| after `require "cases/helper"` | mere-ruby | ruby |
|---|---|---|
| `-("c" + "ol")` | 0.317 ms | 0.0007 ms |
| `"abc".dup` | 0.398 ms | 0.0001 ms |
| `{}.dup` | 0.476 ms | 0.0002 ms |

(in a script that loads nothing: 0.0026 ms for the `-@`.) This is the
interpreter's, the evaluator's and the VM's alike, and the place it lives is
being rebuilt by note 559's 2b (instance variables' storage). 0e takes it as
2b', with Strings, Arrays and Hashes on 2b's layout, which removes
`hiv_made` and the five walks; 0e measures these three operations before and
after.

## What changed

- **rb_thread_current and rb_thread_local_aref look no method up**, as in
  CRuby: request 37 (`MR_THREAD`) answers Thread.current from the table
  `Thread.current` reads, and a thread-local from the table `Thread#[]`
  reads (the running Fiber's own for the current thread in a Fiber,
  `fb_tl_owner`). For anything it cannot answer -- not a Thread, or a value
  of false -- it answers 0 and C sends `#[]` as before, which gives the same
  value. `MERE_RUBY_CAPI_WITHOUT=builtin` sends both as before.
- capi/check: `thread_current` and `thread_aref`, and contracts: C's
  Thread.current is `Thread.current`, also inside another thread; a
  thread-local reads what `Thread#[]=` wrote, nil for none, false for false;
  a Fiber's own in a Fiber, and the thread's again after it; another
  thread's; and a Thread subclass's `#[]` is not what C reads.

## Checked

Instructions of the loop alone, read in the process before and after it
(`proc_pid_rusage`'s `ri_instructions`, from a small C extension built for
each side), with GC disabled during the loop; base and this build
alternating, median of 3:

| per operation | main | this branch | ruby |
|---|---|---|---|
| prepared `reset!; step` | 161,875 | 115,412 (-28.7%) | 2,880 |
| raw `execute("select 1")` | 6,792,954 | 6,644,317 (-2.2%) | 33,522 |
| `select_value("select 1")` | 23,081,784 | 22,947,805 (-0.6%) | 82,168 |

(Taking the difference of two whole runs and dividing by n did not work
here: activerecord's load varies by more than the loop costs.)

- capi_check: the contracts agree on both sides (api 412), hold under
  collection stress, and each negative control fails.
- `run_corpus.sh --both`: the gates, then 962/962 with the hash index on
  and off. `MERE_RUBY_VM=1 run_corpus.sh --both`: 962/962.
- capi_spec_check: 2420 of 2602, the recorded count. capi_mkmf_check passes.
  capi_gem_check: seventeen gems give the same output on both sides (sqlite3
  among them). headers_check passes.

## Left

- The `-@`/`dup` walk: 0e's 2b'.
- What is left of execute and select_value after that is sqlite3's and
  activerecord's Ruby, interpreted: for df's VM work, once 2b' is in, the
  same loops are the measurement.
- capi_check on the VM (#313) runs these contracts on the VM once both are
  in.

# Read existing classes without growing a metaclass chain

The bundled `objspace` shim implemented `ObjectSpace.internal_class_of(o)` as
`o.singleton_class`. The unchanged upstream `test_internal_class_of` follows
class-of links until it sees a repeated object. Creating another singleton on
each read makes that traversal unbounded and reaches the CI memory limit.
It also gives the wrong answer for ordinary objects and raises for values
that cannot have singleton classes.

Read the existing object/primitive class tag directly. Class objects use
explicit metaclass links with a finite cycle; opening a singleton through
`singleton_class` or `class <<` updates those links. Modules retain their
ordinary class until they acquire a singleton. This path does not dispatch
overridden Ruby `class` or `singleton_class` methods.

Singleton existence is recorded persistently by method, undef and mixin
writers. It survives removal of the last own method, includes inherited-only
singletons from `extend`, and is copied by Module dup/clone even when the
singleton is empty. Reflection does not scan the current method table to infer
this history. Only whole singleton names use metaclass handling; an ordinary
class nested inside a singleton namespace keeps its own class identity.

Local macOS arm64 measurements use O2, base `dcbdbf0aab7631d5991a0dccbee87d8802099d63`,
Mere compiler `991f299b20f18639713685fe3297e087ddc5b1d7`, and unchanged CRuby
source `3e93b23afcec3433f6aecc34b5d832799d754238`. The supervisor retains the
600-second wall and 2-GiB process-family RSS limits.

| Measurement | Before | After |
| --- | --- | --- |
| `TestObjSpace#test_internal_class_of` | MEMORY_LIMIT, 5.379 s, 2,173,440 KiB | Pass, 1.627 s, 189,904 KiB |
| Full `objspace/test_objspace.rb` | Cannot finish the class traversal | 62 tests / 776 assertions, 10.454 s, 363,680 KiB, no resource limit |

The full file still has 37 failures, 7 errors and 2 skips. Running the other
61 tests on the unchanged baseline reproduces exactly the same 46 non-passing
case names and outcome categories. These are compatibility findings; bounded
completion does not mean the full file passes. No upstream test or CI limit
is changed by this patch. MRI's internal wrapper objects and exact builtin
metaclass topology are not claimed to be implemented completely.

Validation:

- All 543 corpus programs match Ruby 4.0.9 with hash indexing ON and OFF.
- The new regression and corpus 401, 384, 386 and 94 match Ruby on macOS and
  Linux at O2, with indexing ON/OFF and normal/GC-stress execution
  (`MERE_RUBY_GC_STRESS=100`): 20 comparisons per platform.
- The regression covers immediate/frozen values, existing singleton classes,
  an Array subclass, overridden reflection methods, module singleton methods,
  metaclass exposure, finite traversal, stable class enumeration and GC.
- Review regressions cover inherited-only and empty extensions, last-method
  removal, an overridden `extend_object` that creates nothing, empty singleton
  duplication/cloning and an ordinary class in a singleton namespace.

These are local resource and correctness measurements, not an end-to-end
GitHub Actions speedup. Hosted CI remains a separate validation step.

# Singleton class receivers and super

Class.prepend installed ActiveSupport's subclasses filter, but super inside it
could not find native Class#subclasses when self was a module's singleton class.
super_base lifted singleton classes of objects/primitive values into their
metaclass chain, while leaving singleton classes of modules/classes unlifted.
Every VClass receiver now starts in its metaclass chain. Remove the unused
value-only predicate. No additional state/cache/frame is kept.

Extended943 covers six singleton/metaclass shapes, class/module singleton
bodies, ordinary direct subclasses, defined?(super), and native arity.
Five corpus files match all8 engine/hash/GC32 conditions,40comparisons;
both main943 controls reproduce the gap. Corpus--both1035/1035,VM1035/0/0/0;
12gates pass. Compiler9dec2ff6,mgz661a01d8,clean reference4.0.10/a704/Prism1.8.2.

Core Class/Module/Super and Method evaluator have no prior PASS lost on
complete comparisons. Method VM is unresolved: initial before99complete at
1919360KiB,afterINCOMPLETE/MEMORY_LIMIT2256912KiB; isolated serial whole-file
replays both bound,before2209552/after2104912KiB. Related19-case Method checks
complete all5sides, retaining the same known1Mere failure. No budget/exclusion
was widened; incomplete files are not counted passing.

Separate integrationd1ce15ee adds only this fix/943 to85d7500b, with a fresh
native install from its exact O2 binary. FullMailer17files, both engines:
before0MATCH268MISSING/allMereINCOMPLETE;after248MATCH20RED/zeroother,
all17reference/MereCOMPLETE. No bounds. Residual17 attachment failures are
Array subclass argument coercion;3 keyword failures are implicit super inside
a block in a ruby2_keywords method. These are separate work, not passed cases.

ASJSON158cases,fixedseed12345,threealternatingRSSpairs,normalGC,KiB:
E before1426160/1560592/1579472,after1507616/1591008/1478048;
VM before1196272/1203664/1292576,after1307264/1245088/1303648.
All12pass. MediansE1560592->1507616(-3.39%),VM1203664->1303648(+8.31%).
Ranges overlap; no stable memory improvement claimed. Complete native/tool
provenance and raw record digests are retained. Full runs usejobs2/600s/2GiB.

Ordinary super instructions,3alternatingpairs,startupincluded:
class-methodE+0.235%,VM+0.349%;instance-methodE-0.121%,VM+0.471%.
Latermain398 and its memory changes are not relabelled into these results.
Global/hosted merge holds and Method VM resource acceptance remain unresolved.

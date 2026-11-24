# Native dependency library search directory

Base: main 6d62be02. Runtime: 9cd70852. Reference Ruby: 4.0.10,
source a704b7cd95a42cc0cf5f307137bf3aac0285b915, binary SHA-256
5ad9092ceb67b18b9ed512ad3fbcf309910c7ad7d2fabb3d85d5228a51eb8df0.
The independent reference has 84 default/bundled specifications and zero extras.
All native gems are built in private gem homes, never Gem.default_dir.

mkmf places libdir before explicitly configured dependency directories. The
placeholder system libdir therefore selected Apple's SQLite even when
--with-opt-dir selected Homebrew headers. Fresh sqlite3 2.10.2 builds reproduce
this: reference links the configured-prefix library, while main links the
system library and its forked file-database child reports a segmentation fault.

RbConfig::CONFIG now reports the actual C API import-library directory when
native headers are present; MAKEFILE_CONFIG keeps the same value. Other
installation placeholders and the no-C-API layout retain their existing paths.
This changes no SQLite source, fork hook, native gem packaging or C API ABI.
Corpus 1019 checks that the advertised runtime library exists in libdir and
that CONFIG and MAKEFILE_CONFIG agree: main answers false/true, candidate and
reference true/true. It requires no external SQLite package.

The following initial cohort predates #235. Growing append-mode logs can
inflate timing/RSS; those numbers are historical and are not a current-main
performance claim. The newly authorized full Action Pack run uses a separate
combined build containing main 66a7afd0 and fresh native gems.

Validation, ordinary O2 build:
- Fresh reference/main/candidate builds from the same sqlite3 archive use
  --enable-system-libraries and the same configured prefix. Main's file child
  exits 1; candidate/reference file and memory children exit 0. Both evaluator
  and VM pass. The parent's subsequent SELECT 42 succeeds in all probes.
  Native library load and linked dependency provenance are checked explicitly.
- capi_check: all six contracts on both interpreters and under GC stress pass;
  all six negative controls fail as required. Existing API count remains 261.
- Full optional/capi replay: 46 files; reference 2602, main 2420, candidate 2420,
  identical per-file pass counts. Existing unsupported/limited files are unchanged.
- mkmf checks: 14 contracts on reference/Mere/GC stress; upstream launcher and
  child retain their context; broken compilation and foreign-runtime controls
  fail as required.
- run_corpus.sh --both: 870/870, hash index ON and OFF, 822.341 seconds,
  maximum family RSS 1195392 KiB, no resource event. Bounds remain 900 seconds
  and 2 GiB. VM corpus: 866 VM / 4 fallback / zero differences, exact inventory.
- Source gates and default/explicit record hygiene pass.

The two unchanged Active Record target files use private framework gem homes
with only the freshly built SQLite gem overlaid; all other installation
provenance is retained and the runner records --other-install-binary. Each
side keeps its own source copy and temporary directory. Main stops partway in
both files (zero MATCH, five MISSING); candidate completes both with five MATCH,
zero RED/missing/skips. Fresh standalone SQLite builds independently prove the
library/fork behavior, without relying on a full Rails installation.

Maximum process-family RSS, KiB:

| File | main, incomplete | candidate, complete |
| --- | ---: | ---: |
| connection_adapters/registration_test.rb | 590528 | 724608 |
| reload_models_test.rb | 578544 | 689600 |

The baseline crashes before completing the work, so the higher completed-run
peaks are reported without attributing them to retention or claiming a memory
reduction. Parent native-probe peaks remain about 185 MiB. Complete framework
runs still wait for the owner's heavy-run authorization. Portable validation
and exact C API spec comparisons are under capi/check/records; raw logs remain
private. No erb/escape, puma/native-gem WIP or bignum.c changes are included.

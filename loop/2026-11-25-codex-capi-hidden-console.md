# C API internal constant cache operations

Base: main 6d62be02. Runtime: a0248d71. Reference Ruby: 4.0.10,
source a704b7cd95a42cc0cf5f307137bf3aac0285b915, binary SHA-256
5ad9092ceb67b18b9ed512ad3fbcf309910c7ad7d2fabb3d85d5228a51eb8df0.
The private reference still has 84 default/bundled specifications and no extras;
no framework gems are installed into its default gem directory.

io-console 0.9.5 caches IO.console under the non-public ID console. Constant
set/get already used hidden storage, but defined/get-at/get-from/remove called
Ruby's public name validation and raised NameError instead of using that cache.
The change completes those hidden-ID operations. Valid public constant names
keep their existing paths. Inheritance, direct lookup, false/nil values,
removal and public Ruby rejection are covered by shared C/Ruby contracts.

Removal checks the owning class's actual frozen state through the existing
exported rb_check_frozen function. Its inline macro reads class proxy flags,
which currently omit that bit. This local choice avoids altering other C API
implementation work. The frozen-owner case also appears in corpus 1018.

The corpus builds a tiny extension against each runtime's own headers and
uses the same program on reference, evaluator and VM. Main raises the original
NameError; the candidate matches reference. Existing corpus selectors accept
four-digit names through corpus/*.rb; explicit record hygiene covers this log.

The following initial cohort predates #235. Growing append-mode logs can
inflate timing/RSS; those numbers are historical and are not a current-main
performance claim. The newly authorized full Action Pack run uses a separate
combined build containing main 66a7afd0 and fresh native gems.

Validation, ordinary O2 build:
- capi_check: all six contracts on reference/Mere/GC stress and all six negative
  controls pass. API checks increase from 261 to 311, adding 50 assertions.
- Full optional/capi replay: 46 files; reference 2602, main 2420, candidate 2420.
  Every per-file pass count is identical to main. Existing io/thread limits and
  the unbuilt digest extension are recorded, not changed by this fix.
- run_corpus.sh --both: 870/870 match with the hash index ON and OFF;
  829.392 seconds, maximum family RSS 1180736 KiB, no resource event,
  original 900-second / 2-GiB bounds.
- Full VM corpus: 866 VM / 4 fallback / zero differences, exact inventory.
- Source gates and default/explicit record hygiene pass.
- Fresh io-console builds in separate gem homes: main raises NameError under
  evaluator and VM; final candidate and reference both return nil outside a TTY.
  Each probe confirms that it loaded its own installed native extension.
- Targeted unchanged Rails files move from 362 MATCH / 2 RED to 364 MATCH /
  zero RED: Routing Inspector's 33 tests and routing's 331. The earlier
  framework-native installation provenance is explicitly recorded by the
  diagnostic runner; the separate native-gem reproduction uses fresh builds.

Maximum process-family RSS, KiB (same source, seed, reference and bounds):

| File | main | candidate |
| --- | ---: | ---: |
| dispatch/routing/inspector_test.rb | 424928 | 420432 |
| dispatch/routing_test.rb | 612736 | 623152 |

No uniform memory reduction is claimed. Complete Action Pack validation still
requires the owner's scheduled heavy-run slot. Portable validation and exact
spec counts are under capi/check/records; raw logs remain private.

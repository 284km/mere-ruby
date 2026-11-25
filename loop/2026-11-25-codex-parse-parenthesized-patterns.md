# Parenthesized rightward sequences and invalid hash-pattern keys

A rightward match inside parentheses now uses the same statement-sequence
continuation as an ordinary expression. A semicolon or newline can follow
its pattern; missing separators still fail. This also covers endless methods
and eval. Hash patterns reject bare instance/global/class-variable keys while
retaining valid quoted symbol labels.

Invalid hash-pattern keys now use the existing Prism framed formatter in
eval and load. Main-script and require entry points reach that formatter too.
Equal-position errors are inserted in Prism's own order (later diagnostics
first), preserving the framed regexp diagnostics checked by corpus 817.
Corpus 989/990 covers direct scripts, eval, load and require, plus the negative
separator and match controls. CLI comparison disables the optional
syntax_suggest addon to compare the core Prism report.

Base main: ab5a9bfd. Runtime: 6bba95f8. O2 compiler revision:
9dec2ff687a08433247dbdb7729bc19c8522e538. Clean reference Ruby 4.0.10,
revision a704b7cd95a42cc0cf5f307137bf3aac0285b915: 84 default/bundled
specifications, zero extras, Prism 1.8.2. No reference gem-directory writes.

Validation:

- Corpus --both, run alone: 885/885 ON and OFF; 1070.447 s,
  peak family RSS 1,188,688 KiB, no resource event.
- VM corpus: 885 VM / 0 fallback / 0 differences; 1839.083 s,
  peak family RSS 1,163,968 KiB, no resource event.
- An earlier full-corpus attempt reached its whole-run 3,600-second limit
  after program 726 during concurrent work, with no observed difference.
  It is retained as incomplete; the successful standalone run keeps the
  same limits and complete inventory.
- Nine source gates and record_hygiene pass (342 existing records).
- All six requested CRuby files are COMPLETE before and after on both
  executions, and no passing case is lost. Existing test_parse failures
  remain 3 evaluator / 2 VM with one skip; test_syntax has one error and two
  skips; test_m17n has one skip. m17n_comb, mixed_unicode_escapes and
  pattern_matching pass. Full summaries and nonpassing identities are retained.

Parse-heavy instruction counts use -c on unchanged 100,374-byte Rails
routing/mapper.rb. Three alternating samples: main 189,102,050 / 170,212,748 /
170,196,043; candidate 171,378,752 / 170,902,099 / 169,928,854. Medians:
170,212,748 to 170,902,099 (+0.40%). First-run variation is explicit.

Fixed seed 1, complete m17n_comb (82 tests / 248,127 assertions), alternating
RSS samples in KiB: main 975,504 / 624,032; candidate 807,856 / 868,064.
The six-file cohort has 562,176 KiB evaluator / 617,904 VM before, and
545,904 evaluator / 543,056 VM after. RSS varies substantially; no memory
improvement or stable increase is claimed.

Portable validation: unittest/records/parenthesized-hash-patterns.json.


## Review follow-up

The in branch now shares sequence continuation with rightward matches. Parenthesized matches accept
if/unless/while/until/rescue and and/or continuation through the existing statement modifier parser.
Corpus 989 adds direct and eval controls. The string forms of instance_eval/class_eval/module_eval
still use their pre-existing raw-error path; their diagnostic framing and other pre-existing parser
suggestions are separate follow-ups.

Runtime a5184219, ordinary O2. Full corpus --both: 885/885 ON/OFF (1188.432 s, 1,214,656 KiB). VM:
885 / 0 fallback / 0 differences (528.306 s, 1,109,824 KiB). Eight prefix source gates and default
hygiene pass; generated C needs 155 of the unchanged 1024 bracket limit.

All 6 related CRuby files are COMPLETE on both engines and lose no previously passing case. Existing
nonpasses are retained in the portable record. Parse-heavy mapper instruction medians: 171,522,878
to 170,369,625 (-0.67%), with all three alternating samples preserved. Fixed-seed m17n_comb RSS
after the review change is 977,216 KiB evaluator / 1,017,424 KiB VM; the earlier repeated
main/candidate range above remains the context for its substantial variation.

Portable review validation: unittest/records/parse-patterns-review.json.

# Array index review follow-up and final Action Mailer measurement

Runtime `da465c1481770a472764455c775bacea047528c0`; standalone main control8edcf953. Clean Ruby4.0.10 via
tools/ref_ruby.sh; official revisiona704b7cd95, Prism1.8.2, zero extra gems.

Native alias arity is checked before nil/index conversion and before any to_int hook.
Corpus941 matches all8 evaluator/VM, hash-index and normal/GC32 configurations.
Corpus --both1036/1036; VM1036/0fallback/0differences; source and StrBuf gates pass.
Related36-case Array selection COMPLETE on all five sides, retaining the same2
pre-existing range-length failures on Mere; no previous main PASS lost.

| Operation | evaluator instructions | VM instructions |
| --- | ---: | ---: |
| plain_array_read | -2.17% | -0.69% |
| plain_array_write | -1.78% | -1.10% |
| plain_array_fetch | -1.56% | -1.31% |
| array_range_slice | -1.26% | -1.41% |
| array_values_at_three_ints | -2.81% | -2.69% |

Max RSS KiB for AS JSON158 cases, three alternating fixed-seed12345 pairs;
fresh native installations for each exact measured binary and recovered reference:

| Engine | Before samples | After samples | Median change |
| --- | --- | --- | ---: |
| evaluator | 1611200 / 1589248 / 1625328 | 1616144 / 1587952 / 1572800 | -1.44% |
| vm | 1153392 / 1363952 / 1110960 | 1108720 / 1195424 / 1181248 | +2.42% |

All12 resource runs are COMPLETE/all passing. Sample variation is retained;
no stable memory improvement is inferred from overlapping sample ranges.

Final separate integration2e4f1192: Action Mailer all17 files, both engines
268MATCH and zero RED/MISSING/BOTH/UNCONFIRMED/EXTRA. All files COMPLETE;
no WALL_LIMIT or MEMORY_LIMIT. Integration corpus1037/1037, VM1037/0/0.
Bounds remain600seconds/2GiB per file family, jobs2, seed12345.

The older v15 attempt failed in reference RubyGems startup before discovery.
The recovered isolated official Ruby build and all new native installations
have separate source/binary receipts. This is frozen source, not later main.

Detailed portable evidence is in actionmailer-array-index-review-followup.json
and actionmailer-final-17.json. Earlier whole-Array memory bounds remain in
actionmailer-array-index-overrides.json. Explicit record hygiene is required.

Code and records are pushed together; exact-head bot review and owner acceptance
remain required. No self-merge.

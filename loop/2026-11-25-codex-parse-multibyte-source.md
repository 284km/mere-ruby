# Lexer character boundaries in CP932, Shift_JIS, Big5 and GBK

The lexer now consumes an entire encoded character before interpreting ASCII
backslashes or delimiters. A CP932 or Shift_JIS trail byte 0x5c therefore stays
inside its character in strings, quoted symbols, regexps, heredocs and percent
words. Interpolation and regexp preflight use the same boundary rule. Required
VM source already uses Prism for literal parsing; regexp validation now retains
and restores the source encoding too.

Big5-family and GBK ranges now describe their own lead/trail bytes. This fixes
source identifiers, character and symbol literals, valid_encoding? and chr;
Big5 0x8140 is rejected, while GBK's permitted 0x80 is retained. Exhaustive
one/two-byte boundary probes were compared with the clean reference. Existing
UTF-8 control/meta escape rejection remains in place (corpus 331).

Base main: 2137de26. Runtime: bcd2ea6a. O2 compiler revision:
9dec2ff687a08433247dbdb7729bc19c8522e538. Reference Ruby 4.0.10 revision:
a704b7cd95a42cc0cf5f307137bf3aac0285b915, 84 default/bundled specifications,
zero extras, default Prism 1.8.2. No gems were installed into the reference.

Validation:

- run_corpus.sh --both: 881/881, hash index ON and OFF; 2,627.042 s,
  maximum family RSS 1,082,048 KiB, no resource event.
- VM corpus: 881 VM / 0 fallback / 0 differences; 1,115.393 s,
  maximum family RSS 1,181,488 KiB, no resource event.
- Nine source gates and record_hygiene pass (342 existing records).
- New programs cover main-script and require execution under evaluator and VM.
  The separate literal probe had 336 candidate comparisons and no differences.
- The six requested CRuby files are COMPLETE on both modes before and after;
  no previously passing case is lost. Existing failures remain unchanged:
  test_parse has 3 evaluator / 2 VM failures and one skip; test_syntax has one
  error and two skips. test_m17n has one skip. The other three files pass.
  Full summaries, assertion counts and nonpassing case identities are recorded.

Parse-heavy instruction counts use ruby -c on the unchanged 100,374-byte Rails
routing/mapper.rb, SHA-256 f4080c6ffc17ca38b411c5d4e67a6dffb32dde4ba7242860557ae3ebb19dbe9f.
Three alternating samples: before 187,858,239 / 169,463,221 / 170,994,771;
after 171,297,349 / 169,525,845 / 169,815,377. Medians are 170,994,771 and
169,815,377 (-0.69%). First-run variation is shown; no speedup is claimed.

Memory audit, fixed seed 1, complete test_m17n_comb (82 tests / 248,127
assertions): alternating before 936,512 / 986,768 KiB, after 996,720 /
1,019,344 KiB. The wider baseline observations range from 607,904 to
1,112,640 KiB; the final six-file run has after peaks of 787,760 KiB evaluator
and 655,328 KiB VM. Shared-machine RSS varies substantially, so these raw
samples do not establish a retention regression or a memory improvement.

Corpus names were changed from 987/988 to 991/992 after the complete runs to
avoid collisions with #242 and #239. Contents are byte-for-byte unchanged;
the portable record includes the filename mapping and full source hashes,
and the renamed programs plus 331 were replayed on both modes.

Detailed portable validation: unittest/records/parse-multibyte-source.json.


## Review follow-up

Regexp classes and group skippers now consume a whole character in the pattern encoding; class
ranges use encoded character values. A backslash before a non-ASCII character also consumes the
complete source character in strings, regexps, symbols, words and heredocs. Corpus 991 covers
Windows-31J, Big5 and GBK through main scripts, require, eval and instance_eval, including
Regexp.new and scan. GB18030 and Regexp.escape/union remain separate pre-existing follow-ups.

Runtime f73f8c90, ordinary O2. Full corpus --both: 881/881 ON/OFF (1192.326 s, 1,195,488 KiB). VM:
881 / 0 fallback / 0 differences (526.547 s, 1,149,856 KiB). Eight prefix source gates and default
hygiene pass; generated C needs 155 of the unchanged 1024 bracket limit.

All 7 related CRuby files are COMPLETE on both engines and lose no previously passing case. Existing
nonpasses are retained in the portable record. Parse-heavy mapper instruction medians: 169,609,105
to 169,985,626 (+0.22%), with all three alternating samples preserved. Fixed-seed m17n_comb RSS
after the review change is 789,792 KiB evaluator / 936,704 KiB VM; the earlier repeated
main/candidate range above remains the context for its substantial variation.

test_regexp remains 176 tests / 62,595 assertions / 4 failures / 3 errors on both main and
candidate, with identical passing identities; the reference itself reports one failure and one error in this
local cohort. These are not described as an all-pass file.

Portable review validation: unittest/records/parse-multibyte-review.json.

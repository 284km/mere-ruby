# The embedded YAML parser reads bytes (eager_test's citations fixture)

After #351 and #353, eager_test's `test_preloading_too_many_ids` still peaked past the 2 GiB limit.
Its fixture of 65,536 citations, read and then collected, left the process 1.2 GB above where it began, and none of it was live data: `FixtureSet.reset_cache` and `GC.start` moved nothing.
A plain `YAML.load` of the rows, kept and collected, showed the same shape at 16,384 rows -- ruby +30 MB, mere +232 MB -- and most of mere's was String slots: about 110 Strings made a row, about 6 kept.
A String's slot is never reused (the collector's watermarks depend on the order handles are issued), and a page of 4,096 goes back only when none of its Strings lives; with the survivors spread over every page, the dead slots stayed: 1.8M of them, 75 MB.

## Where the Strings came from

`lib/psych_parser.rb`'s scanner read the source one character at a time: `__char` answered a new one-byte String for every position it looked at, and `__advance` returned it -- for each blank, each indicator, each byte of an anchor's name, each comparison with the next character (`=~ /\s/` on it).
Around them, each token made a Hash of the punctuation and one of the indicators, and the structure's `[:eof, :document, :end_document].include?` made an Array per question.

## The change

- The scanner reads bytes: `__byte` is `getbyte` on the window `__char` used, and the comparisons are of Integers. The syntax of YAML is ASCII.
- `__advance` answers the byte, and counts the marks exactly as before: a line at "\n", a column and an index per character (a UTF-8 continuation byte, 128..191, is not one).
- What a token holds -- a directive, an anchor's or alias's name, a tag, a scalar -- is cut from the source by byte position, as quoted and plain scalars already were. The source is UTF-8 by then (UTF-16 is converted where parse begins), so a multibyte character is never split or re-encoded.
- `__skip` counts a run's characters without a String when the source is ASCII only; a plain scalar is copied once, not three times; the punctuation and indicator tables and the structure's lists are constants.

Checking it against ruby found what was wrong before it, fixed in their own commit:

- an anchor's or alias's name is libyaml's -- letters, digits, `_`, `-`, ended by a blank or one of `? : , ] } % @` and the backquote -- else an error at the `&` or `*`, "while scanning an anchor" / "an alias" (a multibyte name was taken; an empty one was reported a column late);
- a CRLF after a block scalar's header and at the end of its lines is one line break (`a: |\r\n  x\r\n` was "did not find expected comment or line break");
- a tab where a token starts, and `%` `@` and the backquote, report "while scanning for the next token".

Still different from ruby, before this and after (structure, not the scanner):

- `日本: 1\n  語: 2\n x\n` and `鍵: 値: 二重` load where libyaml says "mapping values are not allowed in this context";
- a flow indicator after an anchor in block context (`a: &x, v`) is taken;
- UTF-16 handed over as a binary String is "invalid leading UTF-8 octet" where libyaml says "control characters are not allowed".

## Checked

Built with the Mere CI uses (9dec2ff6). `YAML.load` of the fixture's rows, the default collector, kept to the end (scratchpad `yk3.rb`):

| rows | time, main | this | peak footprint, main | this | kept after GC, main | this |
|---|---|---|---|---|---|---|
| 16,384 | 75.2 s | 63.4 s | 544 MB | 436 MB | 315 MB | 208 MB |
| 65,536 | 298.6 s | 259.3 s | 1,632 MB | 1,203 MB | 979 MB | 553 MB |

At 16,384 rows the String slots are 1.8M → 166k, the String store 75 → 10 MB.
The time is still the interpreter's: the event stream alone is about 2.5 ms a row, some 1,600 builtin calls a row (Integer comparisons, `[]`, `getbyte`) at about a microsecond each, on the evaluator and the VM alike.

test/psych (`unittest/run.sh`, 635 tests): MATCH 635 on the evaluator and on the VM, the hash index on and off. The YAML programs of the corpus (16) match ruby.
Corpus 1072: multibyte keys, values, comments, quoted, block and flow scalars, anchors; error marks after multibyte characters; UTF-16 with and without a BOM, a UTF-8 BOM; CRLF, tabs, trailing blanks; a handler's event marks.

## The corpus

On main 3fbe3921, with `MERE_RUBY_SHAPES_CHECK=1`: 994/994 on the evaluator and on the VM, the hash index on and off (1072 among them).

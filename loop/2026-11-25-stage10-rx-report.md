# A regexp literal's SyntaxError is said as ruby says it

The review of #223 noted that a required file whose regexp literal does not compile raised a SyntaxError with the reason alone, where ruby's message starts with the path and the line and quotes the source. The same was so of an eval. This is that follow-up.

## What ruby says

There are two kinds of refusal, and ruby words them differently.

**Prism's own.** Prism has a regexp parser, and a literal it refuses is one of Prism's syntax errors: a parenthesis that is not closed, a repeat of nothing, an escape cut short, an empty class, an unknown group option. The message is Prism's report of the source:

```
D/mid.rb:6: syntax error found
  4 | v4 = 4
  5 | v5 = 5
> 6 | v6 = /(un/
    |        ^~ end pattern with unmatched parenthesis
  7 | v7 = 7
  8 | v8 = 8
```

**The regexp engine's.** What only the engine refuses is found when the literal is compiled: a class that does not end, a property nobody knows, a name nobody defined, a repeat range upside down. The message is one line, "D/f.rb:3: premature end of char-class: /[a-/", for the first such literal alone.

Here both were the reason and the pattern, with no path in a required file and with the eval's first line in an eval.

## The change

**`prism_report`** asks libprism for its errors of the source (`ic_tree_errors`, a reader of the head of the serialized parse) and writes the report as `pm_parse_errors_format` writes it. The rules were each read off ruby 4.0.10's output for a file made to show them:
- the errors in the order of their place, and "errors" when there are two;
- two lines before the first error's line and two after the last one's; between two errors every line when there are four or fewer, else two after, a row of `~`, and two before;
- a line number as wide as the last error's line number, so a line past it can be wider;
- `^~~` under the error's characters, one column a character (a tab too), cut at the end of its line;
- a line whose error starts 30 bytes in or more starts there, after "... ", and one that goes on 30 bytes past the error stops there, with " ...".

It answers nothing when Prism has no error, or has one that is not a syntax error's.

**A required file** (`rxchk9`, round 60's check) and **an eval** now say Prism's report when Prism has an error, and otherwise the engine's reason at the literal's own line. The line is where the literal was lexed, which the check already kept for warnings.

That line was the eval's own count: a literal on the third line of an eval that starts at line 10 was "line 3". So was the line of a literal's **warning** in such an eval ("f.rb:2: warning: ..." for ruby's "f.rb:11"). The place is now counted as the lexer counts an eval's lines.

**Two of the engine's wordings**: "unmatched close parenthesis" (it said "unmatched )"), and "invalid group name <1>" (it said "bad group name").

## A defect of the VM, found on the way

Under MERE_RUBY_VM a regexp literal with a warning was warned of **twice**. This was on main, for the main script and for a required file:

```
main.rb:2: warning: character class has '-' without escape: /[a-a-z]/
<internal:prelude>:2660: warning: character class has '-' without escape: /[a-a-z]/
```

The parse says a literal's warnings, with the literal's place. Then the compiler makes a Regexp of the literal for the VM to keep, through the same door as `Regexp.new`, which says the regexp parser's warnings at whatever line is current. A Regexp a compiler makes of a literal is now quiet (`ic_first_v`'s second slot, read in `__rx_new`), for the native compiler and the Ruby one.

## What a loop of evals showed

test_eval's `test_syntax_error_no_memory_leak` evals `/[/=~s` 100,000 times and allows the process twice its memory. The first form of this change failed it, and main was already at 1.9 times. Two things grew, both of them containers written at every refusal:
- a Vec made at each call (the options' bytes, the reader's position, the lines' starts) is not given back, in a region or out of one. They are now three Vecs kept and emptied at each call (`vec_recycle`).
- the refused literal's place, written as an entry of the `rx_cur` map and deleted, grew the map's arena. It is now an Integer in a Vec (`rx_bad_line`).

After 100,000 such evals the process is at 129.6 MB (main: 131.7 MB), and after 300,000 at 142.7 MB (main: 139.3 MB).

## Not changed

- ISeq.compile's check evals the source with a line of its own in front, so a frame of it would show that line. It keeps the message it had.
- A literal the lexer itself refuses (`/\/`, which never ends) has a frame already, and its mark and words are not Prism's yet: "unterminated regexp meets end of file" at the end, for ruby's "...; expected a closing delimiter" at the start.
- Other syntax errors are not taken from Prism. The evaluator's parser words those itself, and the two do not always agree on what is an error.

Corpus 817 has a required file and an eval of each shape above (34 sources), the warning's line in an eval and in a required file, and a child run that counts the warnings of a main script and a file it requires.

## Checked

Against ruby 4.0.10 (tools/ref_ruby.sh), built with Mere 9dec2ff6, on main 6d62be02:
- corpus 870/870. Under MERE_RUBY_VM=1: 866 on the VM, 4 fell back, 0 different.
- Corpus 817 differs on main's build, on both executions.
- vm_check 245/245.
- The gates: dead defs, dup defs, gc roots, bracket depth.
- `tools/iseq/native/check.sh` on 21 files: 20 the same as the Ruby compiler's sequences, 0 different, 1 that neither compiles.
- The CI corpus job's OpenSSL checks: asn1, provider, formats, reinitialize, memory, wasm.
- These give the same counts as main 6d62be02's build, on both executions: test_regexp, test_parse, test_syntax, test_eval, test_require, test_rubyoptions, test_iseq and test_exception.
- 23 files of ruby/spec give the same output as main's build: language/regexp_spec and the 11 under language/regexp/, core/regexp's new, compile, union and initialize, core/kernel's eval, require and load, core/binding/eval, core/exception/syntax_error, language/string and core/warning/warn. (The spec tree is 4.0.9's; this compares the two builds, not either with ruby.)
- The messages of 31 patterns, as a literal in an eval and through Regexp.new, against ruby's: the same but for the unterminated `/\/` above.

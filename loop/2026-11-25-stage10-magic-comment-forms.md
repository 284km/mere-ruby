# A magic comment in ruby's two forms, and only those

A follow-up to #257, from its review. #257 made the evaluator read `shareable_constant_value` only as a comment's key, so that a comment mentioning the name (one of round 63's, in the Ruby compiler) was no magic comment. It took a key after a `;` anywhere, and the review found the case that gets wrong:

```ruby
# frozen_string_literal: false; shareable_constant_value: literal
A = [1]
A.frozen?   # false in ruby; true on the evaluator; false on the VM
```

## ruby's rule

Read off ruby 4.0.10 for 25 comments, each before a constant written after a statement:

- **the plain form** is one pair and nothing else: `# key: value`, blanks allowed around the colon and after the value. `# shareable_constant_value: literal; foo: bar`, `# ... literal x` and `# frozen_string_literal: false; shareable_constant_value: literal` set nothing;
- **the emacs form** is the text between two `-*-`: pairs separated by `;` or by blanks, a word with no `:` passed over (`# -*- foo shareable_constant_value: literal -*-` is read);
- the key is a word of its own: `# a-shareable_constant_value: literal` and `# foo shareable_constant_value: literal` are none.

## The change

`scv_value` reads the two forms so. All 25 comments give ruby's answer on both executions (the VM's main script is read by the evaluator's lexer too).

**And the warning of a late `frozen_string_literal`.** "'frozen_string_literal' is ignored after any tokens" was said for a plain comment that only started with the pair (`# frozen_string_literal: true; shareable_constant_value: none`), which ruby does not take for a magic comment and says nothing of; and it was not said for the emacs form (`# -*- frozen_string_literal: true -*-`), which ruby warns of. `fsl_comment_text` reads the same two forms. This was on main, on both executions.

Corpus 823's file of magic comments has the forms.

## Checked

Against ruby 4.0.10 (tools/ref_ruby.sh), built with Mere 9dec2ff6, on main 8b1b9525 (and spot-checked on ec980154: corpus 823, the 25 comments, vm_check):
- corpus 894/894 (one program, 293, differed in the first sweep at a load of 30, and matches in a sweep again). Under MERE_RUBY_VM=1: 894 on the VM, 0 fell back, 0 different.
- Corpus 823 differs on main's build on both executions.
- vm_check 245/245.
- The gates: dead defs, dup defs, gc roots, bracket depth.
- These give the same counts as main's build, on both executions: test_parse, test_syntax, test_rubyoptions and test_literal.

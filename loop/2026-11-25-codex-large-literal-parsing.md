# Remove quadratic parsing work from large literals

The branch starts from main
`66a7afd02bfcde2c512fb686e7584ad556d77de3`. Reference Ruby is the clean
4.0.10 build from `a704b7cd95a42cc0cf5f307137bf3aac0285b915`, with only
its 46 default and 38 bundled gems and Prism 1.8.2. Use the pinned Mere
compiler `9dec2ff687a08433247dbdb7729bc19c8522e538` and mgz
`661a01d8bb68f5acd68e3192bd47f081d179c436` for ordinary O2 comparisons.

The two Literal cases in ruby/test_allocation.rb timed out on the starting
main. Standalone reproduction and native sampling identified three scans:

* An Array element's tok_line walks forward to its logical line's end.
  Calling it for every literal element made a long single-line Array
  quadratic, although ln_before never annotates a literal. Calculate the
  line only for the expression forms that can receive a call annotation.
* colon_after_value checked for an alias/undef statement by walking backward
  to the line's beginning at every label. Decide first whether the previous
  token can be a value. A label cannot, so long Hashes avoid that scan while
  quoted alias/undef names and actual ternary values keep their checks.
* Static duplicate-key warnings searched a growing linked list at every key.
  A native Map now records hash-literal keys, shared through nested literal
  double-splats. Its HDUP region ends after the warning walk; no Ruby Array
  or Hash is created to track it. Computed keys remain runtime questions and
  are not added. Case/when's separate warning logic is unchanged.

On the earlier merged-main O2 binary, a standalone 100,000-element Array took
16.821 seconds and 96,160 KiB peak process-family RSS; sampling attributed
739 of 740 worker samples to tok_line under parse_arr_expr. A standalone
100,000-key Hash did not finish within the 45-second profiling bound,
reaching 86,624 KiB before its own process family was stopped. Sampling
attributed 754 of 758 worker samples to lvt_names_stmt under colon_after_value.
These preliminary profiles establish the causes, not final-head acceptance
measurements. Raw machine-specific profiles are not committed.

Corpus 988 defines the large Array and Hash before its measurement window.
It compares the actual user allocations, one Array and one Hash, without
imitating CRuby compiler temporaries. It also compares call-site lines,
nested arrays, multiline strings and continued lines, alias/undef, ternaries,
static duplicate warnings across literal double-splats and computed keys.
All 12 output lines match the clean reference on both development engines.

Final acceptance retains all 76 allocation cases and their unchanged
budgets; no exclusion, shorter fixture or longer timeout is used. Measure
the file alone on evaluator and VM, before/after on O2, and post MATCH/RED
and process-family max RSS in the English PR. Post the full corpus on/off,
the subsequent VM corpus counts, source gates and record_hygiene on the
final head. Run one corpus sweep at a time. No runtime method dispatch,
argument binding or block-call code is changed; no full unit-test suite or
Rails cold measurement is run. Read automated inline review comments after
opening the PR and after every push.

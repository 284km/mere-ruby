# The file and the method a call was made from, kept as numbers

Note 560, C (after A, #321).

## What a call did with them

A call keeps, per call depth, the file and the method it was made from, and puts them back when it returns. The running file and method are already numbers: `cur_fm`'s two slots, indices into `pos_names` and `meth_names`. But the depth tables kept them as names:

- **On the way in**, `call_files_s` and `call_meths_s` were written with `cur_file ()` and `cur_meth ()`. `map_set_si` compares the name already there before writing.
- **On the way back**, `cur_file_set` and `cur_meth_set` took those names and found their numbers again: two hash lookups each.
- **The new frame's label** was made a number the same way (`cur_meth_set mlabel9`).

After A, in a self call on the evaluator, `cur_meth_set` was 3.5%, `cur_file_set` 2.0% and `map_set_si` 2.0%.

## The change

- **Numbers in, numbers back.** `call_file_ids` and `call_meth_ids` keep the two numbers per depth. `cur_file_back` and `cur_meth_back` put them back into `cur_fm`. A file name kept with its box's mark still goes through `cur_file_set`, which enters the box, as before.
- **The label's number** is in the method's record (`meth_name_id`, the 16th field), so a call of a method with a record sets it with one store (`method_body_flow_lbl`'s `lid`). `meth_name_id` is what `cur_meth_set` did to a name, now a function of its own.
- **The one reader** of a depth's file as a name (`m_eval_leaf.mere`'s frame location) asks `call_file_at`.

`call_names_s` and `call_lines` stay as they were: the backtrace builders read the names, and `map_set_si` writes nothing when the label at a depth is the same.

## Numbers

Instructions, the median of three runs alternating main (89ad241c, with note 559's 2b) and this branch, both built with Mere 9dec2ff6 (CI's). The micro programs are per call, with the same loop without the call taken off.

| program | evaluator: main | here | VM: main | here |
|---|---|---|---|---|
| a self call in a method (per call) | 19,380 | 18,310 (-5.5%) | 21,620 | 20,550 (-4.9%) |
| a method calling another object's method (per call) | 24,680 | 23,740 (-3.8%) | 25,680 | 24,700 (-3.8%) |
| a top-level method (per call) | 12,180 | 11,450 (-6.0%) | 14,110 | 13,370 (-5.2%) |
| app_fib | 215.8 G | 204.6 G (-5.2%) | 207.4 G | 196.2 G (-5.4%) |
| app_tak | 378.2 G | 363.8 G (-3.8%) | 338.4 G | 324.1 G (-4.2%) |
| so_object | 151.4 G | 150.0 G (-0.9%) | 165.4 G | 164.0 G (-0.8%) |
| Rails 8.1's warm boot (`bin/rails runner`) | 49.6 G | 49.3 G (-0.6%) | 48.9 G | 48.6 G (-0.6%) |

Maximum RSS under `MERE_RUBY_GC_TIGHT=1`, the median of three alternating runs:

| program | evaluator: main | here | VM: main | here |
|---|---|---|---|---|
| a recursion 5,000 deep, 200 times | 313.0 MB | 311.2 MB | 564.3 MB | 562.6 MB |
| test/ruby/test_backtrace.rb (seed 1) | 193.0 MB | 195.7 MB | 188.6 MB | 188.8 MB |

test_backtrace's runs spread by 4 to 6 MB on main alone (189.9 to 193.7 MB on the evaluator).

## Checked

- Corpus with `MERE_RUBY_MREC_CHECK=1` and without, on both executions; vm_check; the collector's root check.
- Seven unit files on both executions against main: test_backtrace, test_exception, test_fiber, test_thread, test_settracefunc, test_method, test_proc. The same results as main.

## Witnesses

Corpus 832: methods written in two other files, called from a method, from a block, through a raise that is rescued, from a Fiber, from a Thread and from fifty frames deep; after each return, where the caller is (`caller_locations`' file and label) and its `__method__`.

CHECKED

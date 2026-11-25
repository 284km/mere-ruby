# A for loop's variable on the VM

Asked (note 558): the VM's speed, from the benchmarks where it is furthest from the evaluator. The 33 `so_*` and `app_*` programs of ruby's `benchmark/`, instructions on each:

| | VM / evaluator |
|---|---|
| slowest on the VM | so_spectralnorm 1.13, so_object, so_fasta, so_exception 1.08, so_meteor_contest, so_matrix, so_mandelbrot, app_raise 1.07 |
| fastest on the VM | so_ackermann 0.43, app_answer 0.47, so_partial_sums 0.71, so_nbody 0.73 |

The other 21 are within 0.88 to 1.05, and every output is the same on both.

## so_spectralnorm

Its calls go to the evaluator's call (`ecall_vals`, `ecall_args`) on both executions: the gap was not there. Taken apart, the loop `for j in 0..u.length-1` was. An empty `for` of 250,000 turns cost 4.15 G instructions on the VM and 2.76 G on the evaluator; the same loop written `(0..n).each { |q| j = q }` cost 3.28 G on the VM.

A for loop's block has one parameter in ruby, without has_lead: what `each` gives is bound as to `|x|`, an Array whole.

Both compilers' export for the VM says the parameter (`lead_num`, which `to_a` leaves out for such a block) and not that it is a for loop's. `vm_params` read one required parameter that is not `ambiguous_param0` as `|x,|`: it added the `*,` that spreads an Array. So on the VM

```ruby
for x in [[1, 2], [3]]; p x; end
```

printed `1` and `3` (ruby: `[1, 2]` and `[3]`), and every turn's binding went past the one-store path for a single parameter (`blk_simple1`) through the general one.

## The change

- Both compilers' export for the VM marks a for loop's block: `for` in its parameters, after `ambiguous_param0` (`lib/iseq_compiler_ext.rb`, and `ic/m_ic_export.mere` from the unit's flag 8). `to_a` is unchanged.
- `vm_params` reads it as `ambiguous_param0`: no `*,`.
- `tools/iseq/vm_check.sh` runs the reference as `$REF_RUBY_BIN`, the binary and not rbenv's shim, which adds `RBENV_*` and `RUBYLIB` to the ENV of what it runs (#298's review).

## Numbers

Instructions on the VM, the median of three runs alternating main and this branch:

| program | main | here | the evaluator |
|---|---|---|---|
| `for j in 0..249999; end` | 4.23 G | 3.37 G | 2.76 G |
| the same in a method | 4.25 G | 3.39 G | 2.77 G |
| so_spectralnorm | 614.9 G | 577.9 G | 545.2 G |
| so_mandelbrot | 561.2 G | 529.9 G | 524.7 G |
| so_fasta | 300.0 G | 299.9 G | 278.9 G |
| so_nbody | 518.0 G | 518.3 G | 714.0 G |
| so_binary_trees | 2,394.4 G | 2,394.2 G | 2,449.2 G |

The last three have a `for` loop too, run a few times; their turns are the calls inside.

so_spectralnorm is still above the evaluator's 545 G: a for loop's block on the VM is a block with a frame of its own, from the pool, where the evaluator runs it in the frame around it (`is_for_params`). Not this round's.

## Witnesses

Corpus 827: a for loop's variable over Arrays, nil, an empty Array, a Hash, an `each` that yields several values, one value and none, in a method, read by a block inside the loop, and the several-targets form, which still spreads; and `|v|` and `|v,|` beside it. A vm_check snippet has the same in short.

CHECKED

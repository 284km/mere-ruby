# A for loop's splat target on the evaluator

#300's review found it: on the evaluator, `for *a in o` with `o.each` yielding `1, 2` bound `[1]`, and a bare `yield` bound `[nil]`. Ruby binds `[1, 2]` and `[]`; the VM already did.

## Why

The parser writes a for loop as `each` with a block. A splat target alone was given one parameter, `|__for|`, and the assignment `*a = __for`: a block's one parameter keeps the first of several values and is nil for none.

Ruby's for with a splat target (pm_compile_for_node_index) takes what each gave as a rest parameter. When that is one value which `Array.try_convert` turns into an Array, it uses that Array. Then it assigns. Neither `|x|` nor `|*x|` alone does both: `yield [3, 4]` gives `[3, 4]`, `yield 1, 2` gives `[1, 2]`.

Beside it, a splat on a complex target, `for *h[:z] in o` or `for *s.x in o`, was a SyntaxError on both executions: the for loop's own target reader did not know `*`. In ruby both take the same values as `for *a`.

## The change

- `for *a`, and a splat on an ivar, take `|*__forv|` and, before the assignment, ruby's rule (`for_rest_args`): if `__forv.length == 1` and `::Array.try_convert(__forv[0])` is an Array, that Array. The calls are made, as ruby's sequence makes them.
- The for loop's target reader takes a `*` in front of a target (`parse_for_xtargets`), as a multiple assignment's does. One splat target alone (`for *h[:z]`) goes the same way as `for *a`.

## Left as it was

Several complex targets keep main's way on the evaluator, and a splat among them stays a SyntaxError on both:

- `for s.x, b in [[1, 2]]`: ruby 4.0 sends the writer to one of the values (`2.x = 1`). The VM runs ruby's sequence and does the same; the evaluator binds `[[1, 2], nil]`, as on main. Matching ruby's way on the evaluator is a separate item.
- `for h[:k], *c in o`: ruby raises NoMethodError (`[]=` sent to a Symbol, the same way). Taking it on the evaluator in another way would make the two executions differ where they now agree.

## Witnesses

Corpus 830: `for *a` over several values, one Array, one value, none, an Array of an Array and nil, with the variable after the loop;
`for x, *y` and `for (d, e)` beside it; a splat on an index, an attribute and an ivar; an object whose `to_ary` answers, alone and in an Array; a loop that does not run; and the locals of a method with such a loop. It matches ruby on both executions; on main the evaluator differs on the first and both refuse the splat targets.

CHECKED

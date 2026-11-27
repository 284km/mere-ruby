# #351's review: a String key's encoding in the hash index, and group_by past a program's Hash#[]

Two findings on #351 (Enumerable#group_by grows each group in place).

## A String key's digest

`[[], "ab".force_encoding("UTF-16LE"), "ab".b].group_by(&:itself)` made 2 groups where ruby makes 3.
It was not group_by's: `h = {[] => 1}; h[u16] = 2; h[bin] = 3; h.size` was 2 as well, wherever a hash had its index.
`hkey_digest` wrote a String as `"s" ++ bytes`, and two Strings are eql? only when their encodings are comparable too (rb_str_comparable, our `str_comparable`).

The class that compares by bytes alone is every UTF-8 String, every ASCII-only one in an ASCII-compatible encoding, and the empty one: `str_comparable` says yes for any two of them.
A String outside it now carries its encoding: `"S" ++ encoding ++ ":" ++ bytes`.
`hkey_str_enc_fwd` answers which, memoised per encoding index; a String with no entry in `str_enc` (UTF-8) pays one `map_has`.

## group_by and a program's Hash#[]

After the list of plain keys spilled into the Hash, a key that is not plain went through `invoke_val_c "[]"` and `"[]="`, which dispatched a program's own `Hash#[]` and `#[]=`.
ruby's group_by calls `rb_hash_aref` / `rb_hash_aset`.
It now finds and stores the way the builtin doors do: `hash_touch` and `hash_lookup_w` for a key with its own `#hash`, the index otherwise; `hash_store_key` and `hput_or_queue_w` for the store.

## Checked

Instructions retired, `MERE_RUBY_GC_TIGHT=1`, the median of 3, Mere 9dec2ff6; before #351 (b7d90d5c) / main (3fbe3921) / this:

| | before #351 | main | this |
|---|---|---|---|
| group_by, 10 elements, 3 keys (20,000 times) | 3.822 G | 3.687 G | 3.688 G |
| group_by, 100 elements, 100 keys (2,000 times) | 5.606 G | 3.549 G | 3.548 G |
| group_by with Array keys | 2.501 G | 2.716 G | 2.262 G |
| a Hash of 2,000 UTF-8 String keys | 4.305 G | 4.314 G | 4.330 G |
| a Hash of 2,000 binary String keys | 4.339 G | 4.342 G | 4.435 G |

The binary keys' +2.1% is the price of the right answer (the encoding's check per digest); keyed by the encoding's name it was 4.5%, by its index 2.6%, and with the ASCII-only check first 2.1%.
#351's Array-key group_by was 8.6% over before #351, through the doors; this puts it 9.6% under.

Corpus 1070 gets both cases, on the evaluator and the VM with the index on and off.

## The corpus

On main 3fbe3921, with `MERE_RUBY_SHAPES_CHECK=1`: 993/993 on the evaluator and on the VM, the hash index on and off.

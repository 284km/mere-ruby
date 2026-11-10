#!/usr/bin/env python3
"""Bound lexer stack use in the single-threaded Wasm source copy.

The native lexer builds Cons(token, lex(rest)) on its large C stack. In Wasm
each recursive call also reserves the lexer's many locals. Collect one piece
at a time, preserving the original lexer and its nested interpolation calls.
"""
from pathlib import Path
import sys

path = Path(sys.argv[1]) / 'm_parse.mere'
source = path.read_text()
anchor = 'let rec lex_go = fn (s: str) -> fn (i: int) ->\n'
assert source.count(anchor) == 1
wrapper = '''let wasm_lex_source = map_new ();
let wasm_lex_position = map_new ();
let rec wasm_lex_reverse = fn (xs: Tok list) -> fn (acc: Tok list) ->
  match xs with Nil -> acc | Cons (h, t) -> wasm_lex_reverse t (Cons (h, acc))
and lex_go = fn (s: str) -> fn (i: int) ->
  if map_has wasm_lex_source 0 && str_eq (map_get wasm_lex_source 0) s
     && i > map_get wasm_lex_position 0 then
    (let _ = map_set wasm_lex_position 1 i in (Nil : Tok list))
  else
    let had = map_has wasm_lex_source 0 in
    let old_s = (if had then map_get wasm_lex_source 0 else "") in
    let old_i = (if had then map_get wasm_lex_position 0 else 0) in
    let old_n = (if had then map_get wasm_lex_position 1 else 0 - 1) in
    let _ = map_set wasm_lex_source 0 s in
    let result = wasm_lex_collect s i (Nil : Tok list) in
    let _ = (if had then map_set wasm_lex_source 0 old_s else map_delete wasm_lex_source 0) in
    let _ = map_set wasm_lex_position 0 old_i in
    let _ = map_set wasm_lex_position 1 old_n in
    result
and wasm_lex_collect = fn (s: str) -> fn (i: int) -> fn (acc: Tok list) ->
  let _ = map_set wasm_lex_position 0 i in
  let _ = map_set wasm_lex_position 1 (0 - 1) in
  let piece = wasm_lex_piece s i in
  let acc = wasm_lex_reverse piece acc in
  let next = map_get wasm_lex_position 1 in
  if next < 0 then wasm_lex_reverse acc (Nil : Tok list)
  else wasm_lex_collect s next acc
and wasm_lex_piece = fn (s: str) -> fn (i: int) ->
'''
source = source.replace(anchor, wrapper)
start = source.index('let rec tc_strip =')
end = source.index('\n// CRLF', start)
source = source[:start] + '''let rec wasm_tc_strip = fn toks -> fn (t: int) -> fn (pend: int list) -> fn (acc: Tok list) ->
  match toks with
  | Nil -> wasm_lex_reverse acc Nil
  | Cons (TCont k, r) -> wasm_tc_strip r t (tc_rep k t pend) acc
  | Cons (TNL o, r) -> (let _ = tc_keep (str_of_int o) t pend in wasm_tc_strip r 0 Nil (Cons (TNL o, acc)))
  | Cons (TEOF, r) -> (let _ = tc_keep "eof" t pend in wasm_tc_strip r 0 Nil (Cons (TEOF, acc)))
  | Cons (x, r) -> wasm_tc_strip r (t + 1) pend (Cons (x, acc));
let tc_strip = fn toks -> fn (t: int) -> fn (pend: int list) -> wasm_tc_strip toks t pend Nil;
''' + source[end:]
start = source.index('let rec number_nls_go =')
end = source.index('\n// `eval(code', start)
source = source[:start] + '''let rec wasm_number_nls = fn (s: str) -> fn toks -> fn (off: int) -> fn (line: int) -> fn (acc: Tok list) ->
  match toks with
  | Nil -> wasm_lex_reverse acc Nil
  | Cons (TNL o, r) ->
    let ln = line + nl_count_to s off o 0 in
    let _ = tc_number (str_of_int o) ln in
    wasm_number_nls s r (if o > off then o else off) ln (Cons (TNL ln, acc))
  | Cons (t, r) -> wasm_number_nls s r off line (Cons (t, acc));
let number_nls_go = fn (s: str) -> fn toks -> fn (off: int) -> fn (line: int) -> wasm_number_nls s toks off line Nil;
''' + source[end:]
path.write_text(source)

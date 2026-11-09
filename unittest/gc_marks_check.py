#!/usr/bin/env python3
"""Exercise the production packed GC set at word boundaries and sparse IDs."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
MERE = os.environ.get("MERE", str(ROOT / ".mere-compiler/_build/default/bin/mere.exe"))
source = (ROOT / "main.mere").read_text()
start = source.index("let gc_live_has =")
end = source.index("let rec gc_mark_val =", start)
helpers = source[start:end]
probe = r'''let ensure = fn (yes: bool) -> if yes then () else fail "GC mark mismatch";
let live = map_new ();
let other = map_new ();
let reference = map_new ();
let check = fn (key: int) ->
  let _ = ensure (gc_live_has live key == map_has reference key) in
  let _ = ensure (if gc_live_has other key then false else true) in
  let fresh = (if map_has reference key then false else true) in
  let _ = ensure (gc_live_mark live key == fresh) in
  let _ = ensure (if gc_live_mark live key then false else true) in
  let _ = gc_live_add live key in
  let _ = map_set reference key 1 in
  ensure (gc_live_has live key);
let rec fill = fn (i: int) ->
  if i == 10000 then () else (let _ = check i in fill (i + 1));
let _ = fill 0;
let rec gaps = fn (i: int) ->
  if i == 1000 then () else
    (let key = 1000000000000 + i * 61 in
     let _ = ensure (if gc_live_has live (key + 1) then false else true) in
     let _ = check key in gaps (i + 1));
let _ = gaps 0;
let _ = check 4611686018427387903;
let _ = check 4611686018427387902;
let _ = check 29;
let _ = check 30;
let _ = check 59;
let _ = check 60;
let _ = ensure (gc_live_count live == map_len reference);
let _ = ensure (map_len live < 1400);
let _ = ensure (gc_live_count other == 0);
let _ = gc_live_add other 30;
let _ = ensure (gc_live_count other == 1);
let dense = map_new ();
let rec kinds = fn (kind: int) ->
  if kind == 8 then () else
  let rec ids = fn (id: int) ->
    if id == 3000 then () else
    let _ = ensure (gc_live_mark dense (id * 8 + kind)) in
    let _ = ensure (if kind == 7 then true else (if gc_live_has dense (id * 8 + kind + 1) then false else true)) in
    ids (id + 1) in
  let _ = ids 0 in
  let _ = ensure (map_len dense == (kind + 1) * 100) in
  kinds (kind + 1);
let _ = kinds 0;
let _ = ensure (gc_live_count dense == 24000);
let _ = print "packed GC marks: boundaries, sparse IDs, duplicates and independent sets";
'''
with tempfile.TemporaryDirectory(prefix="mere-gc-marks-") as folder:
    folder = Path(folder)
    main = folder / "marks.mere"
    main.write_text(helpers + probe)
    generated = subprocess.run([MERE, "-c", str(main)], capture_output=True)
    assert generated.returncode == 0, generated.stderr.decode()
    cfile = folder / "marks.c"
    cfile.write_bytes(generated.stdout)
    for name, flags in (("O2", ["-O2"]), ("ASan", ["-O1", "-fsanitize=address,undefined", "-fno-omit-frame-pointer"])):
        binary = folder / name
        subprocess.run(["clang", *flags, "-w", "-fbracket-depth=1024", str(cfile), "-lm", "-o", str(binary)], check=True)
        result = subprocess.run([str(binary)], capture_output=True, check=True, timeout=30,
                                env=dict(os.environ, ASAN_OPTIONS="detect_leaks=0"))
        assert result.stdout == b"packed GC marks: boundaries, sparse IDs, duplicates and independent sets\n", result.stdout
        print(name + ": " + result.stdout.decode().strip())

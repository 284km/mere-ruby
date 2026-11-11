#!/usr/bin/env python3
"""Exercise packed marks and the production class/constant ownership parsers."""
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
MERE = os.environ.get("MERE", str(ROOT / ".mere-compiler/_build/default/bin/mere.exe"))
source = (ROOT / "main.mere").read_text()
start = source.index("let gc_live_new =")
end = source.index("let rec gc_mark_val =", start)
helpers = source[start:end]
owner_helpers = source[source.index("let rec gc_class_base ="):source.index("let gc_source_owner =")]
state = (ROOT / "m_state.mere").read_text()
identity_helper = state[state.index("let rec is_anon_cls ="):state.index("// name_anon (")]
owner_header = """let anonymous_classes = map_new ();
let _ = map_set anonymous_classes "AnonClass_1" 1;
let _ = map_set anonymous_classes "AnonModule_2" 2;
let _ = map_set anonymous_classes "Struct_3" 3;
let _ = map_set anonymous_classes "Refine_M::R_0" 4;
"""
probe = r'''let ensure = fn (yes: bool) -> if yes then () else fail "GC mark mismatch";
let live = gc_live_new ();
let other = gc_live_new ();
let reference = map_new ();
let check = fn (key: int) ->
  let _ = ensure (gc_live_has live key == map_has reference key) in
  let _ = ensure (if gc_live_has other key then false else true) in
  let fresh = (if map_has reference key then false else true) in
  let _ = ensure (gc_live_mark live key == fresh) in
  let _ = ensure (if gc_live_mark live key then false else true) in
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
let _ = (let (pages, words, _) = live in
  let _ = ensure (map_len pages < 100) in ensure (vec_len words == map_len pages * 64));
let _ = ensure (gc_live_count other == 0);
let _ = ensure (gc_live_mark other 30);
let _ = ensure (gc_live_count other == 1);
let dense = gc_live_new ();
let rec kinds = fn (kind: int) ->
  if kind == 8 then () else
  let rec ids = fn (id: int) ->
    if id == 3000 then () else
    let _ = ensure (gc_live_mark dense (id * 8 + kind)) in
    let _ = ensure (if kind == 7 then true else (if gc_live_has dense (id * 8 + kind + 1) then false else true)) in
    ids (id + 1) in
  let _ = ids 0 in
  let _ = (let (pages, words, _) = dense in
    let _ = ensure (map_len pages == (kind + 1) * 2) in
    ensure (vec_len words == (kind + 1) * 128)) in
  kinds (kind + 1);
let _ = kinds 0;
let _ = ensure (gc_live_count dense == 24000);
let nested = gc_live_new ();
let _ = region Scratch {
  let _ = ensure (gc_live_mark nested 1000000000007) in
  let _ = ensure (gc_live_mark nested 80000) in
  ()
};
let _ = ensure (gc_live_has nested 1000000000007);
let _ = ensure (gc_live_has nested 80000);
let _ = ensure (gc_live_count nested == 2);
let _ = print "packed GC marks: boundaries, sparse IDs, duplicates and independent sets";
'''
owner_probe = r'''let check_owner = fn (key: str) -> fn (expected: str) ->
  if str_eq (gc_class_owner key) expected then () else fail ("class owner mismatch: " ++ key);
let check_const = fn (key: str) -> fn (expected: str) ->
  if str_eq (gc_const_owner key) expected then () else fail ("constant owner mismatch: " ++ key);
let _ = check_owner "AnonClass_1#answer" "AnonClass_1";
let _ = check_owner "(sng:(sng:AnonClass_1))#answer" "AnonClass_1";
let _ = check_owner "AnonClass_1::Nested#answer" "AnonClass_1";
let _ = check_owner "cls:AnonClass_1@state" "AnonClass_1";
let _ = check_owner ("AnonClass_1#answer" ++ chr 9 ++ "lookup") "AnonClass_1";
let _ = check_owner "Refine_M::R_0#answer" "Refine_M::R_0";
let _ = check_owner "Refine_M::R_0::Nested#answer" "Refine_M::R_0";
let _ = check_owner "AnonClass_User#answer" "";
let _ = check_owner "AnonModule_User::State" "";
let _ = check_owner "Struct_User#answer" "";
let _ = check_owner "Refine_User#answer" "";
let _ = check_const "AnonClass_1" "";
let _ = check_const "AnonModule_2" "";
let _ = check_const "Refine_M::R_0" "";
let _ = check_const "AnonClass_1::State" "AnonClass_1";
let _ = check_const "(sng:AnonClass_1)::State" "AnonClass_1";
let _ = check_const "AnonClass_1::Nested::State" "AnonClass_1";
let _ = check_const "Refine_M::R_0::State" "Refine_M::R_0";
let _ = check_const "Refine_M::R_0::Nested::State" "Refine_M::R_0";
let _ = check_const "AnonClass_User::State" "";
let _ = ensure (is_anon_cls "AnonClass_1::Nested");
let _ = ensure (is_anon_cls "Refine_M::R_0::Nested");
let _ = ensure (if is_anon_cls "AnonClass_User" then false else true);
let _ = ensure (if is_anon_cls "Refine_User" then false else true);
'''
with tempfile.TemporaryDirectory(prefix="mere-gc-marks-") as folder:
    folder = Path(folder)
    main = folder / "marks.mere"
    main.write_text(owner_header + identity_helper + owner_helpers + helpers + probe + owner_probe)
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

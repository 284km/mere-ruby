# Unowned RED inventory before cause-specific fixes

## Evidence and scope

Inventory retrieved on 2026-11-25 from main CI run
[45383249482](https://github.com/284km/mere-ruby/actions/runs/45383249482),
main commit `3e14a977f19b2c54d4f6012129ea0889d9e55f18`.
Artifact `unittest-report` ID `14940368797` supplies `files.tsv` and
`summary.json`; its eight `unittest-shard-*` artifacts supply the exact case
names and diagnostic logs. It is the newest completed main CI run with a
complete unittest report at retrieval time. Newer completed runs are cancelled
or lack the aggregate report (for example failure run 45469715861 has only
seven unittest shards). Do not substitute a PR-branch report.

The archived reference is Ruby 4.0.9, revision `3e93b23afc`, **not** the
requested 4.0.10. These are historical REDs to reproduce; they are not claims
about current main against 4.0.10. All fixes use a clean 4.0.10, revision
`a704b7cd95`, through `tools/ref_ruby.sh`. No reference gems are installed.
Archived aggregate: 34,507 cases; 33,604 MATCH; 750 RED; 131 BOTH; 22 EXTRA.
No full unit or Rails component suite is authorized or run for this inventory.

Excluded from the table: `test/-ext-/*`, YJIT/ZJIT (including
`ruby/test_yjit*.rb` and `ruby/test_zjit.rb`), `ruby/test_allocation.rb`, and
`ruby/test_gc.rb`. The CI manifest contains no Rails component tests.
A2 and already-owned Time/AST/C API/VM cases are explicitly separated below.
Case status is the artifact's status, including S (skip difference), T
(timeout/resource), and ABSENT/X (incomplete suite); RED is not synonymous
with a failing assertion.

## Cause groups and disposition

These are initial groups based on archived diagnostics. A proposed cause is
not accepted as a fix until reproduced against current main and clean 4.0.10
on both engines. Resource cases must use `MERE_RUBY_GC_TIGHT=1`, `--seed=1`
and process-family RSS where the test spawns children. No budgets, exclusions,
or assertion counts may be relaxed to improve the table.

| Group | Cases | Disposition |
| --- | ---: | --- |
| A2 | 39 | Owned here; after B/A3. |
| AST | 1 | Transfer to AST stream. |
| BOX | 1 | Reproduce one file at a time, then one PR per confirmed cause. |
| CAPACITY | 2 | Reproduce one file at a time, then one PR per confirmed cause. |
| CAPI | 6 | Transfer to C API stream. |
| CARGO | 4 | Reproduce one file at a time, then one PR per confirmed cause. |
| CONT | 2 | Reproduce one file at a time, then one PR per confirmed cause. |
| GC | 24 | Reproduce one file at a time, then one PR per confirmed cause. |
| LOAD | 1 | Reproduce one file at a time, then one PR per confirmed cause. |
| NUM | 9 | Reproduce one file at a time, then one PR per confirmed cause. |
| RSS | 9 | Reproduce one file at a time, then one PR per confirmed cause. |
| STRSCAN | 2 | Reproduce one file at a time, then one PR per confirmed cause. |
| TIME | 42 | Already owned; notify Time stream. |
| TRACE | 2 | Reproduce one file at a time, then one PR per confirmed cause. |
| VM | 10 | Transfer to VM stream. |

## Exact archived RED cases

| Group | File under `test/` | Test | Status | Diagnostic/candidate cause |
| --- | --- | --- | --- | --- |
| CAPI | `cgi/test_cgi_escape.rb` | `CGIEscapeNativeExtTest#test_escape_html_allocates_same_as_escapeHTML` | S | Native implementation/source_location, linkage, or forced-bignum representation; transfer to C API stream. |
| CAPI | `cgi/test_cgi_escape.rb` | `CGIEscapeNativeExtTest#test_escape_html_uses_native_implementation` | S | Native implementation/source_location, linkage, or forced-bignum representation; transfer to C API stream. |
| CAPI | `erb/test_erb.rb` | `TestERB#test_html_escape_extension` | F | Native implementation/source_location, linkage, or forced-bignum representation; transfer to C API stream. |
| A2 | `error_highlight/test_error_highlight.rb` | `ErrorHighlightTest#test_CALL_aref_1` | F | Parser event/location or highlight; investigate after B and A3. |
| A2 | `error_highlight/test_error_highlight.rb` | `ErrorHighlightTest#test_CALL_aref_2` | F | Parser event/location or highlight; investigate after B and A3. |
| A2 | `error_highlight/test_error_highlight.rb` | `ErrorHighlightTest#test_CALL_aref_3` | F | Parser event/location or highlight; investigate after B and A3. |
| A2 | `error_highlight/test_error_highlight.rb` | `ErrorHighlightTest#test_CALL_aref_5` | F | Parser event/location or highlight; investigate after B and A3. |
| A2 | `error_highlight/test_error_highlight.rb` | `ErrorHighlightTest#test_OP_ASGN1_aref_1` | F | Parser event/location or highlight; investigate after B and A3. |
| A2 | `error_highlight/test_error_highlight.rb` | `ErrorHighlightTest#test_OP_ASGN1_aref_2` | F | Parser event/location or highlight; investigate after B and A3. |
| A2 | `error_highlight/test_error_highlight.rb` | `ErrorHighlightTest#test_OP_ASGN1_aref_4` | F | Parser event/location or highlight; investigate after B and A3. |
| A2 | `error_highlight/test_error_highlight.rb` | `ErrorHighlightTest#test_OP_CDECL_toplevel_2` | F | Parser event/location or highlight; investigate after B and A3. |
| A2 | `error_highlight/test_error_highlight.rb` | `ErrorHighlightTest#test_VCALL_2` | F | Parser event/location or highlight; investigate after B and A3. |
| A2 | `error_highlight/test_error_highlight.rb` | `ErrorHighlightTest#test_args_ATTRASGN_3` | F | Parser event/location or highlight; investigate after B and A3. |
| A2 | `error_highlight/test_error_highlight.rb` | `ErrorHighlightTest#test_args_OP_ASGN1_aref_2` | F | Parser event/location or highlight; investigate after B and A3. |
| A2 | `error_highlight/test_error_highlight.rb` | `ErrorHighlightTest#test_spoofed_filename` | F | Parser event/location or highlight; investigate after B and A3. |
| CAPI | `mkmf/test_have_library.rb` | `TestMkmfHaveLibrary#test_have_library` | F | Native implementation/source_location, linkage, or forced-bignum representation; transfer to C API stream. |
| CAPI | `mkmf/test_have_library.rb` | `TestMkmfHaveLibrary#test_have_library_with_name` | F | Native implementation/source_location, linkage, or forced-bignum representation; transfer to C API stream. |
| GC | `objspace/test_objspace.rb` | `TestObjSpace#test_count_symbols` | F | GC/ObjectSpace/representation semantics; confirm against 4.0.10 before changing or transferring. |
| GC | `objspace/test_objspace.rb` | `TestObjSpace#test_count_tdata_objects` | F | GC/ObjectSpace/representation semantics; confirm against 4.0.10 before changing or transferring. |
| GC | `objspace/test_objspace.rb` | `TestObjSpace#test_dump_all` | F | GC/ObjectSpace/representation semantics; confirm against 4.0.10 before changing or transferring. |
| GC | `objspace/test_objspace.rb` | `TestObjSpace#test_load_allocation_path_compile_file` | F | GC/ObjectSpace/representation semantics; confirm against 4.0.10 before changing or transferring. |
| GC | `objspace/test_objspace.rb` | `TestObjSpace#test_load_allocation_path_load` | F | GC/ObjectSpace/representation semantics; confirm against 4.0.10 before changing or transferring. |
| GC | `objspace/test_objspace.rb` | `TestObjSpace#test_memsize_of` | F | GC/ObjectSpace/representation semantics; confirm against 4.0.10 before changing or transferring. |
| GC | `objspace/test_objspace.rb` | `TestObjSpace#test_memsize_of_iseq` | F | GC/ObjectSpace/representation semantics; confirm against 4.0.10 before changing or transferring. |
| GC | `objspace/test_objspace.rb` | `TestObjSpace#test_trace_object_allocations` | F | GC/ObjectSpace/representation semantics; confirm against 4.0.10 before changing or transferring. |
| RSS | `objspace/test_ractor.rb` | `TestObjSpaceRactor#test_copy_finalizer` | T | Resource/leak assertion or timeout; fixed-seed tight-GC reproduction required. |
| AST | `prism/magic_comment_test.rb` | `Prism::MagicCommentTest#test_spanning_heredoc.txt` | E | Prism magic-comment location; transfer to AST stream. |
| A2 | `ripper/test_lexer.rb` | `TestRipper::Lexer#test_heredoc_no_memory_leak` | T | Parser event/location or highlight; investigate after B and A3. |
| A2 | `ripper/test_lexer.rb` | `TestRipper::Lexer#test_heredoc_unterminated_interpolation` | F | Parser event/location or highlight; investigate after B and A3. |
| A2 | `ripper/test_lexer.rb` | `TestRipper::Lexer#test_invalid_escape_string` | F | Parser event/location or highlight; investigate after B and A3. |
| A2 | `ripper/test_lexer.rb` | `TestRipper::Lexer#test_lexer_scan_with_syntax_error` | F | Parser event/location or highlight; investigate after B and A3. |
| A2 | `ripper/test_lexer.rb` | `TestRipper::Lexer#test_raise_errors_keyword` | F | Parser event/location or highlight; investigate after B and A3. |
| A2 | `ripper/test_lexer.rb` | `TestRipper::Lexer#test_token_aftr_error_heredoc` | F | Parser event/location or highlight; investigate after B and A3. |
| A2 | `ripper/test_lexer.rb` | `TestRipper::Lexer#test_trailing_on_embexpr_end` | F | Parser event/location or highlight; investigate after B and A3. |
| A2 | `ripper/test_parser_events.rb` | `TestRipper::ParserEvents#test_blockarg` | F | Parser event/location or highlight; investigate after B and A3. |
| A2 | `ripper/test_parser_events.rb` | `TestRipper::ParserEvents#test_heredoc` | F | Parser event/location or highlight; investigate after B and A3. |
| A2 | `ripper/test_parser_events.rb` | `TestRipper::ParserEvents#test_ignored_nl` | F | Parser event/location or highlight; investigate after B and A3. |
| A2 | `ripper/test_parser_events.rb` | `TestRipper::ParserEvents#test_return_out_of_compile_error_no_memory_leak` | T | Parser event/location or highlight; investigate after B and A3. |
| A2 | `ripper/test_parser_events.rb` | `TestRipper::ParserEvents#test_return_out_of_warn_no_memory_leak` | T | Parser event/location or highlight; investigate after B and A3. |
| A2 | `ripper/test_ripper.rb` | `TestRipper::Ripper#test_no_memory_leak` | T | Parser event/location or highlight; investigate after B and A3. |
| A2 | `ripper/test_ripper.rb` | `TestRipper::Ripper#test_regexp_with_option` | F | Parser event/location or highlight; investigate after B and A3. |
| A2 | `ripper/test_ripper.rb` | `TestRipper::Ripper#test_sexp_no_memory_leak` | T | Parser event/location or highlight; investigate after B and A3. |
| A2 | `ripper/test_ripper.rb` | `TestRipper::Ripper::TestInput#test_no_memory_leak` | T | Parser event/location or highlight; investigate after B and A3. |
| A2 | `ripper/test_ripper.rb` | `TestRipper::Ripper::TestInput#test_regexp_with_option` | F | Parser event/location or highlight; investigate after B and A3. |
| A2 | `ripper/test_ripper.rb` | `TestRipper::Ripper::TestInput#test_sexp_no_memory_leak` | T | Parser event/location or highlight; investigate after B and A3. |
| A2 | `ripper/test_scanner_events.rb` | `TestRipper::ScannerEvents#test_CHAR` | F | Parser event/location or highlight; investigate after B and A3. |
| A2 | `ripper/test_scanner_events.rb` | `TestRipper::ScannerEvents#test_error_token` | F | Parser event/location or highlight; investigate after B and A3. |
| A2 | `ripper/test_scanner_events.rb` | `TestRipper::ScannerEvents#test_gvar` | F | Parser event/location or highlight; investigate after B and A3. |
| A2 | `ripper/test_scanner_events.rb` | `TestRipper::ScannerEvents#test_invalid_char` | E | Parser event/location or highlight; investigate after B and A3. |
| A2 | `ripper/test_scanner_events.rb` | `TestRipper::ScannerEvents#test_invalid_escape` | F | Parser event/location or highlight; investigate after B and A3. |
| A2 | `ripper/test_scanner_events.rb` | `TestRipper::ScannerEvents#test_invalid_hex_escape_regexp` | F | Parser event/location or highlight; investigate after B and A3. |
| A2 | `ripper/test_scanner_events.rb` | `TestRipper::ScannerEvents#test_invalid_hex_escape_string` | F | Parser event/location or highlight; investigate after B and A3. |
| A2 | `ripper/test_scanner_events.rb` | `TestRipper::ScannerEvents#test_words_sep` | F | Parser event/location or highlight; investigate after B and A3. |
| A2 | `ripper/test_sexp.rb` | `TestRipper::Sexp#test_command` | F | Parser event/location or highlight; investigate after B and A3. |
| RSS | `ruby/test_alias.rb` | `TestAlias#test_alias_memory_leak` | T | Resource/leak assertion or timeout; fixed-seed tight-GC reproduction required. |
| CONT | `ruby/test_array.rb` | `TestArray#test_reject_with_callcc` | E | Continuation cannot re-enter Array#reject frame. |
| CONT | `ruby/test_array.rb` | `TestArraySubclass#test_reject_with_callcc` | E | Continuation cannot re-enter Array#reject frame. |
| NUM | `ruby/test_bignum.rb` | `TestBignum#test_aref2` | F | Numeric conversion/radix/float precision/warnings or work-budget difference; reproduce individually. |
| NUM | `ruby/test_bignum.rb` | `TestBignum#test_convert` | F | Numeric conversion/radix/float precision/warnings or work-budget difference; reproduce individually. |
| NUM | `ruby/test_bignum.rb` | `TestBignum#test_digits_for_invalid_base_numbers` | F | Numeric conversion/radix/float precision/warnings or work-budget difference; reproduce individually. |
| NUM | `ruby/test_bignum.rb` | `TestBignum#test_divide` | F | Numeric conversion/radix/float precision/warnings or work-budget difference; reproduce individually. |
| NUM | `ruby/test_bignum.rb` | `TestBignum#test_float_fdiv` | F | Numeric conversion/radix/float precision/warnings or work-budget difference; reproduce individually. |
| NUM | `ruby/test_bignum.rb` | `TestBignum#test_interrupt_during_to_s` | F | Numeric conversion/radix/float precision/warnings or work-budget difference; reproduce individually. |
| CAPI | `ruby/test_bignum.rb` | `TestBignum#test_prepare` | F | Native implementation/source_location, linkage, or forced-bignum representation; transfer to C API stream. |
| NUM | `ruby/test_bignum.rb` | `TestBignum#test_to_f` | F | Numeric conversion/radix/float precision/warnings or work-budget difference; reproduce individually. |
| NUM | `ruby/test_bignum.rb` | `TestBignum#test_to_s2` | F | Numeric conversion/radix/float precision/warnings or work-budget difference; reproduce individually. |
| BOX | `ruby/test_box.rb` | `TestBox#test_prelude_gems_and_loaded_features` | F | Bundled-gem prelude/loaded-feature isolation; related to B13. |
| GC | `ruby/test_eval.rb` | `TestEval#test_outer_local_variable_under_gc_compact_stress` | S | GC/ObjectSpace/representation semantics; confirm against 4.0.10 before changing or transferring. |
| RSS | `ruby/test_hash.rb` | `TestHashOnly#test_replace_memory_leak` | T | Resource/leak assertion or timeout; fixed-seed tight-GC reproduction required. |
| NUM | `ruby/test_integer.rb` | `TestInteger#test_pow` | T | Numeric conversion/radix/float precision/warnings or work-budget difference; reproduce individually. |
| GC | `ruby/test_io.rb` | `TestIO#test_autoclose_false_closed_by_finalizer` | S | GC/ObjectSpace/representation semantics; confirm against 4.0.10 before changing or transferring. |
| GC | `ruby/test_io.rb` | `TestIO#test_autoclose_true_closed_by_finalizer` | S | GC/ObjectSpace/representation semantics; confirm against 4.0.10 before changing or transferring. |
| GC | `ruby/test_io.rb` | `TestIO#test_copy_stream_no_busy_wait` | S | GC/ObjectSpace/representation semantics; confirm against 4.0.10 before changing or transferring. |
| RSS | `ruby/test_io.rb` | `TestIO#test_select_memory_leak` | T | Resource/leak assertion or timeout; fixed-seed tight-GC reproduction required. |
| GC | `ruby/test_io_buffer.rb` | `TestIOBuffer#test_bug_21210` | S | GC/ObjectSpace/representation semantics; confirm against 4.0.10 before changing or transferring. |
| VM | `ruby/test_iseq.rb` | `TestISeq#test_invalid_source_no_memory_leak` | T | ISeq/native VM metadata, crash diagnostics, stack budget, or ISeq resource test; transfer to VM stream. |
| VM | `ruby/test_iseq.rb` | `TestISeq#test_iseq_builtin_to_a` | F | ISeq/native VM metadata, crash diagnostics, stack budget, or ISeq resource test; transfer to VM stream. |
| VM | `ruby/test_iseq.rb` | `TestISeq#test_loading_kwargs_memory_leak` | T | ISeq/native VM metadata, crash diagnostics, stack budget, or ISeq resource test; transfer to VM stream. |
| GC | `ruby/test_method.rb` | `TestMethod#test_hash_does_not_change_after_compaction` | S | GC/ObjectSpace/representation semantics; confirm against 4.0.10 before changing or transferring. |
| RSS | `ruby/test_object.rb` | `TestObject#test_copied_ivar_memory_leak` | T | Resource/leak assertion or timeout; fixed-seed tight-GC reproduction required. |
| GC | `ruby/test_object.rb` | `TestObject#test_max_shape_variation_with_performance_warnings` | F | GC/ObjectSpace/representation semantics; confirm against 4.0.10 before changing or transferring. |
| GC | `ruby/test_object.rb` | `TestObject#test_remove_instance_variable_re_embed` | F | GC/ObjectSpace/representation semantics; confirm against 4.0.10 before changing or transferring. |
| CAPACITY | `ruby/test_optimization.rb` | `TestRubyOptimization#test_string_freeze_saves_memory` | F | String/IO retained capacity or native memsize accounting. |
| GC | `ruby/test_proc.rb` | `TestProc#test_hash_does_not_change_after_compaction` | S | GC/ObjectSpace/representation semantics; confirm against 4.0.10 before changing or transferring. |
| GC | `ruby/test_process.rb` | `TestProcess#test_warmup_frees_pages` | E | GC/ObjectSpace/representation semantics; confirm against 4.0.10 before changing or transferring. |
| GC | `ruby/test_process.rb` | `TestProcess#test_warmup_precompute_string_coderange` | F | GC/ObjectSpace/representation semantics; confirm against 4.0.10 before changing or transferring. |
| GC | `ruby/test_process.rb` | `TestProcess#test_warmup_promote_all_objects_to_oldgen` | F | GC/ObjectSpace/representation semantics; confirm against 4.0.10 before changing or transferring. |
| GC | `ruby/test_process.rb` | `TestProcess#test_warmup_run_major_gc_and_compact` | E | GC/ObjectSpace/representation semantics; confirm against 4.0.10 before changing or transferring. |
| VM | `ruby/test_rubyvm.rb` | `TestRubyVM#test_stat` | E | ISeq/native VM metadata, crash diagnostics, stack budget, or ISeq resource test; transfer to VM stream. |
| VM | `ruby/test_rubyvm.rb` | `TestRubyVM#test_stat_unknown` | F | ISeq/native VM metadata, crash diagnostics, stack budget, or ISeq resource test; transfer to VM stream. |
| GC | `ruby/test_set.rb` | `TC_Set#test_compare_by_identity_compact` | S | GC/ObjectSpace/representation semantics; confirm against 4.0.10 before changing or transferring. |
| TRACE | `ruby/test_settracefunc.rb` | `TestSetTraceFunc#test_lots_of_enabled_tracepoints_ractor_gc` | T | Ractor-local TracePoint semantics; reproduce on both engines before ownership decision. |
| TRACE | `ruby/test_settracefunc.rb` | `TestSetTraceFunc#test_tp_ractor_local_untargeted` | F | Ractor-local TracePoint semantics; reproduce on both engines before ownership decision. |
| RSS | `ruby/test_settracefunc.rb` | `TestSetTraceFunc#test_tracepoint_bmethod_memory_leak` | T | Resource/leak assertion or timeout; fixed-seed tight-GC reproduction required. |
| RSS | `ruby/test_settracefunc.rb` | `TestSetTraceFunc#test_tracepoint_memory_leak` | T | Resource/leak assertion or timeout; fixed-seed tight-GC reproduction required. |
| VM | `ruby/test_stack.rb` | `TestStack#test_relative_stack_sizes` | E | ISeq/native VM metadata, crash diagnostics, stack budget, or ISeq resource test; transfer to VM stream. |
| VM | `ruby/test_stack.rb` | `TestStack#test_vm_stack_size` | F | ISeq/native VM metadata, crash diagnostics, stack budget, or ISeq resource test; transfer to VM stream. |
| CAPACITY | `ruby/test_string_memory.rb` | `TestStringMemory#test_byteslice_postfix_twice` | F | String/IO retained capacity or native memsize accounting. |
| RSS | `ruby/test_syntax.rb` | `TestSyntax#test_invalid_symbol_in_hash_memory_leak` | T | Resource/leak assertion or timeout; fixed-seed tight-GC reproduction required. |
| VM | `ruby/test_vm_dump.rb` | `TestVMDump#test_darwin_invalid_access` | F | ISeq/native VM metadata, crash diagnostics, stack budget, or ISeq resource test; transfer to VM stream. |
| VM | `ruby/test_vm_dump.rb` | `TestVMDump#test_darwin_invalid_call` | F | ISeq/native VM metadata, crash diagnostics, stack budget, or ISeq resource test; transfer to VM stream. |
| VM | `ruby/test_vm_dump.rb` | `TestVMDump#test_darwin_segv_in_syscall` | F | ISeq/native VM metadata, crash diagnostics, stack budget, or ISeq resource test; transfer to VM stream. |
| GC | `ruby/test_weakkeymap.rb` | `TestWeakKeyMap#test_compaction` | S | GC/ObjectSpace/representation semantics; confirm against 4.0.10 before changing or transferring. |
| GC | `ruby/test_weakmap.rb` | `TestWeakMap#test_compaction` | S | GC/ObjectSpace/representation semantics; confirm against 4.0.10 before changing or transferring. |
| CARGO | `rubygems/test_gem_ext_cargo_builder.rb` | `TestGemExtCargoBuilder#test_build_cdylib` | E | Cargo builder child/toolchain or extension integration; reproduce before assigning C API. |
| CARGO | `rubygems/test_gem_ext_cargo_builder.rb` | `TestGemExtCargoBuilder#test_custom_name` | F | Cargo builder child/toolchain or extension integration; reproduce before assigning C API. |
| CARGO | `rubygems/test_gem_ext_cargo_builder.rb` | `TestGemExtCargoBuilder#test_full_integration` | F | Cargo builder child/toolchain or extension integration; reproduce before assigning C API. |
| CARGO | `rubygems/test_gem_ext_cargo_builder.rb` | `TestGemExtCargoBuilder#test_rubygems_cfg_passed_to_rustc` | E | Cargo builder child/toolchain or extension integration; reproduce before assigning C API. |
| LOAD | `rubygems/test_require.rb` | `TestGemRequire#test_activate_via_require_respects_loaded_files` | F | RubyGems activation/load tracking; inspect on current main. |
| RSS | `socket/test_addrinfo.rb` | `TestSocketAddrinfo#test_marshal_memory_leak` | T | Resource/leak assertion or timeout; fixed-seed tight-GC reproduction required. |
| STRSCAN | `strscan/test_stringscanner.rb` | `TestStringScanner#test_charpos_not_use_string_methods` | E | Ruby shim calls overridable String methods that the native scanner bypasses. |
| STRSCAN | `strscan/test_stringscanner.rb` | `TestStringScannerFixedAnchor#test_charpos_not_use_string_methods` | E | Ruby shim calls overridable String methods that the native scanner bypasses. |
| TIME | `test_time.rb` | `TestTimeExtension#test_completion` | ABSENT | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_completion_with_different_timezone` | ABSENT | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_encode_httpdate` | ABSENT | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_encode_rfc2822` | ABSENT | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_huge_precision` | X | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_invalid` | ABSENT | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_iso8601` | ABSENT | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_iso8601_alias` | ABSENT | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_iso8601_encode` | ABSENT | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_iso8601_fraction` | ABSENT | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_iso8601_leap_second` | ABSENT | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_iso8601_nsec` | ABSENT | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_nsec` | X | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_parse_fraction` | ABSENT | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_parse_leap_second` | ABSENT | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_parse_now_nil` | ABSENT | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_parse_offset_hour_minute_second` | ABSENT | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_parse_with_various_object` | ABSENT | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_rfc2616` | ABSENT | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_rfc2822` | ABSENT | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_rfc2822_leap_second` | ABSENT | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_rfc2822_nonlinear` | X | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_rfc2822_ractor` | ABSENT | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_rfc2822_utc_roundtrip_summer` | ABSENT | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_rfc2822_utc_roundtrip_winter` | X | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_rfc822` | ABSENT | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_ruby_talk_152866` | ABSENT | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_strptime` | ABSENT | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_strptime_Ymd_z` | X | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_strptime_empty` | ABSENT | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_strptime_j` | ABSENT | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_strptime_p` | ABSENT | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_strptime_s_N` | ABSENT | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_strptime_s_z` | ABSENT | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_strptime_wuvg` | ABSENT | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_xmlschema` | ABSENT | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_xmlschema_alias` | ABSENT | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_xmlschema_encode` | ABSENT | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_xmlschema_fraction` | ABSENT | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_xmlschema_leap_second` | ABSENT | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_xmlschema_nsec` | ABSENT | Library time suite already owned by Rails/VM time stream; notify owner. |
| TIME | `test_time.rb` | `TestTimeExtension#test_zone_0000` | X | Library time suite already owned by Rails/VM time stream; notify owner. |

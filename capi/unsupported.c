/* Functions an extension can be compiled against that this C API does not
 * provide. Each is here so that the extension LOADS -- one missing symbol
 * otherwise refuses a whole library, and with it every function in it that
 * does work -- and each raises NotImplementedError, naming itself, when it
 * is called. Nothing here answers.
 *
 * This file is the ledger of what is missing: a function leaves it when it
 * is written. It does not include ruby.h (the prototypes there differ from
 * the one shape every stub has).
 *
 * The groups, and why each is not there:
 *   - bignum algorithms by name (rb_big_mul_toom3, ...): CRuby's internal
 *     routines, exported for its own tests. This interpreter's Integer has
 *     one multiplication; calling it by another's name would be a claim.
 *   - TracePoint from C, the debug inspector, profile frames, postponed
 *     jobs, internal thread event hooks, the bug reporter, ISeq loading:
 *     the VM's own structures.
 *   - memory views, the Random interface, encoding converters: not written
 *     yet.
 */
extern void mr_unsupported_symbol(const char *name) __attribute__((__noreturn__));
#define UNSUPPORTED(name) void name(void) { mr_unsupported_symbol(#name); }

/* CRuby's internal bignum routines */
UNSUPPORTED(rb_big_divrem_normal) UNSUPPORTED(rb_big_mul_balance) UNSUPPORTED(rb_big_mul_karatsuba)
UNSUPPORTED(rb_big_mul_normal) UNSUPPORTED(rb_big_mul_toom3) UNSUPPORTED(rb_big_new)
UNSUPPORTED(rb_big_sq_fast) UNSUPPORTED(rb_big2str_generic) UNSUPPORTED(rb_big2str_poweroftwo)
UNSUPPORTED(rb_str2big_karatsuba) UNSUPPORTED(rb_str2big_normal) UNSUPPORTED(rb_str2big_poweroftwo)
UNSUPPORTED(rb_gcd_normal)
/* the VM's own structures */
UNSUPPORTED(rb_tracepoint_new) UNSUPPORTED(rb_tracepoint_enable) UNSUPPORTED(rb_tracepoint_disable)
UNSUPPORTED(rb_tracearg_from_tracepoint) UNSUPPORTED(rb_tracearg_event_flag) UNSUPPORTED(rb_tracearg_object)
UNSUPPORTED(rb_debug_inspector_open) UNSUPPORTED(rb_debug_inspector_backtrace_locations)
UNSUPPORTED(rb_debug_inspector_frame_binding_get) UNSUPPORTED(rb_debug_inspector_frame_class_get)
UNSUPPORTED(rb_debug_inspector_frame_iseq_get) UNSUPPORTED(rb_debug_inspector_frame_self_get)
UNSUPPORTED(rb_profile_frames) UNSUPPORTED(rb_profile_thread_frames)
UNSUPPORTED(rb_profile_frame_absolute_path) UNSUPPORTED(rb_profile_frame_base_label)
UNSUPPORTED(rb_profile_frame_classpath) UNSUPPORTED(rb_profile_frame_first_lineno)
UNSUPPORTED(rb_profile_frame_full_label) UNSUPPORTED(rb_profile_frame_label)
UNSUPPORTED(rb_profile_frame_method_name) UNSUPPORTED(rb_profile_frame_path)
UNSUPPORTED(rb_profile_frame_qualified_method_name) UNSUPPORTED(rb_profile_frame_singleton_method_p)
UNSUPPORTED(rb_postponed_job_preregister) UNSUPPORTED(rb_postponed_job_register)
UNSUPPORTED(rb_postponed_job_register_one) UNSUPPORTED(rb_postponed_job_trigger)
UNSUPPORTED(rb_internal_thread_add_event_hook) UNSUPPORTED(rb_internal_thread_remove_event_hook)
UNSUPPORTED(rb_thread_lock_native_thread) UNSUPPORTED(rb_thread_prevent_fork)
UNSUPPORTED(rb_bug_reporter_add) UNSUPPORTED(rb_iseq_load)
/* memory views */
UNSUPPORTED(rb_memory_view_available_p) UNSUPPORTED(rb_memory_view_extract_item_members)
UNSUPPORTED(rb_memory_view_fill_contiguous_strides) UNSUPPORTED(rb_memory_view_get)
UNSUPPORTED(rb_memory_view_get_item) UNSUPPORTED(rb_memory_view_init_as_byte_array)
UNSUPPORTED(rb_memory_view_item_size_from_format) UNSUPPORTED(rb_memory_view_parse_item_format)
UNSUPPORTED(rb_memory_view_register) UNSUPPORTED(rb_memory_view_release)
/* the Random interface */
UNSUPPORTED(rb_random_base_init) UNSUPPORTED(rb_random_mark)
/* encoding converters, and the rest */
UNSUPPORTED(rb_econv_str_append) UNSUPPORTED(rb_marshal_define_compat)
UNSUPPORTED(rb_setup_fake_str) UNSUPPORTED(rb_str_normalize_ospath)

/* Declared as data: an extension that names one links, and finds it empty. */
unsigned long rb_memory_view_exported_object_registry;
const char rb_memory_view_exported_object_registry_data_type[128];
const char rb_random_data_type_1_0[128];

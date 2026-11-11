/* Shared native/Wasm adapter for the pinned ruby/nkf 0.2.0 engine.
 * Local malformed-input bounds fixes are recorded in vendor/nkf/UPSTREAM.json.
 * Option tokenization and API phase ordering derive from ext/nkf/nkf.c at
 * 65506fecfd6bec82552746473bb91899d861a849. See vendor/nkf/LICENSE.txt.
 * No Ruby/Mere pointer survives a conversion phase. Results are borrowed only
 * until mr_nkf_clear_result and must be copied before another Ruby callback.
 */
#include <stddef.h>
#include <stdint.h>
#include <limits.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#if !defined(MR_NKF_WASM)
#include <pthread.h>
#include <setjmp.h>
#endif

enum { NKF_OK = 0, NKF_NO_OUTPUT = 1, NKF_NO_MEMORY = 2,
       NKF_TOO_LARGE = 3, NKF_ENGINE_FAILURE = 4 };
#if defined(MR_NKF_WASM)
typedef int32_t nkf_wire_length;
#define NKF_WIRE_MAX INT32_MAX
#define NKF_TLS
__attribute__((import_module("env"), import_name("mr_nkf_abort")))
extern void mr_nkf_host_abort(int code);
#else
typedef long long nkf_wire_length;
#define NKF_WIRE_MAX LLONG_MAX
#define NKF_TLS _Thread_local
static pthread_mutex_t nkf_lock = PTHREAD_MUTEX_INITIALIZER;
static pthread_once_t nkf_once = PTHREAD_ONCE_INIT;
static NKF_TLS jmp_buf nkf_failure;
#endif
typedef struct { nkf_wire_length len; unsigned char data[]; } nkf_bytes;
static NKF_TLS nkf_bytes *nkf_result;
static NKF_TLS nkf_bytes *nkf_encoding_result, *nkf_base_result;
static NKF_TLS size_t nkf_result_capacity, nkf_result_length;
static NKF_TLS const char *nkf_result_encoding, *nkf_result_base;
static const unsigned char *nkf_input;
static int nkf_input_length, nkf_input_position;

/* Track engine allocations, including partially initialized fixed buffers and
 * MIME lookahead temporaries. A failed phase can release all of them without
 * following partially initialized engine pointers. The list has no fixed cap.
 */
typedef union nkf_allocation nkf_allocation;
union nkf_allocation {
    max_align_t alignment;
    struct { nkf_allocation *previous, *next; size_t size; } record;
};
static nkf_allocation *nkf_allocations;
#if defined(MR_NKF_TEST)
static long long nkf_fail_after = -1;
static size_t nkf_allocation_count;
#endif

_Noreturn static void nkf_fail(int status) {
#if defined(MR_NKF_WASM)
    mr_nkf_host_abort(status);
    __builtin_unreachable();
#else
    longjmp(nkf_failure, status);
#endif
}
static void nkf_test_allocation(void) {
#if defined(MR_NKF_TEST)
    if (nkf_fail_after == 0) nkf_fail(NKF_NO_MEMORY);
    if (nkf_fail_after > 0) --nkf_fail_after;
#endif
}
static void *nkf_checked_malloc(size_t size) {
    if (!size) size = 1;
    if (size > SIZE_MAX - sizeof(nkf_allocation)) nkf_fail(NKF_TOO_LARGE);
    nkf_test_allocation();
    nkf_allocation *p = malloc(sizeof(*p) + size);
    if (!p) nkf_fail(NKF_NO_MEMORY);
    p->record.previous = NULL;
    p->record.next = nkf_allocations;
    p->record.size = size;
    if (nkf_allocations) nkf_allocations->record.previous = p;
    nkf_allocations = p;
#if defined(MR_NKF_TEST)
    ++nkf_allocation_count;
#endif
    return p + 1;
}
static void nkf_checked_free(void *pointer) {
    if (!pointer) return;
    nkf_allocation *p = (nkf_allocation *)pointer - 1;
    if (p->record.previous) p->record.previous->record.next = p->record.next;
    else nkf_allocations = p->record.next;
    if (p->record.next) p->record.next->record.previous = p->record.previous;
    free(p);
#if defined(MR_NKF_TEST)
    --nkf_allocation_count;
#endif
}
static void *nkf_checked_realloc(void *pointer, size_t size) {
    if (!pointer) return nkf_checked_malloc(size);
    if (!size) size = 1;
    if (size > SIZE_MAX - sizeof(nkf_allocation)) nkf_fail(NKF_TOO_LARGE);
    nkf_test_allocation();
    nkf_allocation *old = (nkf_allocation *)pointer - 1;
    nkf_allocation *p = realloc(old, sizeof(*p) + size);
    if (!p) nkf_fail(NKF_NO_MEMORY);
    p->record.size = size;
    if (p->record.previous) p->record.previous->record.next = p;
    else nkf_allocations = p;
    if (p->record.next) p->record.next->record.previous = p;
    return p + 1;
}
static void nkf_clear_result(void) {
    free(nkf_result);
    free(nkf_encoding_result);
    free(nkf_base_result);
    nkf_result = NULL;
    nkf_encoding_result = nkf_base_result = NULL;
    nkf_result_capacity = nkf_result_length = 0;
    nkf_result_encoding = nkf_result_base = NULL;
}
static nkf_bytes *nkf_copy_name(const char *name) {
    if (!name) nkf_fail(NKF_ENGINE_FAILURE);
    size_t length = strlen(name);
    if (length > (size_t)NKF_WIRE_MAX ||
        length > SIZE_MAX - sizeof(nkf_bytes)) nkf_fail(NKF_TOO_LARGE);
    nkf_test_allocation();
    nkf_bytes *value = malloc(sizeof(*value) + length);
    if (!value) nkf_fail(NKF_NO_MEMORY);
    value->len = (nkf_wire_length)length;
    if (length) memcpy(value->data, name, length);
    return value;
}
static void nkf_reserve_result(size_t needed) {
    if (needed > (size_t)NKF_WIRE_MAX ||
        needed > SIZE_MAX - sizeof(nkf_bytes)) nkf_fail(NKF_TOO_LARGE);
    if (nkf_result && needed <= nkf_result_capacity) return;
    size_t capacity = nkf_result_capacity ? nkf_result_capacity : 16;
    while (capacity < needed) {
        if (capacity > (size_t)NKF_WIRE_MAX / 2 ||
            capacity > (SIZE_MAX - sizeof(nkf_bytes)) / 2) {
            capacity = needed;
            break;
        }
        capacity *= 2;
    }
    nkf_test_allocation();
    nkf_bytes *p = realloc(nkf_result, sizeof(*p) + capacity);
    if (!p) nkf_fail(NKF_NO_MEMORY);
    nkf_result = p;
    nkf_result_capacity = capacity;
}
static int nkf_get_input(void) {
    if (nkf_input_position < 0) nkf_fail(NKF_ENGINE_FAILURE);
    return nkf_input_position >= nkf_input_length ? EOF :
        nkf_input[nkf_input_position++];
}
static int nkf_unget_input(void) {
    return --nkf_input_position;
}
static int nkf_put_output(int character) {
    if (character == EOF) return character;
    if (nkf_result_length == SIZE_MAX) nkf_fail(NKF_TOO_LARGE);
    nkf_reserve_result(nkf_result_length + 1);
    nkf_result->data[nkf_result_length++] = (unsigned char)character;
    return character;
}

#undef getc
#undef ungetc
#undef putchar
#define getc(file) nkf_get_input()
#define ungetc(character, file) nkf_unget_input()
#define putchar(character) nkf_put_output(character)
#define malloc(size) nkf_checked_malloc(size)
#define realloc(pointer, size) nkf_checked_realloc(pointer, size)
#define free(pointer) nkf_checked_free(pointer)
#define exit(status) nkf_fail(NKF_ENGINE_FAILURE)
#define PERL_XS 1
#include "nkf_symbols.h"
#include "../vendor/nkf/nkf-utf8/config.h"
#include "../vendor/nkf/nkf-utf8/utf8tbl.c"
#include "../vendor/nkf/nkf-utf8/nkf.c"
#undef getc
#undef ungetc
#undef putchar
#undef malloc
#undef realloc
#undef free
#undef exit

static void nkf_release_engine(void) {
    while (nkf_allocations) nkf_checked_free(nkf_allocations + 1);
    nkf_state = NULL;
    nkf_input = NULL;
    nkf_input_length = nkf_input_position = 0;
}
long long mr_nkf_cleanup(void) {
#if !defined(MR_NKF_WASM)
    pthread_mutex_lock(&nkf_lock);
#endif
    nkf_release_engine();
    nkf_clear_result();
#if !defined(MR_NKF_WASM)
    pthread_mutex_unlock(&nkf_lock);
#endif
    return NKF_OK;
}
/* Native host diagnostics; not part of the Ruby module's public API. */
long long mr_nkf_owned_allocations(void) {
#if !defined(MR_NKF_WASM)
    pthread_mutex_lock(&nkf_lock);
#endif
    long long count = 0;
    for (nkf_allocation *p = nkf_allocations; p; p = p->record.next) ++count;
#if !defined(MR_NKF_WASM)
    pthread_mutex_unlock(&nkf_lock);
#endif
    return count;
}
#if !defined(MR_NKF_WASM)
static void nkf_at_exit(void) { (void)mr_nkf_cleanup(); }
static void nkf_register_cleanup(void) { (void)atexit(nkf_at_exit); }
#endif
typedef int (*nkf_phase)(void *);
static int nkf_run_phase(nkf_phase function, void *argument) {
#if !defined(MR_NKF_WASM)
    pthread_once(&nkf_once, nkf_register_cleanup);
    pthread_mutex_lock(&nkf_lock);
    int failed = setjmp(nkf_failure);
    if (failed) {
        nkf_release_engine();
        nkf_clear_result();
        pthread_mutex_unlock(&nkf_lock);
        return failed;
    }
#endif
    int result = function(argument);
    if (result != NKF_OK) nkf_clear_result();
    /* Retain the consumed-input counter for nested source coercion semantics,
     * but never retain the borrowed input pointer outside the atomic phase. */
    nkf_input = NULL;
    nkf_input_length = 0;
#if !defined(MR_NKF_WASM)
    pthread_mutex_unlock(&nkf_lock);
#endif
    return result;
}

/* Exact upstream tokenization, including its 255-byte partial-option limit.
 * The Ruby wrapper deliberately ignores the tokenizer's return value.
 */
static void nkf_parse_options(const char *arg) {
    unsigned char option[256];
    int i = 0, j = 0, escaped = FALSE, single = FALSE, quoted = FALSE;
    for (i = 0; arg[i]; ++i) {
        if (j == 255) return;
        if (single) {
            if (arg[i] == '\'') single = FALSE;
            else option[j++] = arg[i];
        } else if (escaped) {
            escaped = FALSE; option[j++] = arg[i];
        } else if (arg[i] == '\\') escaped = TRUE;
        else if (quoted) {
            if (arg[i] == '"') quoted = FALSE;
            else option[j++] = arg[i];
        } else if (arg[i] == '\'') single = TRUE;
        else if (arg[i] == '"') quoted = TRUE;
        else if (arg[i] == ' ') { option[j] = '\0'; options(option); j = 0; }
        else option[j++] = arg[i];
    }
    if (j) { option[j] = '\0'; options(option); }
}
static int nkf_reset_phase(void *argument) {
    reinit();
    if (*(long long *)argument) nkf_input_position = 0;
    return NKF_OK;
}
long long mr_nkf_reset(long long guessing) {
    return nkf_run_phase(nkf_reset_phase, &guessing);
}
static int nkf_options_phase(void *argument) {
    if (!nkf_state) reinit();
    nkf_parse_options(argument);
    if (!output_encoding) return NKF_NO_OUTPUT;
    switch (nkf_enc_to_index(output_encoding)) {
    case UTF_8_BOM: output_encoding = nkf_enc_from_index(UTF_8); break;
    case UTF_16BE_BOM: output_encoding = nkf_enc_from_index(UTF_16BE); break;
    case UTF_16LE_BOM: output_encoding = nkf_enc_from_index(UTF_16LE); break;
    case UTF_32BE_BOM: output_encoding = nkf_enc_from_index(UTF_32BE); break;
    case UTF_32LE_BOM: output_encoding = nkf_enc_from_index(UTF_32LE); break;
    }
    output_bom_f = FALSE;
    nkf_input_position = 0;
    return NKF_OK;
}
long long mr_nkf_options(const char *options_string) {
    return nkf_run_phase(nkf_options_phase, (void *)options_string);
}
typedef struct { const nkf_bytes *input; int guessing; } nkf_conversion;
static int nkf_convert_phase(void *argument) {
    nkf_conversion *conversion = argument;
    const nkf_bytes *input = conversion->input;
    if (!input || input->len < 0 || input->len > INT_MAX) return NKF_TOO_LARGE;
    if (!nkf_state) reinit();
    nkf_clear_result();
    nkf_reserve_result(0);
    nkf_input = input->data;
    nkf_input_length = (int)input->len;
    /* Do not reset nkf_input_position here: StringValuePtr in the reference
     * can execute a nested conversion after the earlier counter reset. */
    guess_f = conversion->guessing;
    kanji_convert(NULL);
    guess_f = FALSE;
    nkf_result->len = (nkf_wire_length)nkf_result_length;
    if (conversion->guessing) {
        nkf_result_encoding = get_guessed_code();
        nkf_encoding *guessed = nkf_enc_find(nkf_result_encoding);
        nkf_result_base = guessed ?
            nkf_enc_name(nkf_enc_to_base_encoding(guessed)) : nkf_result_encoding;
    } else {
        if (!output_encoding) return NKF_NO_OUTPUT;
        nkf_result_encoding = mimeout_f ? "US-ASCII" : nkf_enc_name(output_encoding);
        nkf_result_base = mimeout_f ? "US-ASCII" :
            nkf_enc_name(nkf_enc_to_base_encoding(output_encoding));
    }
    /* C strings have no Mere length header. Copy names into byte wires inside
     * the protected phase, just like the converted output. */
    nkf_encoding_result = nkf_copy_name(nkf_result_encoding);
    nkf_base_result = nkf_copy_name(nkf_result_base);
    return NKF_OK;
}
long long mr_nkf_convert(const nkf_bytes *input) {
    nkf_conversion conversion = { input, FALSE };
    return nkf_run_phase(nkf_convert_phase, &conversion);
}
long long mr_nkf_guess(const nkf_bytes *input) {
    nkf_conversion conversion = { input, TRUE };
    return nkf_run_phase(nkf_convert_phase, &conversion);
}
const nkf_bytes *mr_nkf_result(void) { return nkf_result; }
const nkf_bytes *mr_nkf_encoding_bytes(void) { return nkf_encoding_result; }
const nkf_bytes *mr_nkf_base_encoding_bytes(void) { return nkf_base_result; }
#if defined(MR_NKF_TEST)
const char *mr_nkf_encoding(void) {
    return nkf_result_encoding ? nkf_result_encoding : "ASCII-8BIT";
}
const char *mr_nkf_base_encoding(void) {
    return nkf_result_base ? nkf_result_base : "ASCII-8BIT";
}
#endif
long long mr_nkf_clear_result(void) { nkf_clear_result(); return NKF_OK; }

#if defined(MR_NKF_WASM)
/* Temporary argument storage belongs to the synchronous JS bridge, rather
 * than either VM's collector. It is freed in the bridge's finally block. */
void *mr_nkf_wasm_alloc(uint32_t size) { return malloc(size ? size : 1); }
void mr_nkf_wasm_free(void *pointer) { free(pointer); }
#endif
#if defined(MR_NKF_TEST)
void mr_nkf_test_fail_after(long long count) { nkf_fail_after = count; }
size_t mr_nkf_test_allocations(void) { return nkf_allocation_count; }
#endif

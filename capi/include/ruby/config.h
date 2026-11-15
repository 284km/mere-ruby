#ifndef INCLUDE_RUBY_CONFIG_H
#define INCLUDE_RUBY_CONFIG_H 1
/* mere-ruby's ruby/config.h.
 *
 * CRuby's is written by autoconf when CRuby is built, and describes that
 * build. There is no such build here: this file states facts about the C
 * compiler and the C library an extension is compiled with, and nothing
 * about an interpreter's own construction (no thread implementation, no
 * JIT, no parser choice).
 *
 * How each kind of fact is held to the truth:
 *   sizes      taken from the compiler's own predefined macros where it has
 *              them; the rest (off_t, time_t, ...) are stated per operating
 *              system and capi/config_check.c asserts them at compile time,
 *              in every build of the interpreter
 *   headers    asked of the compiler, __has_include
 *   functions  stated per operating system; capi/tools/config_probe.py
 *              links each one (CI, both platforms)
 *
 * Supported: LP64 targets of clang or gcc on macOS and Linux. */
#if !(defined(__APPLE__) || defined(__linux__)) || !defined(__LP64__) || !defined(__has_include)
# error "ruby/config.h: mere-ruby's C API is described for LP64 macOS and Linux, clang or gcc"
#endif

#define STDC_HEADERS 1
#ifndef _ALL_SOURCE
# define _ALL_SOURCE 1
#endif
#ifndef _DARWIN_C_SOURCE
# define _DARWIN_C_SOURCE 1
#endif
#ifndef _GNU_SOURCE
# define _GNU_SOURCE 1
#endif
#ifndef _POSIX_PTHREAD_SEMANTICS
# define _POSIX_PTHREAD_SEMANTICS 1
#endif
#ifndef __STDC_WANT_LIB_EXT2__
# define __STDC_WANT_LIB_EXT2__ 1
#endif
#ifndef __STDC_WANT_MATH_SPEC_FUNCS__
# define __STDC_WANT_MATH_SPEC_FUNCS__ 1
#endif
#ifndef __EXTENSIONS__
# define __EXTENSIONS__ 1
#endif
#ifndef _REENTRANT
# define _REENTRANT 1
#endif
#ifndef _THREAD_SAFE
# define _THREAD_SAFE 1
#endif
#define RUBY_SYMBOL_EXPORT_BEGIN _Pragma("GCC visibility push(default)")
#define RUBY_SYMBOL_EXPORT_END _Pragma("GCC visibility pop")
#ifndef __cplusplus
# define restrict __restrict__
#endif

/* --- sizes ------------------------------------------------------------ */
#define SIZEOF_INT __SIZEOF_INT__
#define SIZEOF_SHORT __SIZEOF_SHORT__
#define SIZEOF_LONG __SIZEOF_LONG__
#define SIZEOF_LONG_LONG __SIZEOF_LONG_LONG__
#define SIZEOF___INT64 0
#ifdef __SIZEOF_INT128__
# define SIZEOF___INT128 __SIZEOF_INT128__
# define HAVE_INT128_T 1
# define HAVE_UINT128_T 1
# define int128_t __int128
# define uint128_t unsigned __int128
# define SIZEOF_INT128_T SIZEOF___INT128
# define SIZEOF_UINT128_T SIZEOF___INT128
#else
# define SIZEOF___INT128 0
#endif
#define SIZEOF_VOIDP __SIZEOF_POINTER__
#define SIZEOF_FLOAT __SIZEOF_FLOAT__
#define SIZEOF_DOUBLE __SIZEOF_DOUBLE__
#define SIZEOF_SIZE_T __SIZEOF_SIZE_T__
#define SIZEOF_PTRDIFF_T __SIZEOF_PTRDIFF_T__
#define SIZEOF_INTPTR_T __SIZEOF_POINTER__
#define SIZEOF_UINTPTR_T __SIZEOF_POINTER__
#define SIZEOF_SSIZE_T __SIZEOF_SIZE_T__
#define SIZEOF_INT8_T 1
#define SIZEOF_UINT8_T 1
#define SIZEOF_INT16_T 2
#define SIZEOF_UINT16_T 2
#define SIZEOF_INT32_T 4
#define SIZEOF_UINT32_T 4
#define SIZEOF_INT64_T 8
#define SIZEOF_UINT64_T 8
/* (asserted in capi/config_check.c) */
#define SIZEOF_OFF_T 8
#define SIZEOF_TIME_T 8
#define SIZEOF_CLOCK_T 8
#ifdef __APPLE__
# define SIZEOF_DEV_T 4
#else
# define SIZEOF_DEV_T 8
#endif
#define SIZEOF_STRUCT_STAT_ST_SIZE SIZEOF_OFF_T
#define SIZEOF_STRUCT_STAT_ST_BLOCKS SIZEOF_OFF_T
#define SIZEOF_STRUCT_STAT_ST_INO SIZEOF_LONG
#define SIZEOF_STRUCT_STAT_ST_DEV SIZEOF_DEV_T
#define SIZEOF_STRUCT_STAT_ST_RDEV SIZEOF_DEV_T
#define SIZEOF_STRUCT_TIMEVAL_TV_SEC SIZEOF_TIME_T

#define RBIMPL_ATTR_PACKED_STRUCT_BEGIN()
#define RBIMPL_ATTR_PACKED_STRUCT_END() __attribute__((packed))
#define USE_UNALIGNED_MEMBER_ACCESS 1
#define PRI_LL_PREFIX "ll"
#define PRI_SIZE_PREFIX "z"
#define PRI_PTRDIFF_PREFIX "t"
#define PRI_PTR_PREFIX "l"

/* --- the system's integer types, and how each converts ----------------
 * (signedness and width asserted in capi/config_check.c) */
#define rb_pid_t pid_t
#define SIGNEDNESS_OF_PID_T -1
#define PIDT2NUM(v) INT2NUM(v)
#define NUM2PIDT(v) NUM2INT(v)
#define PRI_PIDT_PREFIX PRI_INT_PREFIX
#define rb_uid_t uid_t
#define SIGNEDNESS_OF_UID_T +1
#define UIDT2NUM(v) UINT2NUM(v)
#define NUM2UIDT(v) NUM2UINT(v)
#define PRI_UIDT_PREFIX PRI_INT_PREFIX
#define rb_gid_t gid_t
#define SIGNEDNESS_OF_GID_T +1
#define GIDT2NUM(v) UINT2NUM(v)
#define NUM2GIDT(v) NUM2UINT(v)
#define PRI_GIDT_PREFIX PRI_INT_PREFIX
#define rb_time_t time_t
#define SIGNEDNESS_OF_TIME_T -1
#define TIMET2NUM(v) LONG2NUM(v)
#define NUM2TIMET(v) NUM2LONG(v)
#define PRI_TIMET_PREFIX PRI_LONG_PREFIX
#define rb_dev_t dev_t
#define rb_mode_t mode_t
#define rb_rlim_t rlim_t
#define SIGNEDNESS_OF_RLIM_T +1
#define rb_off_t off_t
#define SIGNEDNESS_OF_OFF_T -1
#define rb_clockid_t clockid_t
#define PRI_CLOCKID_PREFIX PRI_INT_PREFIX
#ifdef __APPLE__
# define SIGNEDNESS_OF_DEV_T -1
# define DEVT2NUM(v) INT2NUM(v)
# define NUM2DEVT(v) NUM2INT(v)
# define PRI_DEVT_PREFIX PRI_INT_PREFIX
# define SIGNEDNESS_OF_MODE_T +1
# define MODET2NUM(v) USHORT2NUM(v)
# define NUM2MODET(v) NUM2USHORT(v)
# define PRI_MODET_PREFIX PRI_SHORT_PREFIX
# define RLIM2NUM(v) ULL2NUM(v)
# define NUM2RLIM(v) NUM2ULL(v)
# define PRI_RLIM_PREFIX PRI_LL_PREFIX
# define OFFT2NUM(v) LL2NUM(v)
# define NUM2OFFT(v) NUM2LL(v)
# define PRI_OFFT_PREFIX PRI_LL_PREFIX
# define SIGNEDNESS_OF_CLOCKID_T +1
# define CLOCKID2NUM(v) UINT2NUM(v)
# define NUM2CLOCKID(v) NUM2UINT(v)
# define PRI_64_PREFIX "ll"
#else
# define SIGNEDNESS_OF_DEV_T +1
# define DEVT2NUM(v) ULONG2NUM(v)
# define NUM2DEVT(v) NUM2ULONG(v)
# define PRI_DEVT_PREFIX PRI_LONG_PREFIX
# define SIGNEDNESS_OF_MODE_T +1
# define MODET2NUM(v) UINT2NUM(v)
# define NUM2MODET(v) NUM2UINT(v)
# define PRI_MODET_PREFIX PRI_INT_PREFIX
# define RLIM2NUM(v) ULONG2NUM(v)
# define NUM2RLIM(v) NUM2ULONG(v)
# define PRI_RLIM_PREFIX PRI_LONG_PREFIX
# define OFFT2NUM(v) LONG2NUM(v)
# define NUM2OFFT(v) NUM2LONG(v)
# define PRI_OFFT_PREFIX PRI_LONG_PREFIX
# define SIGNEDNESS_OF_CLOCKID_T -1
# define CLOCKID2NUM(v) INT2NUM(v)
# define NUM2CLOCKID(v) NUM2INT(v)
# define PRI_64_PREFIX "l"
#endif
#define GETGROUPS_T gid_t
#define IOCTL_REQ_TYPE unsigned long
#define NUM2IOCTLREQ(num) NUM2ULONG(num)

/* --- what the compiler offers ----------------------------------------- */
#define CONSTFUNC(x) __attribute__ ((__const__)) x
#define PUREFUNC(x) __attribute__ ((__pure__)) x
#define NORETURN(x) __attribute__ ((__noreturn__)) x
#define DEPRECATED(x) __attribute__ ((__deprecated__)) x
#define DEPRECATED_BY(n,x) __attribute__ ((__deprecated__("by "#n))) x
#define NOINLINE(x) __attribute__ ((__noinline__)) x
#define ALWAYS_INLINE(x) __attribute__ ((__always_inline__)) x
#define NO_SANITIZE(san, x) __attribute__ ((__no_sanitize__(san))) x
#define NO_SANITIZE_ADDRESS(x) __attribute__ ((__no_sanitize_address__)) x
#define NO_ADDRESS_SAFETY_ANALYSIS(x) __attribute__ ((__no_address_safety_analysis__)) x
#define WARN_UNUSED_RESULT(x) __attribute__ ((__warn_unused_result__)) x
#define MAYBE_UNUSED(x) __attribute__ ((__unused__)) x
#define ERRORFUNC(mesg,x) __attribute__ ((__error__ mesg)) x
#define WARNINGFUNC(mesg,x) __attribute__ ((__warning__ mesg)) x
#define WEAK(x) __attribute__ ((__weak__)) x
#define HAVE_FUNC_WEAK 1
#define RUBY_FUNC_EXPORTED __attribute__ ((__visibility__("default"))) extern
#define RUBY_FUNC_NONNULL(n,x) __attribute__ ((__nonnull__(n))) x
#define RUBY_FUNCTION_NAME_STRING __func__
#define ENUM_OVER_INT 1
#define HAVE_STMT_AND_DECL_IN_EXPR 1
#define HAVE_TYPEOF 1
#define HAVE_VA_ARGS_MACRO 1
#define HAVE__ALIGNOF 1
#define HAVE___BUILTIN_UNREACHABLE 1
#define HAVE_GCC_ATOMIC_BUILTINS 1
#define HAVE_GCC_ATOMIC_BUILTINS_64 1
#define HAVE_GCC_SYNC_BUILTINS 1
#define HAVE_BUILTIN___BUILTIN_ASSUME_ALIGNED 1
#define HAVE_BUILTIN___BUILTIN_BSWAP16 1
#define HAVE_BUILTIN___BUILTIN_BSWAP32 1
#define HAVE_BUILTIN___BUILTIN_BSWAP64 1
#define HAVE_BUILTIN___BUILTIN_POPCOUNT 1
#define HAVE_BUILTIN___BUILTIN_POPCOUNTLL 1
#define HAVE_BUILTIN___BUILTIN_CLZ 1
#define HAVE_BUILTIN___BUILTIN_CLZL 1
#define HAVE_BUILTIN___BUILTIN_CLZLL 1
#define HAVE_BUILTIN___BUILTIN_CTZ 1
#define HAVE_BUILTIN___BUILTIN_CTZLL 1
#define HAVE_BUILTIN___BUILTIN_CONSTANT_P 1
#define HAVE_BUILTIN___BUILTIN_CHOOSE_EXPR 1
#define HAVE_BUILTIN___BUILTIN_CHOOSE_EXPR_CONSTANT_P 1
#define HAVE_BUILTIN___BUILTIN_TYPES_COMPATIBLE_P 1
#define HAVE_BUILTIN___BUILTIN_TRAP 1
#define HAVE_BUILTIN___BUILTIN_EXPECT 1
#define HAVE_BUILTIN___BUILTIN_ADD_OVERFLOW 1
#define HAVE_BUILTIN___BUILTIN_SUB_OVERFLOW 1
#define HAVE_BUILTIN___BUILTIN_MUL_OVERFLOW 1
#define USE___BUILTIN_ADD_OVERFLOW_LONG_LONG 1
#define USE___BUILTIN_SUB_OVERFLOW_LONG_LONG 1
#define USE___BUILTIN_MUL_OVERFLOW_LONG_LONG 1
#define RB_THREAD_LOCAL_SPECIFIER _Thread_local
#define RSHIFT(x,y) ((x)>>(int)(y))
#define STACK_GROW_DIRECTION -1

/* --- types ------------------------------------------------------------ */
#define HAVE__BOOL 1
#define HAVE_LONG_LONG 1
#define HAVE_OFF_T 1
#define HAVE_PID_T 1
#define HAVE_UID_T 1
#define HAVE_GID_T 1
#define HAVE_TIME_T 1
#define HAVE_DEV_T 1
#define HAVE_MODE_T 1
#define HAVE_RLIM_T 1
#define HAVE_CLOCKID_T 1
#define HAVE_INT8_T 1
#define HAVE_UINT8_T 1
#define HAVE_INT16_T 1
#define HAVE_UINT16_T 1
#define HAVE_INT32_T 1
#define HAVE_UINT32_T 1
#define HAVE_INT64_T 1
#define HAVE_UINT64_T 1
#define HAVE_INTPTR_T 1
#define HAVE_UINTPTR_T 1
#define HAVE_SSIZE_T 1
#define HAVE_SIG_T 1
#define HAVE_STRUCT_TIMEVAL 1
#define HAVE_STRUCT_TIMESPEC 1
#define HAVE_STRUCT_TIMEZONE 1
#define HAVE_STRUCT_STAT_ST_BLKSIZE 1
#define HAVE_STRUCT_STAT_ST_BLOCKS 1
#define HAVE_STRUCT_STAT_ST_RDEV 1
#define HAVE_STRUCT_TM_TM_ZONE 1
#define HAVE_TM_ZONE 1
#define HAVE_STRUCT_TM_TM_GMTOFF 1
#define HAVE_DAYLIGHT 1
#define HAVE_RB_FD_INIT 1
#define HAVE_DECL_GETENV 1
#ifdef __APPLE__
# define HAVE_STRUCT_STAT_ST_ATIMESPEC 1
# define HAVE_STRUCT_STAT_ST_MTIMESPEC 1
# define HAVE_STRUCT_STAT_ST_CTIMESPEC 1
# define HAVE_STRUCT_STAT_ST_BIRTHTIMESPEC 1
# define HAVE_DECL_SYS_NERR 1
#else
# define HAVE_STRUCT_STAT_ST_ATIM 1
# define HAVE_STRUCT_STAT_ST_MTIM 1
# define HAVE_STRUCT_STAT_ST_CTIM 1
#endif

/* --- headers ---------------------------------------------------------- */
#if __has_include(<stdio.h>)
# define HAVE_STDIO_H 1
#endif
#if __has_include(<stdlib.h>)
# define HAVE_STDLIB_H 1
#endif
#if __has_include(<string.h>)
# define HAVE_STRING_H 1
#endif
#if __has_include(<inttypes.h>)
# define HAVE_INTTYPES_H 1
#endif
#if __has_include(<stdint.h>)
# define HAVE_STDINT_H 1
#endif
#if __has_include(<strings.h>)
# define HAVE_STRINGS_H 1
#endif
#if __has_include(<sys/stat.h>)
# define HAVE_SYS_STAT_H 1
#endif
#if __has_include(<sys/types.h>)
# define HAVE_SYS_TYPES_H 1
#endif
#if __has_include(<unistd.h>)
# define HAVE_UNISTD_H 1
#endif
#if __has_include(<wchar.h>)
# define HAVE_WCHAR_H 1
#endif
#if __has_include(<pthread.h>)
# define HAVE_PTHREAD_H 1
#endif
#if __has_include(<crt_externs.h>)
# define HAVE_CRT_EXTERNS_H 1
#endif
#if __has_include(<dirent.h>)
# define HAVE_DIRENT_H 1
#endif
#if __has_include(<stdbool.h>)
# define HAVE_STDBOOL_H 1
#endif
#if __has_include(<sys/wait.h>)
# define HAVE_SYS_WAIT_H 1
#endif
#if __has_include(<copyfile.h>)
# define HAVE_COPYFILE_H 1
#endif
#if __has_include(<grp.h>)
# define HAVE_GRP_H 1
#endif
#if __has_include(<fcntl.h>)
# define HAVE_FCNTL_H 1
#endif
#if __has_include(<float.h>)
# define HAVE_FLOAT_H 1
#endif
#if __has_include(<langinfo.h>)
# define HAVE_LANGINFO_H 1
#endif
#if __has_include(<limits.h>)
# define HAVE_LIMITS_H 1
#endif
#if __has_include(<locale.h>)
# define HAVE_LOCALE_H 1
#endif
#if __has_include(<malloc/malloc.h>)
# define HAVE_MALLOC_MALLOC_H 1
#endif
#if __has_include(<malloc.h>)
# define HAVE_MALLOC_H 1
#endif
#if __has_include(<pwd.h>)
# define HAVE_PWD_H 1
#endif
#if __has_include(<stdalign.h>)
# define HAVE_STDALIGN_H 1
#endif
#if __has_include(<sys/attr.h>)
# define HAVE_SYS_ATTR_H 1
#endif
#if __has_include(<sys/fcntl.h>)
# define HAVE_SYS_FCNTL_H 1
#endif
#if __has_include(<sys/file.h>)
# define HAVE_SYS_FILE_H 1
#endif
#if __has_include(<sys/ioctl.h>)
# define HAVE_SYS_IOCTL_H 1
#endif
#if __has_include(<sys/param.h>)
# define HAVE_SYS_PARAM_H 1
#endif
#if __has_include(<sys/random.h>)
# define HAVE_SYS_RANDOM_H 1
#endif
#if __has_include(<sys/resource.h>)
# define HAVE_SYS_RESOURCE_H 1
#endif
#if __has_include(<sys/select.h>)
# define HAVE_SYS_SELECT_H 1
#endif
#if __has_include(<sys/socket.h>)
# define HAVE_SYS_SOCKET_H 1
#endif
#if __has_include(<sys/time.h>)
# define HAVE_SYS_TIME_H 1
#endif
#if __has_include(<sys/times.h>)
# define HAVE_SYS_TIMES_H 1
#endif
#if __has_include(<sys/uio.h>)
# define HAVE_SYS_UIO_H 1
#endif
#if __has_include(<time.h>)
# define HAVE_TIME_H 1
#endif
#if __has_include(<ucontext.h>)
# define HAVE_UCONTEXT_H 1
#endif
#if __has_include(<utime.h>)
# define HAVE_UTIME_H 1
#endif
#if __has_include(<sys/event.h>)
# define HAVE_SYS_EVENT_H 1
#endif
#if __has_include(<sys/epoll.h>)
# define HAVE_SYS_EPOLL_H 1
#endif
#if __has_include(<sys/eventfd.h>)
# define HAVE_SYS_EVENTFD_H 1
#endif
#if __has_include(<sys/prctl.h>)
# define HAVE_SYS_PRCTL_H 1
#endif
#if __has_include(<sys/sendfile.h>)
# define HAVE_SYS_SENDFILE_H 1
#endif
#if __has_include(<sys/syscall.h>)
# define HAVE_SYS_SYSCALL_H 1
#endif
#if __has_include(<sys/sysmacros.h>)
# define HAVE_SYS_SYSMACROS_H 1
#endif
#if __has_include(<sys/utime.h>)
# define HAVE_SYS_UTIME_H 1
#endif
#if __has_include(<stdckdint.h>)
# define HAVE_STDCKDINT_H 1
#endif
#if __has_include(<stdatomic.h>)
# define HAVE_STDATOMIC_H 1
#endif
#if __has_include(<alloca.h>)
# define HAVE_ALLOCA_H 1
#endif
#if __has_include(<sys/user.h>)
# define HAVE_SYS_USER_H 1
#endif
#if __has_include(<mach-o/loader.h>)
# define HAVE_MACH_O_LOADER_H 1
#endif
#if __has_include(<libproc.h>)
# define HAVE_LIBPROC_H 1
#endif
#if __has_include(<execinfo.h>)
# define HAVE_EXECINFO_H 1
#endif
#if __has_include(<libunwind.h>)
# define HAVE_LIBUNWIND_H 1
#endif
#if __has_include(<mach/task.h>)
# define HAVE_MACH_TASK_H 1
#endif
#if __has_include(<mach/mach_init.h>)
# define HAVE_MACH_MACH_INIT_H 1
#endif
#if __has_include(<mach/mach_port.h>)
# define HAVE_MACH_MACH_PORT_H 1
#endif
#if __has_include(<ieeefp.h>)
# define HAVE_IEEEFP_H 1
#endif
#if __has_include(<intrinsics.h>)
# define HAVE_INTRINSICS_H 1
#endif
#if __has_include(<atomic.h>)
# define HAVE_ATOMIC_H 1
#endif
#if __has_include(<memory.h>)
# define HAVE_MEMORY_H 1
#endif
#if __has_include(<stdio_ext.h>)
# define HAVE_STDIO_EXT_H 1
#endif
#if (defined(__x86_64__) || defined(__i386__)) && __has_include(<x86intrin.h>)
# define HAVE_X86INTRIN_H 1
#endif
#if (defined(__x86_64__) || defined(__i386__)) && __has_include(<immintrin.h>)
# define HAVE_IMMINTRIN_H 1
#endif
#if __has_include(<setjmpex.h>)
# define HAVE_SETJMPEX_H 1
#endif
#if __has_include(<direct.h>)
# define HAVE_DIRECT_H 1
#endif
#if __has_include(<process.h>)
# define HAVE_PROCESS_H 1
#endif
#if __has_include(<a.out.h>)
# define HAVE_A_OUT_H 1
#endif
#if __has_include(<elf.h>)
# define HAVE_ELF_H 1
#endif
#if __has_include(<elf_abi.h>)
# define HAVE_ELF_ABI_H 1
#endif
#if __has_include(<net/socket.h>)
# define HAVE_NET_SOCKET_H 1
#endif

/* --- C library functions (capi/tools/config_probe.py) ------------------- */
#define HAVE_LIBPTHREAD 1
#define HAVE_LIBDL 1
#define HAVE_ALLOCA 1
#define HAVE_ISFINITE 1
#define HAVE_SIGNBIT 1
#define HAVE_WORKING_FORK 1
#define HAVE__SC_CLK_TCK 1
#define ATAN2_INF_C99 1
#define NEGATIVE_TIME_T 1
#define POSIX_SIGNAL 1
#define HAVE_ACOSH 1
#define HAVE_ARC4RANDOM_BUF 1
#define HAVE_ATAN2F 1
#define HAVE_ATAN2L 1
#define HAVE_BACKTRACE 1
#define HAVE_CBRT 1
#define HAVE_CHMOD 1
#define HAVE_CHOWN 1
#define HAVE_CHROOT 1
#define HAVE_CLOCK_GETRES 1
#define HAVE_CLOCK_GETTIME 1
#define HAVE_COSH 1
#define HAVE_DIRFD 1
#define HAVE_DLADDR 1
#define HAVE_DLOPEN 1
#define HAVE_DUP 1
#define HAVE_DUP2 1
#define HAVE_DUP3 1
#define HAVE_ENDGRENT 1
#define HAVE_ERF 1
#define HAVE_EXECL 1
#define HAVE_EXECLE 1
#define HAVE_EXECV 1
#define HAVE_EXECVE 1
#define HAVE_FCHDIR 1
#define HAVE_FCHMOD 1
#define HAVE_FCHMODAT 1
#define HAVE_FCHOWN 1
#define HAVE_FCHOWNAT 1
#define HAVE_FCNTL 1
#define HAVE_FDATASYNC 1
#define HAVE_FDOPENDIR 1
#define HAVE_FFS 1
#define HAVE_FLOCK 1
#define HAVE_FMOD 1
#define HAVE_FORK 1
#define HAVE_FSEEKO 1
#define HAVE_FSTATAT 1
#define HAVE_FSYNC 1
#define HAVE_FTELLO 1
#define HAVE_FTRUNCATE 1
#define HAVE_GETCONTEXT 1
#define HAVE_GETCWD 1
#define HAVE_GETEGID 1
#define HAVE_GETENTROPY 1
#define HAVE_GETEUID 1
#define HAVE_GETGID 1
#define HAVE_GETGRNAM 1
#define HAVE_GETGRNAM_R 1
#define HAVE_GETGROUPS 1
#define HAVE_GETITIMER 1
#define HAVE_GETLOGIN 1
#define HAVE_GETLOGIN_R 1
#define HAVE_GETPGID 1
#define HAVE_GETPGRP 1
#define HAVE_GETPPID 1
#define HAVE_GETPRIORITY 1
#define HAVE_GETPWNAM 1
#define HAVE_GETPWNAM_R 1
#define HAVE_GETPWUID 1
#define HAVE_GETPWUID_R 1
#define HAVE_GETRLIMIT 1
#define HAVE_GETSID 1
#define HAVE_GETTIMEOFDAY 1
#define HAVE_GETUID 1
#define HAVE_GMTIME_R 1
#define HAVE_HYPOT 1
#define HAVE_INITGROUPS 1
#define HAVE_IOCTL 1
#define HAVE_ISINF 1
#define HAVE_ISNAN 1
#define HAVE_KILL 1
#define HAVE_KILLPG 1
#define HAVE_LCHMOD 1
#define HAVE_LCHOWN 1
#define HAVE_LGAMMA_R 1
#define HAVE_LINK 1
#define HAVE_LINKAT 1
#define HAVE_LLABS 1
#define HAVE_LOCKF 1
#define HAVE_LOG2 1
#define HAVE_LSTAT 1
#define HAVE_LUTIMES 1
#define HAVE_MADVISE 1
#define HAVE_MBLEN 1
#define HAVE_MEMMEM 1
#define HAVE_MEMMOVE 1
#define HAVE_MKDIRAT 1
#define HAVE_MKDTEMP 1
#define HAVE_MKFIFO 1
#define HAVE_MKNOD 1
#define HAVE_MKOSTEMP 1
#define HAVE_MKTIME 1
#define HAVE_MMAP 1
#define HAVE_NAN 1
#define HAVE_NANOSLEEP 1
#define HAVE_NEXTAFTER 1
#define HAVE_OPENAT 1
#define HAVE_PCLOSE 1
#define HAVE_PIPE 1
#define HAVE_PIPE2 1
#define HAVE_POLL 1
#define HAVE_POPEN 1
#define HAVE_POSIX_MADVISE 1
#define HAVE_POSIX_MEMALIGN 1
#define HAVE_POSIX_SPAWN 1
#define HAVE_POSIX_SPAWNP 1
#define HAVE_PREAD 1
#define HAVE_PREADV 1
#define HAVE_PTHREAD_ATTR_GETGUARDSIZE 1
#define HAVE_PTHREAD_ATTR_GETSTACK 1
#define HAVE_PTHREAD_ATTR_SETINHERITSCHED 1
#define HAVE_PTHREAD_SETNAME_NP 1
#define HAVE_PTHREAD_SIGMASK 1
#define HAVE_PWRITE 1
#define HAVE_PWRITEV 1
#define HAVE_QSORT_R 1
#define HAVE_READDIR_R 1
#define HAVE_READLINK 1
#define HAVE_READLINKAT 1
#define HAVE_REALPATH 1
#define HAVE_RENAMEAT 1
#define HAVE_ROUND 1
#define HAVE_SCHED_YIELD 1
#define HAVE_SEEKDIR 1
#define HAVE_SENDFILE 1
#define HAVE_SETCONTEXT 1
#define HAVE_SETEGID 1
#define HAVE_SETENV 1
#define HAVE_SETEUID 1
#define HAVE_SETGID 1
#define HAVE_SETGROUPS 1
#define HAVE_SETITIMER 1
#define HAVE_SETPGID 1
#define HAVE_SETPGRP 1
#define HAVE_SETREGID 1
#define HAVE_SETREUID 1
#define HAVE_SETRLIMIT 1
#define HAVE_SETSID 1
#define HAVE_SETUID 1
#define HAVE_SHUTDOWN 1
#define HAVE_SIGACTION 1
#define HAVE_SIGALTSTACK 1
#define HAVE_SIGPROCMASK 1
#define HAVE_SINH 1
#define HAVE_SNPRINTF 1
#define HAVE_SOCKETPAIR 1
#define HAVE_STRCHR 1
#define HAVE_STRERROR 1
#define HAVE_STRLCAT 1
#define HAVE_STRLCPY 1
#define HAVE_STRSTR 1
#define HAVE_SYMLINK 1
#define HAVE_SYMLINKAT 1
#define HAVE_SYSCALL 1
#define HAVE_SYSCONF 1
#define HAVE_SYSTEM 1
#define HAVE_TANH 1
#define HAVE_TELLDIR 1
#define HAVE_TGAMMA 1
#define HAVE_TIMEGM 1
#define HAVE_TIMES 1
#define HAVE_TRUNCATE 1
#define HAVE_TTYNAME_R 1
#define HAVE_TZSET 1
#define HAVE_UMASK 1
#define HAVE_UNLINKAT 1
#define HAVE_UNSETENV 1
#define HAVE_UTIMENSAT 1
#define HAVE_UTIMES 1
#define HAVE_WAIT4 1
#define HAVE_WAITPID 1
#define HAVE_WRITEV 1
#define HAVE__LONGJMP 1
#define HAVE__SETJMP 1
#ifdef __APPLE__
#define HAVE_CRYPT 1
#define HAVE_FCOPYFILE 1
#define HAVE_FGETATTRLIST 1
#define HAVE_GETATTRLIST 1
#define HAVE_GETPEEREID 1
#define HAVE_ISSETUGID 1
#define HAVE_MALLOC_SIZE 1
#define HAVE_MEMSET_S 1
#define HAVE_PTHREAD_GET_STACKADDR_NP 1
#define HAVE_PTHREAD_GET_STACKSIZE_NP 1
#define HAVE_SETRGID 1
#define HAVE_SETRUID 1
#define HAVE_SIGSETJMP 1
#define HAVE___COSPI 1
#define HAVE___SINPI 1
# define HAVE_BSD_QSORT_R 1
# define BROKEN_CRYPT 1
# define vfork fork
#else
#define HAVE_ACCEPT4 1
#define HAVE_CLOCK_NANOSLEEP 1
#define HAVE_CLOSEFROM 1
#define HAVE_CLOSE_RANGE 1
#define HAVE_COPY_FILE_RANGE 1
#define HAVE_DL_ITERATE_PHDR 1
#define HAVE_EACCESS 1
#define HAVE_EPOLL_CREATE1 1
#define HAVE_EVENTFD 1
#define HAVE_EXPLICIT_BZERO 1
#define HAVE_FALLOCATE 1
#define HAVE_FINITE 1
#define HAVE_FTRUNCATE64 1
#define HAVE_GETRANDOM 1
#define HAVE_GETRESGID 1
#define HAVE_GETRESUID 1
#define HAVE_GETTID 1
#define HAVE_LSEEK64 1
#define HAVE_MALLOC_TRIM 1
#define HAVE_MALLOC_USABLE_SIZE 1
#define HAVE_MEMRCHR 1
#define HAVE_MREMAP 1
#define HAVE_POSIX_FADVISE 1
#define HAVE_POSIX_FALLOCATE 1
#define HAVE_PPOLL 1
#define HAVE_PRCTL 1
#define HAVE_PROCESS_VM_READV 1
#define HAVE_PTHREAD_GETATTR_NP 1
#define HAVE_RENAMEAT2 1
#define HAVE_SCHED_GETAFFINITY 1
#define HAVE_SECURE_GETENV 1
#define HAVE_SETRESGID 1
#define HAVE_SETRESUID 1
#define HAVE_STATX 1
#define HAVE_TIMER_CREATE 1
#define HAVE_TIMER_SETTIME 1
#define HAVE_TRUNCATE64 1
# define HAVE_GNU_QSORT_R 1
#endif

/* --- the extension's own file names and the jump primitives ------------ */
#ifdef __APPLE__
# define DLEXT_MAXLEN 7
# define DLEXT ".bundle"
# define SOEXT ".dylib"
#else
# define DLEXT_MAXLEN 3
# define DLEXT ".so"
# define SOEXT ".so"
#endif
#define RUBY_SETJMP(env) _setjmp((env))
#define RUBY_LONGJMP(env,val) _longjmp((env),val)
#define RUBY_JMP_BUF jmp_buf
#if defined(__APPLE__) && defined(__aarch64__)
# define RUBY_PLATFORM "arm64-darwin"
#elif defined(__APPLE__)
# define RUBY_PLATFORM "x86_64-darwin"
#elif defined(__aarch64__)
# define RUBY_PLATFORM "aarch64-linux"
#else
# define RUBY_PLATFORM "x86_64-linux"
#endif
#endif /* INCLUDE_RUBY_CONFIG_H */

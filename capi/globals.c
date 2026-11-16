/* The classes, modules and streams ruby.h declares as variables, filled in
 * when the first extension is about to run its Init_. */
#include "mr_capi.h"
#include "ruby/version.h"

#define EACH_CONSTANT(X) \
    X(rb_cObject, "Object") X(rb_cBasicObject, "BasicObject") X(rb_cModule, "Module") X(rb_cClass, "Class") \
    X(rb_cArray, "Array") X(rb_cBinding, "Binding") X(rb_cComplex, "Complex") X(rb_cDir, "Dir") \
    X(rb_cEncoding, "Encoding") X(rb_cEnumerator, "Enumerator") X(rb_cFalseClass, "FalseClass") \
    X(rb_cFile, "File") X(rb_cFloat, "Float") X(rb_cHash, "Hash") X(rb_cInteger, "Integer") X(rb_cIO, "IO") \
    X(rb_cMatch, "MatchData") X(rb_cMethod, "Method") X(rb_cNilClass, "NilClass") X(rb_cNumeric, "Numeric") \
    X(rb_cProc, "Proc") X(rb_cRandom, "Random") X(rb_cRange, "Range") X(rb_cRational, "Rational") \
    X(rb_cRegexp, "Regexp") X(rb_cSet, "Set") X(rb_cStat, "File::Stat") X(rb_cString, "String") \
    X(rb_cStruct, "Struct") X(rb_cSymbol, "Symbol") X(rb_cThread, "Thread") X(rb_cTime, "Time") \
    X(rb_cTrueClass, "TrueClass") X(rb_cUnboundMethod, "UnboundMethod") X(rb_cRefinement, "Refinement") \
    X(rb_cRactor, "Ractor") \
    X(rb_mKernel, "Kernel") X(rb_mComparable, "Comparable") X(rb_mEnumerable, "Enumerable") \
    X(rb_mErrno, "Errno") X(rb_mFileTest, "FileTest") X(rb_mGC, "GC") X(rb_mMath, "Math") \
    X(rb_mProcess, "Process") X(rb_mWaitReadable, "IO::WaitReadable") X(rb_mWaitWritable, "IO::WaitWritable") \
    X(rb_eException, "Exception") X(rb_eStandardError, "StandardError") X(rb_eSystemExit, "SystemExit") \
    X(rb_eInterrupt, "Interrupt") X(rb_eSignal, "SignalException") X(rb_eFatal, "fatal") \
    X(rb_eArgError, "ArgumentError") X(rb_eEOFError, "EOFError") X(rb_eIndexError, "IndexError") \
    X(rb_eStopIteration, "StopIteration") X(rb_eKeyError, "KeyError") X(rb_eRangeError, "RangeError") \
    X(rb_eIOError, "IOError") X(rb_eRuntimeError, "RuntimeError") X(rb_eFrozenError, "FrozenError") \
    X(rb_eSecurityError, "SecurityError") X(rb_eSystemCallError, "SystemCallError") \
    X(rb_eThreadError, "ThreadError") X(rb_eTypeError, "TypeError") X(rb_eZeroDivError, "ZeroDivisionError") \
    X(rb_eNotImpError, "NotImplementedError") X(rb_eNoMemError, "NoMemoryError") \
    X(rb_eNoMethodError, "NoMethodError") X(rb_eFloatDomainError, "FloatDomainError") \
    X(rb_eLocalJumpError, "LocalJumpError") X(rb_eSysStackError, "SystemStackError") \
    X(rb_eRegexpError, "RegexpError") X(rb_eEncodingError, "EncodingError") \
    X(rb_eEncCompatError, "Encoding::CompatibilityError") X(rb_eNoMatchingPatternError, "NoMatchingPatternError") \
    X(rb_eNoMatchingPatternKeyError, "NoMatchingPatternKeyError") X(rb_eScriptError, "ScriptError") \
    X(rb_eNameError, "NameError") X(rb_eSyntaxError, "SyntaxError") X(rb_eLoadError, "LoadError") \
    X(rb_eMathDomainError, "Math::DomainError") X(rb_eIOTimeoutError, "IO::TimeoutError")

#define DEFINE(variable, path) VALUE variable;
EACH_CONSTANT(DEFINE)
#undef DEFINE
/* Declared by ruby.h; this interpreter has no such class to name (IO::Buffer,
 * Ruby::Box, NameError's message object). nil is not a class: a use of one
 * fails where it is used. */
VALUE rb_cIOBuffer = Qnil, rb_cBox = Qnil, rb_cNameErrorMesg = Qnil;
VALUE rb_stdin, rb_stdout, rb_stderr;
VALUE rb_fs, rb_output_fs, rb_rs, rb_default_rs, rb_output_rs, rb_argv0;

const char ruby_engine[] = "ruby";
const char ruby_hexdigits[] = "0123456789abcdef0123456789ABCDEF";
const int ruby_api_version[3] = { RUBY_API_VERSION_MAJOR, RUBY_API_VERSION_MINOR, RUBY_API_VERSION_TEENY };

static VALUE boot_body(VALUE unused) {
    (void)unused;
#define FILL(variable, path) variable = mr_const(path);
    EACH_CONSTANT(FILL)
#undef FILL
    rb_stdin = rb_gv_get("$stdin");
    rb_stdout = rb_gv_get("$stdout");
    rb_stderr = rb_gv_get("$stderr");
    rb_fs = rb_gv_get("$;");
    rb_output_fs = rb_gv_get("$,");
    rb_rs = rb_gv_get("$/");
    rb_default_rs = rb_rs;
    rb_output_rs = rb_gv_get("$\\");
    rb_argv0 = rb_gv_get("$0");
    return Qnil;
}
void mr_capi_boot(void) {
    VALUE outcome;
    mr_guarded(boot_body, Qnil, &outcome);
    if (outcome != Qundef) mr_throw(outcome);
}

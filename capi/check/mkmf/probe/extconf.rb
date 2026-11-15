# What an extension's extconf.rb usually does, on both rubies: ask the
# compiler some questions, then write a Makefile.
require 'mkmf'
have_header('stdint.h')
have_header('no_such_header_anywhere.h')
have_func('strlen', 'string.h')
have_func('no_such_function_anywhere')
# (a function of ruby's own: answered by whether THIS ruby has it)
have_func('rb_ary_new')
have_func('rb_no_such_function_anywhere')
have_func('rb_tracepoint_new')
# (have_macro answers and defines nothing: its answer is passed on by hand)
$defs << '-DMKMF_PROBE_STDC' if have_macro('__STDC__')
$defs << '-DMKMF_PROBE_NO_MACRO' if have_macro('NO_SUCH_MACRO_ANYWHERE')
check_sizeof('long')
have_library('m', 'floor')
$defs << '-DMKMF_PROBE_NOTE=7'
create_header
create_makefile('mkmf_probe')

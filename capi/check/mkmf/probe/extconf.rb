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
# (OpenSSL, as an extension with TLS of its own looks for it -- puma's
#  MiniSSL: dir_config reads configure's --with-openssl-dir back out of
#  RbConfig where the ruby was built against a named installation, and the
#  header and both libraries are found there; elsewhere on the compiler's own
#  paths)
dir_config('openssl')
$defs << '-DMKMF_PROBE_OPENSSL' if have_header('openssl/ssl.h') && have_library('crypto', 'BIO_read') && have_library('ssl', 'SSL_CTX_new')
$defs << '-DMKMF_PROBE_NOTE=7'
create_header
create_makefile('mkmf_probe')

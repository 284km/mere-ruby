# Loaded before anything else by the launcher unittest/mkmf_context.sh writes
# (so by the test and by every child it starts). ruby's test/mkmf is written
# to run inside a ruby BUILD tree: it sets $extmk, reads topdir's Makefile and
# finds ruby.h under the source tree and config.h under topdir's .ext. This
# points mere-ruby at the tree mkmf_context.sh staged for that -- its own
# headers under both names -- and changes nothing else: the compiler, the
# flags and the rest of RbConfig are the interpreter's own.
require 'rbconfig'
$top_srcdir = ENV.fetch('UNITTEST_MKMF_SOURCE')
$topdir = ENV.fetch('UNITTEST_MKMF_BUILD')
RbConfig.fire_update!('topdir', $topdir)

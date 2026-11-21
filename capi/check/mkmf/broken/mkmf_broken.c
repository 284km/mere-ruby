/* Does not compile, on purpose: `make` must fail for it on both rubies. */
#include <ruby.h>
void Init_mkmf_broken(void) { this is not C }

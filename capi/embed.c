/* The embedding API, as it answers inside a running interpreter: an
 * extension is loaded by a Ruby that is already set up, and CRuby's
 * ruby_setup then returns 0 at once (`if (GET_VM()) return 0;`), and
 * ruby_init with it. Starting an interpreter from a C program of its own --
 * ruby_options, ruby_run_node -- is not offered: mere-ruby is the program. */
#include "mr_capi.h"

int ruby_setup(void) { return 0; }
void ruby_init(void) { (void)ruby_setup(); }

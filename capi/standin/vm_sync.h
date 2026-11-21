/* Stands in for CRuby's vm_sync.h where a file of capi/vendor includes it.
 * One native thread runs Ruby here: what CRuby does under its VM lock is a
 * block. */
#ifndef RUBY_VM_SYNC_H
#define RUBY_VM_SYNC_H
#define RB_VM_LOCKING()
#define ASSERT_vm_locking() ((void)0)
#endif

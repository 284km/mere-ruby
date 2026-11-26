# IO's and File's methods as reflection names them

test/ruby whole on both executions (#287) left one test failing on the VM alone, `TestIO#test_marshal_closed_io`: `undef_method :closed?` in an IO's singleton class raised NameError. The evaluator took the statement inside `class << r` and refused the call form (`r.singleton_class.send(:undef_method, :closed?)`) the same way. The cause was not the VM's: reflection did not know IO's methods.

## What reflection saw

IO's public methods are the dispatcher's: no method row names them. The other core classes' are named by a list generated from the reference (`m_builtin_lists.mere`, `tools/gen_builtin_lists.rb`), which IO and File were not in. What the method table had instead was the prelude's: its helpers on IO (`__fd_read` and 125 more), its `dup` and `to_s` on IO, and, on File, its versions of IO's methods (`read`, `close`, ...). So, on main:

| | ruby | main |
|---|---|---|
| `IO.instance_methods(false)` | 77 | 59 of them missing, 128 more (126 of them internal) |
| `File.instance_methods(false)` | 10 | 51 more, 42 of them IO's in ruby |
| `r.singleton_class.method_defined?(:closed?)` | true | false |
| `undef_method :closed?` in `class << r` | undefines it | NameError on the VM |

## The change

- **The list.** `tools/gen_builtin_lists.rb` takes IO and File too; the lists are generated again (the others are unchanged, the header now names 4.0.10). The probe asks File's instance methods of a File, not of the class. IO's are asked of `$stdout`, which does not answer nine of them (`close_read`, `close_write`, `fdatasync`, `fsync`, `ioctl`, `pread`, `pwrite`, `set_encoding_by_bom`, `to_io`), so the list leaves those out: a pipe answers them through File's rows, `$stdout` does not, and the list is a claim `respond_to?` reads.
- **What the prelude wrote.** A row the prelude wrote on IO or File (`io_row_hidden`) is left out of a class's own list unless ruby gives the class that name, and out of a list down the chain when it is a helper (`__...`). File's `close_write` is still File's to answer down the chain. Every one of them can still be called. Three lists read the rule: `instance_methods(false)`, the public, private and protected `instance_methods` of either form, and the walk under `methods` and its kin (`collect_vis_go`).
- **What the list does not speak for.** `respond_to?` reads the lists too, and IO's names what an IO or a File answers. An object of another IO subclass, a socket, answers the stream methods through its own route (`fdio_route_call`) and not, for one, `to_path`: with IO's list behind it, `IPSocket.allocate.respond_to?(:to_path)` was true, the socket library's `#inspect` called it, and corpus 476 failed. For such an object `respond_to?` reads the lists without IO's and File's (`listed_builtin_root_skip_io`), as before.
- **The walker's message.** The class body's walker refused an unknown name with the class's key, `(sng:281474976710835)`; it names it as the call does now, `#<Class:#<IO:0x...>>`, and a module as a module.

## Now

| | ruby | here |
|---|---|---|
| `IO.instance_methods(false)` | 77 | the same less the nine `$stdout` does not answer |
| `File.instance_methods(false)`, `public_instance_methods(false)` | 10 | the same |
| `File.instance_methods` | | the same less `ioctl` |
| internal names in any public list of IO, File, a pipe, a File | none | none |

`TestIO#test_marshal_closed_io` passes on both executions.

Corpus 826 has the lists (the names both have, File's whole own list, no internal name in seven lists), `method_defined?`, `undef_method` of an IO method in a pipe's and a File's singleton class, Marshal of a closed IO before and after, and an unknown name refused.

## Recorded

- `$stdout` (and `IO.new(fd)`) does not answer the nine names above; a pipe does.
- `IO.private_instance_methods(false)` lacks `initialize` and `initialize_copy`.
- Other classes' prelude helpers show the same way: `Dir#__adopt`, `Thread#__tf_install`. The rule is IO's and File's only.
- `File.instance_method(:read).owner` is File (ruby: IO): the owner is the row's.
- A socket does not answer `to_path`, `path` or `lineno`, which ruby's do (IO's); its `respond_to?` says so.

CHECKED

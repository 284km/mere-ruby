# Argument-marker retention

Run `python3 unittest/argument_marker_check.py` with an O2 binary. The workload alternates two callees and checks their return values. It compares native default-region allocation totals at 1,000 and 100,000 iterations, with hash indexing ON and OFF. These are allocated bytes, not sampled RSS.

On macOS with pinned Mere `991f299b`, main `8bfec2b` grew from 144,275,272 to 152,886,848 bytes (8,611,576 extra bytes). Giving the three-name argument-error marker table a collectible arena reduced the growth to 534,952 bytes (144,194,976 to 144,729,928). The check allows 2 MiB of auxiliary growth, and fails on the unmodified binary.

Saved marker names must be copied before evaluating nested defaults: an inner call can collect the table's arena. The focused corpus program checks nested positional/keyword defaults, explicit GC, and argument errors. The existing lambda backtrace-label compatibility gap is outside this change; the lambda case checks its argument error text.

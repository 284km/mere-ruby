# Experimental Rails validation only

This branch combines unmerged C API candidate #95 (54184e4e), the SHA-2
implementation in #120, and the locked Rails measurement from #117.
It is not a release or a branch to merge into main. Each independent PR
keeps its own review, full CI and per-file regression requirements.

Runtime commit 153e64f5392df17d1332410e3b10ce49d5fa9fca produced the separate
fresh measurement: all 68 dependencies install in 284.529 seconds, followed
by the command-registry failure tracked in #121. The reference remains
healthy; Rails application tests and HTTP on mere-ruby are not established.
The three provider implementation files are byte-identical to #120's
initial implementation commit e1878eae. The original C API branch and PR
have not been edited by this validation work.

# capi_gem_check: an install's make runs one compiler at a time

`gem install prism` on the reference ruby was stopped at the 2 GiB bound
(MEMORY_LIMIT) in tools/capi_gem_check.py, more often the less loaded the
machine was: #253 and #267 both met it, and so did the first gem check of
capi-xfer-cost (peak 2,147,184 KB, 5.7 s, then killed). With the
reference's prism not installed, the check also reads "DIFFERENT": its
gems.rb then loads the default prism (1.8.2) where mere-ruby loads 2.1.0.

**Cause.** RubyGems runs make with `-j<processors + 1>` when MAKEFLAGS has
none (rubygems/installer.rb `build_jobs`, ext/builder.rb) -- eleven at once
on this ten-processor machine -- and one compile of prism's `api_node.c`
with the reference's flags (`-O3 -ggdb3`) is about 1.5 GB by itself
(watched with ps during an install: the clang `-cc1` of api_node.c peaked at
1,494 MB; prism.c alone is 260 MB). Measured on one install of
prism-2.1.0.gem by the reference, with the check's own `supervise` (the
process and its children):

| make jobs | peak | time |
|---|---|---|
| RubyGems' default (11) | 2,147,184 KB, killed | 5.7 s |
| 2 | 2,088,096 KB | 10.5 s |
| 1 | 1,738,736 KB | 16.1 s |

**Change.** Every `gem install` the check runs, on both sides, gets
`--build-jobs 1` (BUILD_JOBS). The bound stays 2 GiB; what changes is that
the check, not the machine's processor count, decides how many compilers
run inside it.

**Checked.** The whole check against main's build (5276535f, mere 9dec2ff6),
reference ruby 4.0.10: all 22 gems install on both sides, "the same output
on both sides (173 lines)", the other-ruby control fails. The largest step
is the reference's prism install at 1,695,200 KB (18.4 s); the steps take
828 s in all. (Load average 13 to 45 during the run.)

**Left.** 1.7 GB of 2 GiB is the reference's prism with one compiler: if a
later prism or a different compiler needs more for api_node.c, the bound is
met again, and there is nothing smaller to set here short of changing the
reference's build flags, which would make it another build.

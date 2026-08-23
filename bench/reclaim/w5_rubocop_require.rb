# The workload behind the default-region numbers in the reclamation notes:
# loading rubocop end to end. Needs a gem home and CRuby's pure-Ruby stdlib:
#
#   GEM_HOME=<gems> GEM_PATH=<gems> RUBYLIB=<stdlib> ./mere-ruby bench/reclaim/w5_rubocop_require.rb
#   (or via -I<stdlib>; both work — RUBYLIB is what bench/region_split.sh
#    and bench/def_sites.sh can pass through their environment)
#
# Attribution history: 8.6 GB of default-region allocation decomposed into
# call-bookkeeping churn (per-call delete reindexing 37%, per-call name/file/
# meth/line overwrites 29%, boxed-value copies 26%) — fixed upstream in mere
# v0.1.316 (reindex reuse) and here by compacting the bookkeeping maps in
# gc_collect. 9.0 GB -> 1.76 GB.
require "rubygems"
require "rubocop"
puts "OK rubocop"

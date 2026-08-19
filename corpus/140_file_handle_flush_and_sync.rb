# A File here is a path, a mode and a write buffer -- there is no descriptor --
# and `responds` was promising six methods of that buffer that nothing
# implemented: respond_to?(:flush) said yes and calling it raised NoMethodError,
# which is worse than either answer on its own, because a library that checks
# first breaks anyway.
path = "/tmp/mrb_corpus_io_handle.txt"

# a `w` open truncates at once, a write is buffered, and flush puts it out
f = File.open(path, "w")
f.write("one\n")
before_flush = File.read(path)
f.flush
after_flush = File.read(path)
f.write("two\n")
f.close
p [before_flush, after_flush, File.read(path)]

# `sync = true` means every write goes out as it happens
g = File.open(path, "w")
p g.sync
g.sync = true
p g.sync
g.write("sync\n")
p File.read(path)
g.close

# read CONSUMES: the second one is "", and eof? is true afterwards
h = File.open(path, "r")
p [h.read, h.read, h.eof?]
p [h.tty?, h.isatty]
h.close

# an `a` open keeps what is there
a = File.open(path, "a")
a.write("more\n")
a.flush
p File.read(path)
a.close
p File.read(path)

File.delete(path)

# A spawned child's standard three are BLOCKING, as ruby makes them before
# exec: an IO.pipe's ends are non-blocking, and a child given one as its
# stdout gave up at the first full pipe (64 KB) with EAGAIN -- puma's
# test_form_data_encoding_windows, where curl's echo of a 260 KB body came
# back cut at 65536 bytes.
r, w = IO.pipe
pid = spawn("head", "-c", "300000", "/dev/zero", out: w, err: File::NULL)
w.close
sleep 0.3
p r.read.bytesize
Process.wait pid
p $?.success?

# ...through the shell, and with stderr sent to the child's stdout
r, w = IO.pipe
pid = spawn("head -c 200000 /dev/zero; echo done >&2", out: w, err: [:child, :out])
w.close
sleep 0.3
p r.read.bytesize
Process.wait pid

# ...and IO.popen's pipe
IO.popen(["head", "-c", "150000", "/dev/zero"]) do |io|
  sleep 0.3
  p io.read.bytesize
end

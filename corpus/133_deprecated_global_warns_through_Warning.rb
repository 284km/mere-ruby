# Reading `$=` is deprecated in Ruby and warns -- through Warning.warn, which a
# program can override. No warning was emitted at all here, so an override never
# ran and the read was silent. A test suite that turns warnings into failures
# depends on exactly this path.
module Warning
  def warn(m); raise "warned: #{m[/variable .*/]}"; end
end

$VERBOSE = true
begin
  x = $=
  p ["no raise", x]
rescue => e
  p e.message
end

# with $VERBOSE off there is no warning, and the read is just a read
$VERBOSE = false
begin
  x = $=
  p ["quiet", x]
rescue => e
  p ["unexpected", e.message]
end

# the category switches are still readable and writable
p Warning[:deprecated]
Warning[:deprecated] = true
p Warning[:deprecated]

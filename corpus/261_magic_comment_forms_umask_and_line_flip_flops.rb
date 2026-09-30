# vim: set fileencoding=big5 :
# frozen_string_literal: true
#
# Three things a program can ask without any command-line switch:
#
# * The magic comment in the forms ruby reads -- here vim's `fileencoding=`,
#   any spelling of the name -- decides __ENCODING__ as well as the literals.
#   __ENCODING__ used to look the UPCASED name up and fall back to UTF-8 for
#   every encoding not spelled in capitals (Big5, Shift_JIS), while the
#   literals of the same file were Big5.
# * `frozen_string_literal: true` makes a literal ruby's fstring: one object
#   per content and encoding, the same object each time it is evaluated.
# * File.umask is umask(2) itself: set, read back, restored.
# * An integer end of a flip-flop is compared with $. and a regexp end is
#   matched against $_ -- the awk idiom `print if 2..3`.
p __ENCODING__
p "abc".encoding
p "abc".frozen?
p "abc".equal?("abc")
lits = Array.new(2) { "lit" }
p lits[0].equal?(lits[1])
p "x#{1}y".frozen?
p eval("__ENCODING__")

old = File.umask(0o027)
p File.umask
p File.umask(old) == 0o027
p File.umask == old

path = File.join(ENV["TMPDIR"] || "/tmp", "mr261_#{$$}.txt")
begin
  File.write(path, "a\nb\nc\nd\ne\n")
  File.open(path) do |f|
    while f.gets
      print $_ if 2..3
    end
  end
  File.open(path) do |f|
    while f.gets
      print "x", $_ if /c/../d/
    end
  end
  File.open(path) do |f|
    while f.gets
      print "y", $_ if 4...4
    end
  end
ensure
  File.delete(path) if File.exist?(path)
end

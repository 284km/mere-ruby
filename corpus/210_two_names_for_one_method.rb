# "X is an alias of Y" is the FIRST divergence in 44 of the record's files, and
# it is one question asked of three tables: respond_to? (builtin_obj_has), the
# reflection door (builtin_owns_here), and the alias map (canon_alias). A name
# that DISPATCHES is not enough -- all three have to agree, or two names for one
# implementation come back as two different Methods.
#
# ⚠ Every pair below was read out of the ruby/spec file that asserts it, not
# recalled. Two of them are counter-intuitive and would have been guessed
# backwards: File#path is the ALIAS and to_path the canonical, while for IO it
# is the other way round.

require "stringio"
require "pathname"

p Time.instance_method(:tv_nsec) == Time.instance_method(:nsec)
p Time.instance_method(:tv_sec) == Time.instance_method(:to_i)
p Time.instance_method(:tv_usec) == Time.instance_method(:usec)
p Time.instance_method(:xmlschema) == Time.instance_method(:iso8601)
p File.instance_method(:path) == File.instance_method(:to_path)
p IO.instance_method(:to_path) == IO.instance_method(:path)
p IO.instance_method(:eof) == IO.instance_method(:eof?)
p Dir.instance_method(:path) == Dir.instance_method(:to_path)
p Thread.instance_method(:inspect) == Thread.instance_method(:to_s)
p BasicObject.instance_method(:equal?) == BasicObject.instance_method(:==)
p Struct.instance_method(:length) == Struct.instance_method(:size)
p Struct.instance_method(:values) == Struct.instance_method(:to_a)
p StringIO.instance_method(:length) == StringIO.instance_method(:size)
p StringIO.instance_method(:tell) == StringIO.instance_method(:pos)
p StringIO.instance_method(:isatty) == StringIO.instance_method(:tty?)
p StringIO.instance_method(:each) == StringIO.instance_method(:each_line)
p Pathname.instance_method(:/) == Pathname.instance_method(:+)
p Pathname.instance_method(:===) == Pathname.instance_method(:==)

# ...and the CLASS-method side, which had no table at all: `Time.method(:gm)`
# was a NameError for a method the next line could call, and that was every
# class in the dispatcher.
p Time.respond_to?(:utc)
p Time.method(:gm) == Time.method(:utc)
p Time.method(:mktime) == Time.method(:local)
p Process.method(:waitpid) == Process.method(:wait)
p Process.method(:waitpid2) == Process.method(:wait2)
p [Thread.respond_to?(:start), Marshal.respond_to?(:dump)]

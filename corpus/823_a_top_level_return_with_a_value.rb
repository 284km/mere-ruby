# A file's own `return` ends the file, and a value given to it goes nowhere.
# ruby says so as it compiles the file, before any of it runs: "<file>:
# warning: argument of top-level return is ignored", once for each such
# return of the top level (one in a method or a block is another matter),
# with the file and no line, and not under -W0. A required file's, a loaded
# file's and the main script's alike.
#
# The warning is on stderr, which this corpus does not compare, so a child
# runs each case and its two streams are read as one.
require "tmpdir"
dir = Dir.mktmpdir("c823")
real = File.realpath(dir)
w = ->(name, src) { File.write(File.join(dir, name), src) }
run = ->(*args) { IO.popen([RbConfig.ruby, *args], err: [:child, :out], &:read).gsub(real, "D").gsub(dir, "D") }

w.("one.rb", "$log << :one\nreturn 5\n$log << :never\n")
w.("many.rb", <<~'RUBY')
  $log << :many
  if $x
    return 1
  end
  begin
    return [2] if $y
  rescue => e
    return e
  else
    $log << :else
  ensure
    $log << :ensure
  end
  [1].each { |i| return i if $z }
  def in_a_method = (return 3)
  x = 1 and return :and if $x
  return
RUBY
w.("bare.rb", "$log << :bare\nreturn\n$log << :never\n")
w.("yes.rb", "$log << :yes\n$y = true\nreturn\n")
w.("main.rb", <<~'RUBY')
  $stdout.sync = true
  $log = []
  p :start
  p require_relative("one"), require_relative("many"), require_relative("bare"), require_relative("yes")
  p load(File.join(__dir__, "many.rb")), load(File.join(__dir__, "one.rb"))
  p $log, in_a_method
  p eval("7")
  begin
    return :main if $log.size > 3
  ensure
    p :main_ensure
  end
  p :unreached
RUBY

puts run.(File.join(dir, "main.rb"))
puts "-- -W0"
puts run.("-W0", File.join(dir, "main.rb"))
puts "-- -w"
puts run.("-w", File.join(dir, "main.rb"))
puts "-- a script of one line"
w.("line.rb", "$log = []; p 1; return 2; p 3\n")
puts run.(File.join(dir, "line.rb"))

# A magic comment is read only as the comment's key: right after the `#`, or
# after a `;` or the `-*-` of the emacs form. A comment that only mentions
# the name is none, and says nothing. (Here such a comment in the ISeq
# compiler's own source warned "invalid value for shareable_constant_value"
# each time that compiler was loaded.)
w.("magic.rb", <<~'RUBY')
  # pm_compile_shareable_constant_value: a literal is pushed
  A = [1]
  # a-shareable_constant_value: literal
  B = [1]
  # foo shareable_constant_value: literal
  C = [1]
  #  shareable_constant_value: literal
  D = [1]
  # -*- shareable_constant_value: none -*-
  E = [1]
  # -*- coding: utf-8; shareable_constant_value: literal -*-
  F = [1]
  # shareable_constant_value: nonsense
  G = [1]
  p [A, B, C, D, E, F, G].map(&:frozen?)
RUBY
puts "-- magic comments"
puts run.("-w", File.join(dir, "magic.rb"))

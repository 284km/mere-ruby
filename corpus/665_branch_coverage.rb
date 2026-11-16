# Round 40 of note 552: branch coverage. A file read while Coverage counts
# branches runs on the ISeq VM: the compiler puts each branch in its
# sequences where ruby's does (compile.c's add_trace_branch_coverage) and the
# VM counts them; Coverage.result answers the constructs and their branches as
# ruby numbers them. And a covered file's lines are the compiled code's line
# events -- a statement written over several lines counts on the line its
# first instruction is on.
require "coverage"
require "tmpdir"

TARGET = <<~'RUBY'
  def pick(x)
    if x == 0
      :zero
    elsif x == 1
      :one
    else
      :many
    end
  end
  pick(0); pick(0); pick(1); pick(2)
  i = 0
  while i < 3
    i += 1
  end
  i -= 1 until i == 0
  y = i > 1 ? :a : :b
  z = nil&.size
  w = "s"&.size
  case w
  when 0 then :none
  when 1, 2
    :few
  else :lots
  end
  case
  when w > 5 then :big
  end
  puts "unless" unless w
  v = (w if w)
  def never(a) = a ? 1 : 2
RUBY

LINES = <<~'RUBY'
  FOO = [
    { foo: 'bar' },
    { bar: 'baz' }
  ]

  'some string'.split
               .map(&:length)

  some =
    'value'

  Struct.new(
    :foo,
    :bar
  ).new
RUBY

Dir.mktmpdir do |d|
  t = File.join(d, "target665.rb")
  l = File.join(d, "lines665.rb")
  File.write(t, TARGET)
  File.write(l, LINES)
  Coverage.start(lines: true, branches: true)
  require t
  r = Coverage.result(stop: false, clear: true)[t]
  p r[:lines]
  r[:branches].each { |base, branches| puts "#{base.inspect} => #{branches.inspect}" }
  # cleared, and counted again from zero
  pick(1)
  again = Coverage.result[t][:branches]
  p again.values.flat_map(&:values).sum, again.keys.first

  # lines alone: a statement over several lines
  Coverage.start(lines: true)
  require l
  p Coverage.result[l]
  o = File.join(d, "oneshot665.rb")
  File.write(o, LINES.sub("FOO", "BAR"))
  Coverage.start(oneshot_lines: true)
  require o
  p Coverage.result[o]
end

# `super` from a module prepended to a builtin object class (IO, File, Time),
# or from a subclass's override, reaches the class's native method.
# io-console 0.9.5 prepends IO::platform_tty, whose #tty? calls super (in C,
# rb_call_super); Rails' test reporter asks $stdout.tty? for every result.

def try
  yield
rescue => e
  "#{e.class}: #{e.message}"
end

module TtyPlatform
  CALLS = []
  def tty?(*kinds)
    CALLS << kinds
    kinds.empty? ? super() : [:platform, super()]
  end

  def isatty(*kinds) = tty?(*kinds)
end
IO.prepend TtyPlatform

p try { $stdout.tty? }, try { $stdout.isatty }, try { $stdout.tty?(:any) }
p IO.ancestors.first(2), TtyPlatform::CALLS

module Counting
  CALLS = []
  def fileno
    CALLS << :fileno
    super
  end

  def path
    CALLS << :path
    super
  end

  def closed?
    CALLS << :closed?
    super
  end
end
IO.prepend Counting
p try { $stdout.fileno }, try { $stdout.closed? }

File.open(__FILE__) do |f|
  p try { f.tty? }, try { File.basename(f.path) }, try { f.fileno.is_a?(Integer) }, try { f.closed? }
end
p Counting::CALLS

module Years
  def year = super + 1000
end
Time.prepend Years
p try { Time.at(0).utc.year }, try { Time.at(0).utc.month }

class Stamp < Time
  def hour = super * 10
end
p try { Stamp.at(3600).utc.hour }

# names Kernel and BasicObject also have are Time's own here
module TimeShow
  def to_s = "<" + super + ">"
  def <=>(other) = super
  def ==(other) = super
end
Time.prepend TimeShow
z = Time.at(0).utc
p try { z.to_s }, try { z <=> Time.at(1) }, try { Time.at(1) < Time.at(2) }
p try { [Time.at(3), Time.at(1)].sort.map(&:to_i) }, try { Time.at(1) == Time.at(1) }

# a singleton's super still reaches Kernel#puts as before
$stdout.singleton_class.class_eval { def puts(*a) = super }
$stdout.puts("through the singleton")

# a singleton method or an extended module on a Time reaches Time's own
tz = Time.at(7200).utc
def tz.hour = super * 2
p try { tz.hour }
tz2 = Time.at(0).utc
tz2.extend(Module.new { def year = super + 1 })
p try { tz2.year }

# a body that replaces Time's own in Time itself goes on to Kernel's
class Time
  def eql?(other) = super
end
p try { Time.at(1).eql?(Time.at(1)) }, try { Time.at(1).eql?(Time.at(1).dup) }

# super from inside a refinement reaches the native, not the refinement again
module HourPlus
  refine(Time) { def hour = super + 100 }
end
using HourPlus
p try { Time.at(3600).utc.hour }

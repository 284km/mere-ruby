# Ruby identifiers may contain any non-ASCII character, and the lexer walks
# bytes -- sidekiq writes `alias_method :💣, :clear`.
# NOT `p :💣` -- Symbol#inspect escapes non-ASCII when the default external
# encoding is not UTF-8, so the expected output would depend on the shell's
# locale rather than on the interpreter.
p :💣.to_s.bytes
p :あ.to_s.bytes
p :💣 == :"💣"
p({ あ: 1 }[:あ])

def 名前 = 1
p 名前

class Bomb
  def clear = :cleared
  alias_method :💣, :clear
end
p Bomb.new.💣
p Bomb.instance_methods(false).sort.size

# `::Name` is TOP LEVEL and nothing else -- read by bare name it would find a
# nested constant of the same name, which is exactly what `::Process` inside
# a Sidekiq that has its own Process is written to avoid.
class Process2; end
module Outer
  class Process2
    def self.who = :nested
  end
  def self.top = ::Process2
  def self.near = Process2
end
p Outer.top
p Outer.near
p ::Process2
p defined?(::Process2)
p defined?(::NoSuchConstantAnywhere)
p Outer::Process2.who

# the builtin namespaces that are Modules in ruby say so
p [Process, GC, ObjectSpace, Marshal, Signal, Math, Comparable, Kernel].map(&:class)
p [String, Array, Integer].map(&:class)
p Math.sqrt(4)
p Math.hypot(3, 4)

# `require(x)` written as a call -- inside a method, as a value -- names a
# path it cannot find in that path's own encoding, as the statement form
# does. (Where the OS takes a path's bytes as they are, the call form said a
# Windows-31J name in UTF-8, and the name's end_with? then refused it.)

sjis = "\u{3042}".encode("Windows-31J")
latin = "\u{ff}".encode("ISO-8859-1")

def via(x) = require(x)

[sjis, latin, "\u{221e}"].each do |pa|
  [[:via, -> { via(pa) }], [:value, -> { r = require(pa); r }]].each do |how, call|
    begin
      call.call
    rescue LoadError => e
      p [how, e.message.encoding, e.message.end_with?(pa), e.path.encoding]
    end
  end
end

# not a String: asked for #to_path, once
class P
  def initialize(s) = (@s = s; @asked = 0)
  attr_reader :asked
  def to_path = (@asked += 1; @s)
end
o = P.new("no_such_feature_for_695")
begin
  via(o)
rescue LoadError => e
  p e.message, o.asked
end
begin
  via(42)
rescue TypeError => e
  p e.message
end

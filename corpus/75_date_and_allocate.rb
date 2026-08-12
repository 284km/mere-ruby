# date ships as source: proleptic Gregorian only (CRuby defaults to the
# Italian reform, so pre-1582 Julian Day numbers differ -- stated, not hidden).
require "date"

d = Date.new(2026, 8, 12)
p d.to_s, d.year, d.month, d.day, d.wday, d.yday, d.jd, d.leap?
p (d + 30).to_s, (d - 1).to_s, (d >> 1).to_s, (d << 2).to_s
p Date.parse("2026-08-12").to_s
p Date.parse("2026/01/03").to_s
p d.strftime("%Y/%m/%d %j %a %A %b %B %F %%")
p (Date.new(2026,9,1) - d).to_i
p (d <=> Date.new(2026,1,1))
p Date.jd(2461265).to_s
p Date.new(2024,2,29).to_s, Date.leap?(2024), Date.leap?(1900), Date.leap?(2000)
p (Date.new(2026,1,31) >> 1).to_s
p (Date.new(2026,3,31) << 1).to_s
p Date.new(2026,8,12).succ.to_s
p [Date.new(2026,1,2), Date.new(2025,5,5)].sort.map(&:to_s)
p Date.new(2026,8,12) == Date.new(2026,8,12)
p Date.strptime("2026-08-12", "%F").to_s
p Date.new(2026,8,31).to_s
p Date.new(1970,1,1).jd, Date.new(1583,1,1).jd
p (Date.new(2026,12,31)).yday
p Date.valid_civil?(2026, 2, 30)
begin; Date.new(2026,2,30); rescue ArgumentError => e; p e.class; end
p DateTime.new(2026,8,12,3,4,5).hour
p Date::ABBR_DAYNAMES[0]

# Class#allocate makes an instance with no ivars and no initialize call --
# how Date builds one from a Julian day.
class Made
  def initialize(x) = @x = x
  attr_reader :x
  def self.new(a, b)
    o = allocate
    o.set(a + b)
    o
  end
  def set(v) = @v = v
  attr_reader :v
end
p Made.allocate.instance_variables
p Made.new(1, 2).v

# ...and a bare `new` inside another class method reaches that def self.new
class Made
  def self.mk(a) = new(a, a)
end
p Made.mk(4).v

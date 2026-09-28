# Enumerator.produce was a special object whose #size never returned, and a
# generator that never ends could not answer take_while or find: they
# materialised every element first. produce is an ordinary Enumerator.new
# now, and those walks stop at the first element that decides.
e = Enumerator.produce(1) { |x| x * 2 }
p e.class, e.size, e.take(5), e.first(3)
p e.take_while { |x| x < 100 }, e.find { |x| x > 1000 }, e.detect(&:odd?), e.find_index { |x| x == 64 }
p e.lazy.select(&:even?).first(2)
seen = []
g = Enumerator.produce { |prev| seen << prev; (prev || 10) - 3 }
p g.take(3), seen
lines = "a\nb\nc".lines
p Enumerator.produce { lines.shift }.take_while { |s| s }
countdown = Enumerator.produce(3) do |n|
  raise StopIteration if n <= 1
  n - 1
end
p countdown.to_a, countdown.map { |n| n * 10 }
p Enumerator.produce(0, size: 4) { |n| n + 1 }.size
p Enumerator.produce(0, size: -> { 2 + 2 }) { |n| n + 1 }.size
p Enumerator.produce(0, size: nil) { |n| n + 1 }.size
[-> { Enumerator.produce }, -> { Enumerator.produce(a: 1) { } }, -> { Enumerator.produce(1, 2) { } }].each do |f|
  begin
    f.call
  rescue ArgumentError => err
    p err.message
  end
end
nat = Enumerator.new { |y| n = 0; loop { y << n; n += 1 } }
p nat.take_while { |n| n < 4 }, nat.find { |n| n * n > 50 }

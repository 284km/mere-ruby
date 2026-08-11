# `<`, `<=`, `>`, `>=`, `<=>` on a class or module are the SUBCLASS partial
# order, not a value comparison. Without them, sorting a list of classes
# raised "comparison of Class with Class failed" -- devise does exactly that.
class A; end
class B < A; end
class C < B; end
module M; end
class D; include M; end

p B < A
p A < B
p B <= A
p B <= B
p A > C
p C >= A
p((C <=> A))
p((A <=> C))
p((A <=> A))
p((A <=> M))
p((D <=> M))
p((A <=> 1))

begin
  A < 1
rescue TypeError => e
  puts e.class
end

# ...and the order is what makes a list of them sortable
p [C, A, B].sort.map(&:name)
p [C, A, B].min.name
p [C, A, B].max.name
p [B, A].sort_by { |k| k.name }.map(&:name)

# unrelated classes compare to nil, and Comparable is not involved
p A.ancestors.include?(Comparable)

# Process.clock_gettime: one clock behind every id, seconds as a Float
t1 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
t2 = Process.clock_gettime(Process::CLOCK_REALTIME)
p t1.class
p t2.class
p t1 >= 0
p Process::CLOCK_MONOTONIC.is_a?(Integer)

# A Symbol matches by way of its name, and a String argument is a PATTERN
p :abc.match?(/b/)
p :abc.match(/b/)[0]
p "abc".match("b")[0]
p(/b/.match(:abc)[0])
p "abc".match?("z")
p "abc".match("z")
m = "a1b2".match(/(\d)(\w)/)
p [m[0], m[1], m[2]]

# a require that raises is NOT loaded: ruby takes the feature back out of
# $LOADED_FEATURES so the next require retries
File.write("/tmp/mrb_corpus_bad.rb", 'raise "boom"')
$LOAD_PATH.unshift("/tmp")
2.times do
  begin
    require "mrb_corpus_bad"
  rescue RuntimeError => e
    puts "raised #{e.message}"
  end
end
p $LOADED_FEATURES.grep(/mrb_corpus_bad/).size
File.delete("/tmp/mrb_corpus_bad.rb")

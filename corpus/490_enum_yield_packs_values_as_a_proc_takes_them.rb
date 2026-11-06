# Several values yielded at once reach an Enumerable method's block in one of
# three ways, method by method, as enum.c's enum_yield hands them: apart (map,
# count, inject, to_h -- rb_yield_values2), packed and given as to a PROC even
# when the block is a lambda (select, find, the *_by family, partition,
# drop_while, each_entry, cycle, zip -- rb_yield_force_blockarg), or packed
# and given as they are (sum, chunk, each_slice). A lambda wanting one took
# the values spread and raised ArgumentError; a Symbol's proc was sent the
# first value with the rest as arguments; count and to_h packed what they
# should spread. A Hash's map and find hand the block's arity to #each, which
# yields the pair apart to a block wanting two.
srcs = { gen: Enumerator.new { |y| y.yield 1, 2; y.yield 3, 4 }, ewi: %w[a b].each_with_index, h: {a: 1, b: 2}.each,
         one: Enumerator.new { |y| y.yield [1, 2]; y.yield [3, 4] }, hd: {a: 1, b: 2} }
blks = { l1: ->(x) { x }, l2: ->(x, y) { y }, lr: ->(*a) { a }, l1o: ->(x, y = 9) { y }, lk: ->(x, k: 1) { x },
         sym: :itself.to_proc, sym2: :first.to_proc, pr: proc { |x| x }, mt: 1.method(:then).to_proc }
ms = %i[map flat_map select find_all reject find detect find_index partition group_by min_by max_by sort_by
        minmax_by drop_while take_while each_entry uniq filter_map count sum chunk_while slice_when any? all?
        none? one? each_slice each_with_index each_cons to_h each_with_object inject chunk slice_before
        slice_after cycle zip]
srcs.each do |sn, e|
  ms.each do |m|
    r = blks.map do |bn, b|
      v = begin
        case m
        when :each_slice, :each_cons then e.send(m, 1, &b)
        when :each_with_object then e.each_with_object([], &b)
        when :inject then e.inject(&b)
        when :cycle then e.cycle(2, &b)
        when :zip then e.zip([7, 8], &b)
        when :chunk_while, :slice_when, :chunk, :slice_before, :slice_after then e.send(m, &b).to_a
        else e.send(m, &b)
        end
      rescue Exception => ex
        ex.class
      end
      v = v.to_a if v.is_a?(Enumerator)
      v = :self if v.equal?(e)
      v
    end
    puts "#{sn} #{m} #{r.inspect}"
  end
end
# the lambda's parameters as a proc's: cut to their number, padded with nil
g3 = Enumerator.new { |y| y.yield 1, 2, 3 }
seen = []
[->(x, y) { seen << [x, y] }, ->(x, y, z, w) { seen << [x, y, z, w] }, ->(x, *r) { seen << [x, r] },
 ->(*r, z) { seen << [r, z] }, ->(x, y = 9, *r, z) { seen << [x, y, r, z] }, ->(x, y, k: 1) { seen << [x, y, k] },
 ->(x, **kw) { seen << [x, kw] }, ->(x, &b) { seen << [x, b] }, -> { seen << 0 }].each { |l| g3.select(&l) }
p seen
def two(a, b) = [a, b]
p((Enumerator.new { |y| y.yield 1, 2 }.select(&method(:two)) rescue $!.class))
p((Enumerator.new { |y| y.yield [1, 2] }.select(&->(x, y) { y }) rescue $!.class))
o = Object.new
def o.to_ary = [7, 8]
p Enumerator.new { |y| y.yield o, 5 }.map(&->(x, y) { y }), Enumerator.new { |y| y.yield o, 5 }.select(&->(x) { x.size }).map { |a| a.map(&:class) }
# a Range's and an Array's zip give a lambda wanting two the tuple spread
p (1..2).zip([3], &->(x, y) { p [x, y] }), [[1, 2]].zip([3], &->(x, y) { p [x, y] })
p (1..2).map.with_index(&->(x, i) { x * i }), %w[a b].each_with_index.to_h(&->(x, i) { [i, x] })
# each_with_index and each_entry answer the receiver, whatever walked it
S = Struct.new(:a)
p({a: 1}.each_with_index { }, (1..2).each_with_index { }, S.new(1).each_with_index { }, (1..2).each_entry { })

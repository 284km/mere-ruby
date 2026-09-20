# Enumerator::Lazy against an INFINITE source. Every operator here used to fall
# through the pipeline's list of known kinds to `lz_run ... (-1)`, which runs
# the source to the end before calling the method -- an allocation loop that
# reached 6-17 GB on grep_v, uniq, with_index and slice_before, and the time
# alarm on chunk, grep, zip and four more. Nothing below can finish unless the
# operator is lazy, which is the point: a wrong answer here HANGS.
#
# Every expected value was measured against the reference ruby, not assumed.
# Two of them are counter-intuitive and both were nearly implemented backwards:
#   - `uniq { blk }` dedupes by the BLOCK's value and emits the ORIGINAL.
#   - `with_index { blk }` runs the block and emits the ORIGINAL, so
#     `inf.with_index { 99 }.first(3)` is [1, 2, 3] and not [99, 99, 99].

def inf = (1..Float::INFINITY).lazy
fin = [3, 1, 3, 2, nil, 1].lazy

p inf.grep(2..4).first(3)
p inf.grep(2..4) { |x| x * 10 }.first(3)
p inf.grep_v(2..4).first(3)
p fin.uniq.force
p [3, 1, 3, 2, nil, 1].lazy.uniq { |x| x.to_s }.force
p [3, 1, 3, 2, nil, 1].lazy.compact.force
p inf.flat_map { |x| [x, -x] }.first(4)
p inf.flat_map { |x| x }.first(3)
p inf.with_index.first(3)
p inf.with_index(10).first(3)
p inf.with_index { |x, i| 99 }.first(3)
p inf.each_with_index.first(3)
p inf.zip([4, 5], [8]).first(2)
p inf.zip([4]).first(3)
p inf.to_enum.first(3)

# to_enum hands back a NEW Lazy, not the receiver and not a plain Enumerator.
# A generic `to_enum` arm 3700 lines earlier was answering for every object,
# which made the Lazy one unreachable and this the witness for that too.
e = inf
p e.to_enum.class
p e.to_enum.equal?(e)

# ...and the operators that were already lazy still are.
p inf.map { |x| x * 2 }.first(3)
p inf.select(&:even?).first(3)
p inf.reject(&:even?).first(3)
p inf.take_while { |x| x < 4 }.force
p inf.drop_while { |x| x < 3 }.first(2)
p inf.take(3).force
p inf.drop(2).first(2)
p inf.filter_map { |x| x * 2 if x.odd? }.first(3)

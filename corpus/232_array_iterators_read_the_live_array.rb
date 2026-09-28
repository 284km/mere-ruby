# Array's iterators read the LIVE array on every step (RARRAY_LEN and
# RARRAY_AREF), so an element the block pushes is yielded too; take_while and
# drop_while answer a prefix / suffix of the array as it is when the walk
# stops. The in-place filters keep the length until the walk ends and then
# close up what was kept -- also when the block raises or breaks -- and
# answer nil only when nothing was dropped. A break's value is the answer of
# every one of them.
%i[each each_index map collect select filter reject find_index index rindex count take_while drop_while sort_by! map! collect! select! filter! reject! delete_if keep_if sum uniq any? all? none? one? min_by max_by minmax_by partition each_with_index each_slice each_cons flat_map sum].each do |m|
  array = [1, 2, 3]; add = [:a, :b] + (4..20).to_a; rec = []; i = 0
  begin
    array.send(m) { |e| rec << e; array << add[i] if i < add.size; i += 1; nil }
  rescue => ex
    rec = ex.class
  end
  p [m, rec.is_a?(Array) ? rec.size : rec]
end

a = [1, 2, 3, 4, 5]
p a.select! { |e| p a.length; e.odd? }, a
a = [1, 2, 3, 4, 5]
begin
  a.reject! { |e| raise "x" if e == 4; e.even? }
rescue => ex
  p ex.message
end
p a
a = [1, 2, 3, 4, 5]
p a.delete_if { |e| break :b if e == 4; e.even? }, a
a = [1, 2, 3]
p a.select! { |e| a << 9 if a.size < 5; true }, a
a = [1, 2, 3]
p a.keep_if { |e| e > 1 }, a.frozen?
a = [1, 2, 3]
p a.map! { |e| a << 0 if a.size < 5; e * 10 }
a = [1, 2, 3]
begin; a.map! { |e| raise "m" if e == 2; e * 10 }; rescue => ex; p ex.message; end
p a
a = [3, 1, 2]
p a.sort_by! { |e| a << 0 if a.size < 4; e }
a = [1, 1, 2, 3]
p a.uniq { |e| a << 7 if a.size < 6; e }, a.uniq!, a
p [1, 2, 3].take_while { |e| e < 3 }, [1, 2, 3].drop_while { |e| e < 2 }
a = [1, 2]
p a.to_h { |e| a << 5 if a.size < 3; [e, e.to_s] }
begin; [1, 2, 3].to_h { |e| p e; e == 2 ? 1 : [e, e] }; rescue => ex; p ex.class, ex.message; end
p [1, 2, 3].any? { break 5 }, [1, 2].min_by { |x| -x }, [1, 2, 3].minmax_by { |x| x % 3 }
p [1,2,3].sum { |x| x * 2 }, [1, 2, 3, 4].partition(&:even?), [1, 2, 3].find_index { |x| x == 2 }

p [1, 2].any? { break 5 }, [1, 2].all? { break 6 }, [1, 2].none? { break 7 }, [1, 2].find_index { break 8 }
p [1, 2].sum { break 9 }, [1, 2].partition { break 10 }, [1, 2].min_by { break 11 }, [1, 2].max_by { |x| break 12 if x == 2; x }
p [1, 2].minmax_by { break 13 }, [1, 2].minmax_by { |x| break 14 if x == 2; x }, [1, 2].one? { break 15 }, [1, 2].count { break 16 }

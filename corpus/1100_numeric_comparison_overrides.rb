# Ruby's literal min/max instructions and Array methods compare in opposite
# directions. A redefined Rational#<=> must run in both paths and in sorting.
# Prime the plain-comparator cache before a method-table change.
p [Rational(1, 2), Rational(1, 3)].max
class Rational
  alias original_compare_1100 <=>
  def <=>(other)
    $comparisons_1100 << [numerator, denominator, other.numerator, other.denominator]
    $answer_1100
  end
end

[1, -1, 0, nil].each do |answer|
  $answer_1100 = answer
  [:max, :min, :minmax, :sort, :sort!].each do |method|
    $comparisons_1100 = []
    values = [Rational(1, 2), Rational(1, 3)]
    begin
      p [answer, method, values.send(method)]
    rescue ArgumentError => error
      p [answer, method, error.class, error.message]
    end
    p $comparisons_1100
  end
  $comparisons_1100 = []
  begin
    p [answer, :literal_max, [Rational(1, 2), Rational(1, 3)].max]
  rescue ArgumentError => error
    p [answer, :literal_max, error.class, error.message]
  end
  p $comparisons_1100
  $comparisons_1100 = []
  begin
    p [answer, :literal_min, [Rational(1, 2), Rational(1, 3)].min]
  rescue ArgumentError => error
    p [answer, :literal_min, error.class, error.message]
  end
  p $comparisons_1100
  $comparisons_1100 = []
  begin
    p [answer, :static_max, [0.5r, 0.25r].max]
    p [answer, :static_min, [0.5r, 0.25r].min]
  rescue ArgumentError => error
    p [answer, :static, error.class, error.message]
  end
  p $comparisons_1100
  $comparisons_1100 = []
  tail = [0.25r]
  begin
    p [answer, :splat_max, [0.5r, *tail].max]
    p [answer, :splat_min, [0.5r, *tail].min]
  rescue ArgumentError => error
    p [answer, :splat, error.class, error.message]
  end
  p $comparisons_1100
end

class Rational
  alias <=> original_compare_1100
end
p [Rational(1, 2), Rational(1, 3)].max
p [Rational(1, 2), Rational(1, 3)].min
p [Rational(1, 2), Rational(1, 3)].sort

# Static Float arrays and splats also use ordinary Array comparison order.
class Float
  alias original_compare_1100 <=>
  def <=>(other) = 1
end
p [1.5, 2].max
p [1.5, 2].min
float_tail = [2]
p [1.5, *float_tail].max
p [1.5, *float_tail].min
p [1.5, Float(2)].max
class Float
  alias <=> original_compare_1100
end

# A replacement Array method still owns the literal call.
def replace_max_1100
  Array.class_eval { define_method(:max) { :replaced_during_arguments } }
  Rational(1, 2)
end
p [replace_max_1100, Rational(1, 3)].max

class Array
  def max = :replacement_max
  def min = :replacement_min
end
p [Rational(1, 2), Rational(1, 3)].max
p [Rational(1, 2), Rational(1, 3)].min

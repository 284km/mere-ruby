# Ruby's literal min/max instructions and Array methods compare in opposite
# directions. A redefined Rational#<=> must run in both paths and in sorting.
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
end

class Rational
  alias <=> original_compare_1100
end
p [Rational(1, 2), Rational(1, 3)].max
p [Rational(1, 2), Rational(1, 3)].min
p [Rational(1, 2), Rational(1, 3)].sort

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

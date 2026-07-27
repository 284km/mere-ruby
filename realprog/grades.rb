# A small, idiomatic grade-report generator. No gems, deterministic output.

Student = Struct.new(:name, :scores) do
  def average
    scores.sum.to_f / scores.size
  end

  def grade
    case average
    when 90.. then "A"
    when 80...90 then "B"
    when 70...80 then "C"
    when 60...70 then "D"
    else "F"
    end
  end
end

class Roster
  include Enumerable

  def initialize(students)
    @students = students.freeze
  end

  def each(&block)
    @students.each(&block)
  end

  def ranked
    sort_by { |s| [-s.average, s.name] }
  end

  def by_grade
    group_by(&:grade).transform_values { |group| group.map(&:name).sort }
  end

  def class_average
    map(&:average).inject(:+) / count
  end
end

roster = Roster.new([
  Student.new("Alice",   [92, 88, 95]),
  Student.new("Bob",     [70, 75, 68]),
  Student.new("Carol",   [55, 60, 58]),
  Student.new("Dave",    [81, 79, 85]),
  Student.new("Eve",     [90, 91, 89]),
])

puts "== Ranking =="
roster.ranked.each_with_index do |s, i|
  puts format("%2d. %-6s %5.1f  (%s)", i + 1, s.name, s.average, s.grade)
end

puts
puts "== By grade =="
roster.by_grade.sort.each do |letter, names|
  puts "#{letter}: #{names.join(', ')}"
end

puts
puts format("Class average: %.2f", roster.class_average)

counts = roster.each_with_object(Hash.new(0)) { |s, h| h[s.grade] += 1 }
puts "Distribution: " + counts.sort.map { |g, n| "#{g}=#{n}" }.join(" ")

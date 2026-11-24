require 'rbconfig'

# Each child owns its method-table changes. The VM environment is inherited
# too, so both the outer program and its probes use the requested engine.
probes = {
  ancestor: <<~'RUBY',
    module Comparable
      def <(other) = :comparable
    end
    p [1 < 2, 1.5 < 2, (2**70) < 1, Rational(1, 2) < 1]
    p [1.send(:<, 2), 1.5.send(:<, 2), (2**70).send(:<, 1)]
    class Numeric
      def -(other) = :numeric
    end
    p [5 - 2, 1.5 - 1, (2**70) - 1, Complex(1, 1) - 1]
    p [5.send(:-, 2), Complex(1, 1).send(:-, 1)]
  RUBY
  comparison: <<~'RUBY',
    class Rational
      def <=>(other) = 1
    end
    r = Rational(1, 2)
    p [r < 1, r <= 1, r > 1, r >= 1]
    p [r.send(:<, 1), r.send(:>, 1)]
    target = Object.new
    def target.coerce(other) = raise('the overridden comparator wins')
    p [r < target, r > target]
  RUBY
  coercion: <<~'RUBY',
    class Rational
      def *(other) = [:rational, self, other]
    end
    r = Rational(1, 2)
    p 2 * r
    p (2**70) * r
    p 2.send(:*, r)
    p 2.0 * r
  RUBY
  same_class: <<~'RUBY',
    class Integer
      def <(other) = :integer
    end
    p [1 < 2, (2**70) < 1, 1.send(:<, 2)]
    class Float
      def -(other) = :float
    end
    p [1.5 - 1, 1.5.send(:-, 1)]
  RUBY
  prepend: <<~'RUBY'
    module BeforeInteger
      def <(other) = :prepended
    end
    Integer.prepend(BeforeInteger)
    p [1 < 2, (2**70) < 1, 1.send(:<, 2)]
  RUBY
}

probes.each do |name, source|
  p name
  IO.popen([RbConfig.ruby, '-e', source]) { |child| print child.read }
  raise "probe failed: #{name}" unless $?.success?
end

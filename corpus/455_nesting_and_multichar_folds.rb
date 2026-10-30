# A `class << self` opened in a method is nested in the method's nesting:
# Module.nesting there has the singleton and the class, and a constant of
# the class is found.
class TS455
  K = 1
  def self.m
    class << self
      p Module.nesting.size
      p K
    end
  end
  # ...and a proc written in a class body is in that nesting wherever it
  # runs -- under instance_eval, too, and so is the singleton it opens.
  PR = proc do
    p Module.nesting
    p K
    class << self
      p Module.nesting.size
      def via_overlay = K
    end
  end
end
TS455.m
o = Object.new
o.instance_eval(&TS455::PR)
p o.via_overlay
TS455::PR.call rescue p $!.class

# [ruby-core:27230]: an overlay that calls super and re-applies itself
class Indexed455
  def subseq = SubSeq455.new
end
class SubSeq455; end
class TS455
  Overlaid = proc do
    class << self
      def subseq
        super.instance_eval(&Overlaid)
      end
    end
  end
end
mid = Indexed455.new
mid.instance_eval(&TS455::Overlaid)
p mid.subseq.class
p mid.subseq.class

# Under /i a run of pattern characters that spells the full fold of one
# character matches that character -- non-ASCII runs too, written as
# characters or as \u escapes.
p(/^ΐ$/i =~ "ΐ")
p(/^ΐ$/i =~ "ΐ")
p(/^ʼn$/i =~ "ŉ")
p(/^ΐ$/i =~ "ΐ")
p(/ss/i =~ "ß", /^ss$/i =~ "ß")
p(/^ἀι$/i =~ "ᾀ")

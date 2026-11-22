module CopiedMethodBodySource
  OFFSET = 7
  def score(value)
    value + OFFSET
  end
end

body = CopiedMethodBodySource.instance_method(:score)
retained = []
3.times do
  96.times do |index|
    owner = Class.new
    owner.define_method(:score, body)
    owner.alias_method(:other, :score)
    retained << owner.new if index % 31 == 0
  end
  GC.start
  p retained.map { |object| [object.score(2), object.other(4), object.method(:score).owner == object.class] }
end

$memo_events = []
class ConditionalClassVariables
  def self.statement
    @@statement ||= ($memo_events << :statement; "A0")
  end

  def self.expression
    (@@expression ||= ($memo_events << :expression; "B0")).succ
  end

  def self.false_value
    (@@false_value ||= ($memo_events << :false; false))
  end

  def self.and_undefined
    @@and_missing &&= ($memo_events << :and; true)
  end

  def self.ordinary_read
    @@ordinary = @@ordinary || ($memo_events << :ordinary; true)
  end

  def self.arithmetic
    @@arithmetic += ($memo_events << :arithmetic; 1)
  end
end
2.times do
  p [ConditionalClassVariables.statement, ConditionalClassVariables.expression,
     ConditionalClassVariables.false_value]
end
[:and_undefined, :ordinary_read, :arithmetic].each do |method|
  begin
    ConditionalClassVariables.send(method)
  rescue NameError => error
    p [error.class, error.name, error.receiver]
  end
end
p $memo_events
ConditionalClassVariables.freeze
p [ConditionalClassVariables.statement, ConditionalClassVariables.expression]
begin
  ConditionalClassVariables.false_value
rescue FrozenError => error
  p [error.class, error.receiver == ConditionalClassVariables]
end

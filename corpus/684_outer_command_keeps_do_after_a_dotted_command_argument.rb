class CommandBuilder
  def self.build(value)
    [value, block_given?, block_given? && yield]
  end
end

def outer_command(value)
  [value, block_given?, block_given? && yield]
end

result = outer_command CommandBuilder.build :argument do
  :outer
end
p result
result = outer_command CommandBuilder&.build :safe_argument do
  :safe_outer
end
p result
result = outer_command nil&.build :skipped do
  :nil_outer
end
p result

# A command that is not itself an argument still owns its trailing do.
result = CommandBuilder.build :direct do
  :direct_block
end
p result
result = CommandBuilder&.build :safe_direct do
  :safe_direct_block
end
p result
result = outer_command CommandBuilder.build(:parenthesized) do
  :outer_after_parentheses
end
p result
result = outer_command CommandBuilder.build(:brace) { :inner_brace }
p result

def middle_command(value)
  [:middle, value, block_given?]
end
result = outer_command middle_command CommandBuilder.build :nested do
  :outermost
end
p result

class CommandFilter
  attr_reader :pattern, :had_block
  def initialize(pattern)
    @pattern, @had_block = pattern, block_given?
  end
end
def with_command_filter(filter)
  p [filter.pattern, filter.had_block]
  Mutex.new.synchronize { yield }
end
def with_empty_command_filter
  with_command_filter CommandFilter.new %r%.% do
    yield
  end
end
p(with_empty_command_filter { :yield_reached })

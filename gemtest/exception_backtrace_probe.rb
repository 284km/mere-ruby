# Regression for implicit native Exception dispatch from a custom initializer.
# Both Ruby 4.0.9 and mere-ruby print ["example:1"].
class GemtestBacktraceError < StandardError
  def initialize
    super('example')
    set_backtrace(['example:1'])
  end
end
p GemtestBacktraceError.new.backtrace

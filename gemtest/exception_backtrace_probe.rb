# Diagnostic for the next core task; not part of the passing OpenSSL selection.
# Ruby 4.0.9 prints ["example:1"]. mere-ruby currently raises NoMethodError.
class GemtestBacktraceError < StandardError
  def initialize
    super('example')
    set_backtrace(['example:1'])
  end
end
p GemtestBacktraceError.new.backtrace

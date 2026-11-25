class SqrtArity1101
  def self.m = Integer.sqrt
end

def report_1101
  p yield
rescue ArgumentError => error
  p [error.class, error.message]
end

report_1101 { SqrtArity1101.m }
report_1101 { Integer.sqrt }
report_1101 { Integer.send(:sqrt) }
report_1101 { Integer.method(:sqrt).call }
report_1101 { Integer.sqrt(4, 9) }
report_1101 { Integer.send(:sqrt, 4, 9, 16) }
report_1101 { Integer.sqrt(0) }
report_1101 { Integer.sqrt(17) }
report_1101 { Integer.sqrt(10**40) }
report_1101 { Integer.sqrt(17) { :ignored } }

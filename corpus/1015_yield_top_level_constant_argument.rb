module YieldRoot1015
  VALUE = :root
end
module YieldResult1015
  VALUE = :from_block
end
def yield_root1015
  yield ::YieldRoot1015::VALUE
end
def yield_receiver1015
  yield::VALUE
end
p yield_root1015 { |value| [:yielded, value] }
p yield_receiver1015 { YieldResult1015 }
def conditional_yield1015(enabled)
  yield ::YieldRoot1015::VALUE if enabled
end
p conditional_yield1015(false) { raise 'must not yield' }
p conditional_yield1015(true) { |value| value }

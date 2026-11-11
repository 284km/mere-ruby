require 'nkf'
workers = 4.times.map do |worker|
  Thread.new do
    100.times do |iteration|
      source = "あ#{worker}:#{iteration}"
      encoded = NKF.nkf('-s', source)
      raise 'thread conversion changed' unless NKF.nkf('-Sw', encoded) == source
      raise 'thread guess changed' unless NKF.guess(source) == Encoding::UTF_8
      Thread.pass
    end
    :complete
  end
end
p workers.map(&:value)
ready, proceed = Queue.new, Queue.new
source = Object.new
source.define_singleton_method(:to_str) do
  ready << true
  proceed.pop
  'あ'
end
outer = Thread.new do
  result = NKF.nkf('-w', source)
  [result.bytes, result.encoding.name]
end
ready.pop
NKF.nkf('-s', 'inner')
proceed << true
p outer.value
p NKF.nkf('-w', 'あ')

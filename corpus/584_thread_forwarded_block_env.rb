class SharedAPI
  def self.open(&block)
    new.start(&block)
  end
  def start
    Thread.pass
    yield self
  end
  def request
    Thread.pass
    yield :response if block_given?
  end
end
class FirstClient
  def run
    options=:first
    SharedAPI.open do |http|
      http.request { |response| raise 'wrong first closure' unless options==:first }
    end
  end
end
class SecondClient
  def run
    other=:second
    SharedAPI.open do |http|
      http.request
      raise 'wrong second closure' unless other==:second
    end
  end
end
20.times do
  one=Thread.new { FirstClient.new.run }
  two=Thread.new { SecondClient.new.run }
  one.value
  two.value
end
puts 'thread blocks preserved'

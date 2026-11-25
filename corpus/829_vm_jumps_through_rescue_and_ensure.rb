# Leaving a protected region every way there is, on the VM as in ruby: a
# return, a break, a next and a redo thrown from the body, from a rescue
# clause and from an ensure; a retry; an exception raised again; a raise
# that no clause takes; and a frame with none of these, whose regions only
# catch.
log = []

def ret_from_body
  begin
    return :body
  ensure
    $log << :ensure1
  end
  :after
end

def ret_from_rescue
  begin
    raise "x"
  rescue
    return :rescue
  ensure
    $log << :ensure2
  end
  :after
end

def ret_from_ensure
  begin
    :body
  ensure
    return :ensure
  end
end

def plain_rescue(n)
  begin
    raise ArgumentError, "a" if n.odd?
    n
  rescue ArgumentError => e
    [e.message, n]
  end
end

def nested_unmatched(n)
  begin
    begin
      raise TypeError, "t#{n}"
    rescue ArgumentError
      :wrong
    end
  rescue TypeError => e
    e.message
  end
end

def retries
  tries = 0
  begin
    tries += 1
    raise "again" if tries < 3
    tries
  rescue
    retry
  end
end

def reraise
  begin
    raise KeyError, "k"
  rescue KeyError
    raise
  end
rescue => e
  [e.class, e.message]
end

$log = []
p ret_from_body, ret_from_rescue, ret_from_ensure, $log
p (1..4).map { |n| plain_rescue(n) }
p (1..3).map { |n| nested_unmatched(n) }
p retries, reraise

r = [1, 2, 3, 4].map do |x|
  begin
    raise "x" if x == 2
    next :next_body if x == 3
    x
  rescue
    next :next_rescue
  ensure
    log << x
  end
end
p r, log

r = []
[1, 2, 3].each do |x|
  begin
    raise "x" if x == 2
    r << x
  rescue
    break
  ensure
    r << :e
  end
end
p r

r = []
i = 0
while i < 5
  i += 1
  begin
    raise "odd" if i.odd?
    r << i
  rescue
    next
  ensure
    r << :ens
  end
  break if i == 4
end
p r

seen = []
done = false
[1].each do |x|
  begin
    seen << x
    unless done
      done = true
      redo
    end
  rescue
    :never
  end
end
p seen

def lam
  l = lambda do
    begin
      raise "x"
    rescue
      return :from_lambda
    end
  end
  [l.call, :after]
end
p lam

def blk_ret
  [1, 2].each do |x|
    begin
      raise "x" if x == 2
    rescue
      return [:blk_return, x]
    end
  end
  :not_here
end
p blk_ret

count = 0
100.times do
  begin
    raise IndexError
  rescue IndexError
    count += 1
  end
end
p count

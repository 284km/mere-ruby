target = Class.new { def marker; :marker; end }.new
target.class.send(:private, :public_method)
begin
  target.public_method(:marker)
  raise 'private public_method was bypassed'
rescue NoMethodError => error
  p [error.name, error.receiver.equal?(target)]
end
p target.send(:public_method, :marker).call
target.class.send(:public, :public_method)
p target.public_method(:marker).call

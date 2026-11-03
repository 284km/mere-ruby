require 'socket'
[IO, BasicSocket, IPSocket, TCPSocket, UNIXSocket].each do |klass|
  object = klass.allocate
  p [klass, object.inspect.sub(/0x[0-9a-f]+/, 'OBJECT')]
  [:closed?, :fileno, :read, :close].each do |method|
    begin
      object.public_send(method)
    rescue IOError => error
      p [method, error.class, error.message]
    end
  end
end
class CustomStream < IO
  def closed?; :custom; end
end
p CustomStream.allocate.closed?
a, b = UNIXSocket.pair(:STREAM, 0)
p [a.closed?, b.closed?]
a.close
p [a.closed?, a.inspect]
b.close
# A registered IO subclass also owns a descriptor in the standard range.
original, peer = UNIXSocket.pair
STDIN.reopen(original)
original.close
low = UNIXSocket.for_fd(0)
p [low.fileno == 0, low.closed?]
low.write('ok')
p peer.read(2)
low.close
peer.close

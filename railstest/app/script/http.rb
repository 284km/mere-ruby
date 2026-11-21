require "puma/server"
require "net/http"
server = Puma::Server.new(Rails.application)
begin
  server.add_tcp_listener("127.0.0.1", 0)
  server.run
  port = server.connected_ports.first
  http = Net::HTTP.new("127.0.0.1", port, nil)
  response = http.get("/notes")
  abort "unexpected HTTP response" unless response.code == "200" && response.body.include?("<h1>Notes</h1>")
  puts "puma-http-ok"
ensure
  server.stop(true)
end

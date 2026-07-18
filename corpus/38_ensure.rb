begin
  puts "body"
ensure
  puts "ensure runs"
end

begin
  raise "err"
rescue
  puts "rescued"
ensure
  puts "ensure after rescue"
end

def with_cleanup
  begin
    return "result"
  ensure
    puts "cleanup"
  end
end
puts with_cleanup

begin
  puts "ok"
rescue
  puts "no"
else
  puts "else branch"
ensure
  puts "done"
end

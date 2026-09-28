# Three predefined globals that did not behave as ruby's do:
#   `$@ = x` is `$!.set_backtrace(x)`, and with nothing rescued it refuses --
#   the assignment used to land in a slot nobody reads;
#   $-a / $-l / $-p say whether the -a / -l / -p switch was given (false
#   here), and they are read-only;
#   $_, the last line `gets` read, belongs to the thread that read it.
begin
  raise "boom"
rescue
  $@ = ["somewhere.rb:1", "elsewhere.rb:2"]
  p $@, $!.backtrace
end
begin
  $@ = []
rescue ArgumentError => e
  p e.message
end
p $-a, $-l, $-p
%w[a l p].each do |sw|
  begin
    eval("$-#{sw} = true")
  rescue NameError => e
    p e.message
  end
end
$_ = "line of main"
Thread.new { p $_; $_ = "line of the thread"; p $_ }.join
p $_

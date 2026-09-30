# An assignment makes its name a local from where it is written, whether or
# not it runs -- and that includes one nested inside a begin, a loop or a case
# of the branch that did not run. resolv.rb's Hosts reads `hosts` after
#   if windows; begin; hosts = ...; rescue LoadError; end; end
# and every require of net/http went through that line.
if false
  begin
    a = 1
  rescue LoadError
  end
end
p a

if false
  while true
    b = 2
  end
end
p b

begin
  raise "stop"
  c = 3
rescue
end
p c

while false
  d = 4
end
p d

case 1
when 2
  e = 5
end
p e

begin
rescue => err
  f = 6
end
p [f, err]

class Hosts
  if /mswin|mingw/ =~ RUBY_PLATFORM
    begin
      require "win32/resolv"
      hosts = "C:/hosts"
    rescue LoadError
    end
  end
  DefaultFileName = hosts || "/etc/hosts"
end
p Hosts::DefaultFileName

def m
  if false
    begin
      g = 7
    ensure
    end
  end
  [g, binding.local_variable_defined?(:g)]
end
p m

# a branch that DID run keeps its value
x = 1
if true
  begin
    x = 2
  rescue
  end
end
p x

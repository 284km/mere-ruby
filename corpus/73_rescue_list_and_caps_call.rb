# A rescue class list wraps after a comma, and an item may be any expression
# -- net/http picks one with a ternary, across four lines with a comment in
# the middle.
module OS
  module SSL
    class SSLError < StandardError; end
  end
end

def boom(k)
  begin
    raise k, "x"
  rescue ArgumentError,
         IOError,
         # a comment inside the list is just a blank line
         defined?(OS::SSL) ? OS::SSL::SSLError : IOError,
         TypeError => e
    [:caught, e.class]
  rescue => e
    [:other, e.class]
  end
end

p boom(IOError)
p boom(ArgumentError)
p boom(TypeError)
p boom(OS::SSL::SSLError)
p boom(RuntimeError)

# the ternary picks the OTHER branch when the constant is undefined
def boom2
  raise IOError, "x"
rescue defined?(NoSuchThing) ? NoSuchThing : IOError => e
  e.class
end
p boom2

# a splat item wraps too
CLASSES = [KeyError, IndexError]
def boom3
  raise KeyError, "k"
rescue ArgumentError,
       *CLASSES => e
  e.class
end
p boom3

# A capitalized name followed by a double-quoted string is a METHOD CALL:
# a constant takes no argument. net/protocol logs with `LOG "reading..."`.
def LOG(m) = "log:#{m}"
def Wrap(x) = [x]

n = 3
p LOG "reading #{n} bytes"
p LOG 'single'
p LOG :sym
p Wrap (1..3).to_a
p LOG(!nil)
p LOG !nil

# ...while a real constant with the same shape stays a constant
module Deep
  module Inner
    VALUE = 9
  end
end
p Deep::Inner::VALUE
p Deep::Inner
ARR = [1, 2]
p ARR[0]
p ARR.size

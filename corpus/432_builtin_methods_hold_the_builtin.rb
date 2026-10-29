# A Method or UnboundMethod made from a builtin holds that builtin: binding
# it to an object whose class overrides the name, or calling it after the
# name was redefined, runs the builtin, as ruby's does.

def show(label)
  r = yield
  puts "#{label}: #{r.inspect}"
rescue => e
  puts "#{label}: #{e.class}: #{e.message}"
end

class S < String
  def upcase = "overridden"
end
show("bind_call over an override") { String.instance_method(:upcase).bind_call(S.new("a")) }
show("bind then call") { String.instance_method(:upcase).bind(S.new("b")).call }
show("the override itself") { S.new("c").upcase }

abs = Integer.instance_method(:abs)
show("before redefinition") { abs.bind(-4).call }
class Integer
  alias __corpus_abs abs
  def abs = :redefined
end
show("after redefinition") { abs.bind(-4).call }
show("the name now") { -4.abs }
class Integer
  alias abs __corpus_abs
end
show("restored") { -4.abs }

class O
  def initialize_copy(o) = :own
  def to_s = "O!"
end
show("Object#initialize_copy, other class") { Object.instance_method(:initialize_copy).bind_call(O.new, "s") }
show("Object#initialize_copy, same class") { Object.instance_method(:initialize_copy).bind_call(O.new, O.new).class }
show("Kernel#to_s") { Kernel.instance_method(:to_s).bind_call(O.new).start_with?("#<O:") }

up = "a".method(:upcase)
class String
  alias __corpus_up upcase
  def upcase = "z"
end
show("Method made before") { up.call }
class String
  alias upcase __corpus_up
end
show("restored upcase") { "a".upcase }

# a user method's Method is not a builtin's: it runs what it was made from
class U
  def m = :first
end
um = U.new.method(:m)
class U
  def m = :second
end
show("user method made before") { um.call }

# an operator aliased to another builtin is that builtin
class Integer
  alias __corpus_minus -
  alias - +
end
x = 3
show("Integer - as +") { [3 - 2, x - 2] }
class Integer
  alias - __corpus_minus
end
show("Integer - restored") { [3 - 2, x - 2] }
class Float
  alias __corpus_div /
  alias / *
end
show("Float / as *") { 3.0 / 2.0 }
class Float
  alias / quo
end
# (Float#quo asks `/` again, and a guard stops it reaching itself)
show("Float / as quo") { 1.0 / 2.0 }
class Float
  alias / __corpus_div
end
show("Float / restored") { 3.0 / 2.0 }

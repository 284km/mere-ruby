# `def (expr).name; end` defines a singleton method on whatever the parenthesised
# expression is. Only a bare name or `self.` was accepted after `def`, so five
# spec files did not parse at all -- and a parse error takes the whole file with
# it.
def (nil).from_nil; :nil_one; end
p nil.from_nil

def (true).from_true; :true_one; end
p true.from_true

def (false).from_false; :false_one; end
p false.from_false

# nil, true and false are singletons -- there is one of each -- so a singleton
# method on one is an instance method of its class, and that is how it is
# defined rather than by registering a key that resolves somewhere else.
p NilClass.instance_method(:from_nil).owner

S = +"a string"
def (S).shout; upcase + "!"; end
p S.shout

o = Object.new
def (o).hi; :hello; end
p o.hi
p (Object.new.respond_to?(:hi))

arr = [3, 1, 2]
def (arr).second; self[1]; end
p arr.second
p [3, 1, 2].respond_to?(:second)

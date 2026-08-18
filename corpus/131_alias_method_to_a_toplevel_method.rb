# A top-level `def` is stored under its bare name here, with no class prefix, so
# `alias_method :new_name, :toplevel_one` found nothing and silently made NO
# alias -- the builtin kept answering. Ruby finds it (a top-level def is a
# private method on Object) and the alias is private too.
def ret1; 1; end

k = Class.new do
  def call_it(kl, name)
    kl.alias_method(name, :ret1)
    hash                      # the alias, once name is :hash
  end
end
i = k.new
p i.call_it(k, :hash)

# the alias is PRIVATE, like its source: reachable with an implicit receiver,
# not from outside
k2 = Class.new do
  def reach; bar; end
end
k2.alias_method(:bar, :ret1)
p k2.new.reach
begin
  k2.new.bar
rescue NoMethodError => e
  puts "outside: NoMethodError"
end

# aliasing an ordinary method is unchanged, and stays public
k3 = Class.new do
  def own; 2; end
end
k3.alias_method(:same, :own)
p k3.new.same
p k3.new.own

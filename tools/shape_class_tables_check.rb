# A class's counts beside the shapes (note 559 step 2b): how many variations
# it has made, how big its objects' areas start. They are kept by the class's
# name, and the shape bound does not bound them: a Class.new a turn whose
# object takes @x adds a key and no shape. The collector drops a dead class's
# keys with its other tables (gc_sweep_classes). run_corpus.sh runs this with
# MERE_RUBY_STORE_STATS=1 and reads the rows sh_cls_var and sh_cls_cap.
N = 3_000
N.times do |i|
  k = Class.new
  k.new.instance_variable_set(:@x, i)
  # (a second shape beside the first: a variation of the class)
  o = k.new
  o.instance_variable_set(:@y, i)
  o.instance_variable_set(:@x, i)
  # an object's singleton class
  s = Object.new
  s.singleton_class
  s.instance_variable_set(:@z, i)
end
3.times { GC.start }

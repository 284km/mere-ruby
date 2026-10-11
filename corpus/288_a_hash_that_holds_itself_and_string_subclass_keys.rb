# A key that contains the hash it is stored in -- `h[h] = :foo` -- was lost:
# the key's digest folds that hash, and the fold took away the queue the pair
# was about to go into (note 305). Ruby keeps the pair; the key's hash changed
# by being stored, so a lookup needs #rehash, as in ruby.
h = {}
h[h] = :foo
p h.size, h.empty?, h.keys.size
g = {a: 1}
g[g] = 2
p g.size, g.keys.map(&:class)
k = {}
k[[k]] = 3
k[:x] = 4
p k.size, k.values
s = {}
s.store(s, 5)
p s.size

# A String key is copied and frozen only when its class IS String: an
# instance of a subclass is stored as it is.
class MyStr < String; end
key = MyStr.new("key")
x = {}
x[key] = 1
p x.keys[0].class, x.keys[0].frozen?, x.keys[0].equal?(key)
y = {MyStr.new("lit") => 2}
p y.keys[0].class, y.keys[0].frozen?
plain = "plain"
z = {}
z[plain] = 3
p z.keys[0].class, z.keys[0].frozen?, z.keys[0].equal?(plain)
sing = +"sing"
def sing.extra = 1
w = {}
w[sing] = 4
p w.keys[0].frozen?, w.keys[0].equal?(sing), w.keys[0].respond_to?(:extra)

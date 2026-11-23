# Around Proc#extend (corpus 896): a frozen proc refuses it, Module#=== sees
# the module, and #singleton_methods lists the module's methods
module M4; def hi = :hi; def self.x = 1; end
pr = proc { 1 }
pr.extend(M4)
p M4 === pr, pr.is_a?(M4), pr.singleton_methods.sort, pr.singleton_methods(false)
p pr.singleton_class.include?(M4)
f = proc { 2 }.freeze
begin
  f.extend(M4)
  p :no_error
rescue => e
  p e.class
end
l = lambda { 3 }
def l.own = 1
p l.singleton_methods
case pr
when M4 then p :matched
else p :not_matched
end
s = +"str"
s.extend(M4)
p M4 === s, s.singleton_methods

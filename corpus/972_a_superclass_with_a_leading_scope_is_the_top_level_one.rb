# A superclass written `::Company` is the top-level constant, whatever the
# scope it is written in holds. The leading `::` was dropped, and the name
# was then looked up from the scope: in activerecord's test models,
#   module Namespaced
#     class Company < ::Company; end
#     class Firm < ::Company; end
#   end
# Firm became a subclass of Namespaced::Company. The class of an expression
# (`class K < expr`) went the same way: it was passed on by name and looked
# up again, which is also how the VM hands every superclass over.
class Company; def self.sub = (@sub ||= []); def self.inherited(k) = (sub << k.name; super); end
module Namespaced
  class Company < ::Company; end
  class Firm < ::Company; end
  class Client < ::Company; end
  class Deep < Company; end
end
p Namespaced::Firm.superclass, Namespaced::Client.superclass, Namespaced::Deep.superclass, Namespaced::Company.superclass
p Company.subclasses.map(&:name).sort, Namespaced::Company.subclasses.map(&:name)
module Namespaced
  X = ::Company
  def self.m = ::Company
  class Again < ::Namespaced::Company; end
end
p Namespaced::X, Namespaced.m, Namespaced::Again.superclass
# an expression for the superclass, an anonymous one, a nested path, a reopen
module Namespaced
  class ByExpr < Object.const_get(:Company); end
  anon = Class.new(::Company)
  class OfAnon < anon; end
  class Path < ::Namespaced::Company; end
  class Firm < ::Company; end
  begin
    class Firm < Company; end
  rescue TypeError => e
    p e.message
  end
  begin
    class Missing < ::NoSuchConstant962; end
  rescue NameError => e
    p e.message
  end
end
p Namespaced::ByExpr.superclass, Namespaced::OfAnon.superclass.superclass, Namespaced::Path.superclass
module Outer2; class Company; end; module In; class K < ::Company; end; class L < Company; end; end; end
p Outer2::In::K.superclass, Outer2::In::L.superclass

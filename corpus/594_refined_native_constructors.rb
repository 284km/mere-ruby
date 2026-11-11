module RefinedFactories
  refine Module.singleton_class do
    def new
      :refined_module
    end
  end
  refine Class.singleton_class do
    def new
      :refined_class
    end
  end
end
using RefinedFactories
p Module.new
p Module.new(&nil)
p Class.new
p Class.new(&nil)

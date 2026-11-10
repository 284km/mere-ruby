module KeywordForwarder
  def self.target(*rest,&block)
    super
  end
  singleton_class.send(:ruby2_keywords,:target)
end
module Kernel
  def target(*args,**kw)
    [args,kw]
  end
end
p KeywordForwarder.target(:path,mode:0666)
p KeywordForwarder.target(:path, **{})
p KeywordForwarder.target(:path, {mode:0666})

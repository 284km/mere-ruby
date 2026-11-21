class RegexMissingReview < Regexp
  def absent(*args, &block); super; end
  def method_missing(name, *args, &block)
    [:missing, self.class, name, args, block && block.call]
  end
  def match?(*args); super; end
end
p RegexMissingReview.new('a').absent(4) { :block }
p RegexMissingReview.new('a').match?('a')
class OrdinaryMissingReview
  def included(*args, &block); super; end
  def method_added(*args, &block); super; end
  def method_missing(name, *args, &block)
    [:missing, self.class, name, args, block && block.call]
  end
end
p OrdinaryMissingReview.new.included(3) { :included_block }
p OrdinaryMissingReview.new.method_added(:foo) { :added_block }
module GenuineHookReview
  def included(*args); super; end
end
module GenuineModuleHookReview
  extend GenuineHookReview
  def self.method_missing(*); raise 'native hook bypassed'; end
end
p GenuineModuleHookReview.send(:included, Object)
class GenuineSingletonHookReview
  def singleton_method_added(name)
    super
  end
end
obj=GenuineSingletonHookReview.new
def obj.example; :ok; end
p obj.example
module HookUndefinedWrapper
  def included(*args, &block); super; end
end
receiver=Module.new
receiver.singleton_class.class_eval { undef_method :included }
receiver.define_singleton_method(:method_missing) do |name, *args, &block|
  [:undefined, name, args, block && block.call]
end
receiver.singleton_class.prepend(HookUndefinedWrapper)
p receiver.send(:included, 3) { :block }

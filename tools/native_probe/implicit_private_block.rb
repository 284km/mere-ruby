# An implicit block call on main can invoke an included private method.
module NativeBuildPrivateCalls
  def public_entry(&block)
    private_entry(&block)
  end
  private
  def private_entry
    block_given? ? yield : :no_block
  end
end
include NativeBuildPrivateCalls
p public_entry
p(public_entry { :block })
p(private_entry { :direct })
begin
  Object.new.private_entry { :wrong }
rescue NoMethodError
  puts :explicit_private_refused
end
def self.private_entry
  yield :singleton
end
p(public_entry { |value| value })

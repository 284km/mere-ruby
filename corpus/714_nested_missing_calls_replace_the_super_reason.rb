class NestedHandledHook
  def self.method_missing(*) = :handled
end
class NestedReasonHook
  def failure(kind)
    super
  end
  def method_missing(name, *args)
    if name == :failure
      if args.first == :raising
        begin
          Object.new.other_missing
        rescue NoMethodError
        end
      elsif args.first == :handled
        NestedHandledHook.other_missing
      end
    end
    super
  end
end
[:raising, :handled].each do |kind|
  begin
    NestedReasonHook.new.failure(kind)
  rescue NoMethodError => error
    p [kind, error.name, error.private_call?, error.message.start_with?('super:')]
  end
end

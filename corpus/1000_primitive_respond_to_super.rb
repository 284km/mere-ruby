[Array, Hash, String].each do |base|
  child = Class.new(base) do
    def respond_to?(name, include_all = false)
      name == :custom || super
    end

    def respond_to_missing?(name, include_all = false)
      name == :dynamic || super
    end

    private
      def hidden; end
  end
  value = child.new
  p [base.name, value.respond_to?(:size), value.respond_to?(:custom),
     value.respond_to?(:dynamic), value.respond_to?(:absent),
     value.respond_to?(:hidden), value.respond_to?(:hidden, true),
     value.send(:respond_to?, :size)]
end

class CheckedArguments < Array
  def respond_to?(*args)
    super
  end
end
[[], [:size, false, :extra]].each do |args|
  begin
    CheckedArguments.new.respond_to?(*args)
  rescue ArgumentError => error
    p [error.class, error.message]
  end
end

def report_missing(receiver, name, *args, **keywords)
  receiver.public_send(name, *args, **keywords)
rescue NoMethodError => error
  p [error.class, error.name, error.args, error.receiver.equal?(receiver),
     error.private_call?, error.message.start_with?("super: no superclass method '")]
end

class ClassMissingReason
  def self.failure(*args, **keywords)
    super
  end
  def self.method_missing(name, *args, **keywords)
    super
  end
end
report_missing(ClassMissingReason, :failure, 1, key: 2)

class ObjectMissingReason
  def failure(*args, **keywords)
    super
  end
  def method_missing(name, *args, **keywords)
    super
  end
end
report_missing(ObjectMissingReason.new, :failure, 3, key: 4)

class DefaultMissingReason
  def failure(*args)
    super
  end
end
report_missing(DefaultMissingReason.new, :failure, 5)

class RemovedReasonParent
  def failure(*) = :must_not_run
  undef_method :failure
end
class RemovedReasonChild < RemovedReasonParent
  def failure(*args)
    super
  end
  def method_missing(name, *args)
    super
  end
end
report_missing(RemovedReasonChild.new, :failure, 6)

class RewrittenMissingReason
  def self.failure(*args)
    super
  end
  def self.method_missing(name, *args)
    super(:rewritten, *args, :extra)
  end
end
report_missing(RewrittenMissingReason, :failure, 7)

# An ordinary missing call after a handled super must keep its own reason.
class HandledMissingReason
  def self.found
    super
  end
  def self.method_missing(name, *args)
    return :handled if name == :found
    super
  end
end
p HandledMissingReason.found
report_missing(HandledMissingReason, :ordinary_missing, 8)
report_missing(ClassMissingReason, :ordinary_missing, 9)

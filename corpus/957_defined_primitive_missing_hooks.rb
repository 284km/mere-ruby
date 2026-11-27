module MissingClaims
  def respond_to_missing?(name, include_private = false)
    (@claims ||= []) << [name, include_private]
    name == :virtual || super
  end

  def claims
    @claims || []
  end
end

class ClaimedHash < Hash
  include MissingClaims
end

class ClaimedString < String
  include MissingClaims
end

class ClaimedArray < Array
  include MissingClaims
end

[ClaimedHash.new, ClaimedString.new, ClaimedArray.new].each do |value|
  p [value.class.name, defined?(value.virtual), defined?(value.absent), value.claims]
end

[{}, "", []].each do |value|
  value.extend(MissingClaims)
  p [:singleton, value.class.name, defined?(value.virtual), value.claims]
end

class HiddenClaim < ClaimedHash
  private
  def virtual
    :hidden
  end
end
value = HiddenClaim.new
p [:private, defined?(value.virtual), value.claims]

class SuppressedClaim < ClaimedHash
  def respond_to?(name, include_private = false)
    name != :respond_to_missing? && super
  end
end
value = SuppressedClaim.new
p [:suppressed, defined?(value.virtual), value.claims]

class OneArgumentClaim < ClaimedHash
  def respond_to?(name)
    name == :respond_to_missing?
  end
end
value = OneArgumentClaim.new
p [:one_argument, defined?(value.virtual), value.claims]

class RealClaim < ClaimedHash
  def virtual
    :real
  end
end
value = RealClaim.new
p [:real, defined?(value.virtual), value.claims]

value = ClaimedHash.new
def value.virtual
  :real_singleton
end
p [:real_singleton, defined?(value.virtual), value.claims]

p [:ordinary, defined?({}.absent), defined?("".absent), defined?([].absent)]

module DefinedHookGuard957
  attr_accessor :guard_mode, :guard_action

  def guard_events
    @guard_events ||= []
  end

  def respond_to?(name, include_private = false)
    if name == :respond_to_missing?
      guard_events << :gate
      if guard_mode == :gate_gc_raise
        GC.start
        raise "gate-gc957"
      end
      raise "gate957" if guard_mode == :gate_raise
      raise Exception, "gate957" if guard_mode == :gate_exception
      throw :defined_guard_exit957, :gate_exit if guard_mode == :gate_throw
      guard_action.call if guard_mode == :gate_action
    end
    super
  end

  def respond_to_missing?(name, include_private = false)
    guard_events << [:hook, name, include_private]
    if guard_mode == :hook_gc_raise
      GC.start
      raise "hook-gc957"
    end
    raise "hook957" if guard_mode == :hook_raise
    raise Exception, "hook957" if guard_mode == :hook_exception
    throw :defined_guard_exit957, :hook_exit if guard_mode == :hook_throw
    guard_action.call if guard_mode == :hook_action
    false
  end
end

# Keep the before runtime's escaped exception visible without ending the file.
def defined_guard_answer957(value)
  defined?(value.virtual)
rescue Exception => error
  [:leaked, error.class.name, error.message]
end

def defined_guard_return957(value, mode)
  value.guard_mode = mode
  value.guard_action = proc { return :returned957 }
  defined?(value.virtual)
  :continued957
end

def defined_guard_break957(value, mode, &action)
  value.guard_mode = mode
  value.guard_action = action
  defined?(value.virtual)
  :continued957
end

[Hash, String, Array].each do |base|
  klass = Class.new(base) { include DefinedHookGuard957 }
  [:gate_raise, :hook_raise, :gate_exception, :hook_exception, :gate_gc_raise, :hook_gc_raise].each do |mode|
    value = klass.new
    value.guard_mode = mode
    p [:guarded, base.name, mode, defined_guard_answer957(value), value.guard_events, $!.nil?]

    begin
      raise "outer957"
    rescue => outer
      trace = outer.backtrace.dup
      answer = defined_guard_answer957(value)
      p [:outer_state, base.name, mode, answer, $!.equal?(outer), $!.backtrace == trace]
    end

    begin
      raise ArgumentError, "next957"
    rescue => later
      p [:next_exception, base.name, mode, later.message, later.cause.nil?]
    end
  end

  [:gate_throw, :hook_throw].each do |mode|
    value = klass.new
    value.guard_mode = mode
    answer = catch(:defined_guard_exit957) do
      defined?(value.virtual)
      :continued957
    end
    p [:throw, base.name, mode, answer, value.guard_events]
  end

  [:gate_action, :hook_action].each do |mode|
    p [:return, base.name, mode, defined_guard_return957(klass.new, mode)]
    p [:break, base.name, mode, defined_guard_break957(klass.new, mode) { break :broken957 }]
  end
end

[{}, "", []].each do |value|
  value.extend(DefinedHookGuard957)
  [:gate_raise, :hook_raise].each do |mode|
    value.guard_mode = mode
    p [:singleton_guarded, value.class.name, mode, defined_guard_answer957(value), $!.nil?]
  end
end

# Do not read $! before the probe: that would pin the pair and hide lost frames.
def defined_guard_bare_rescue957(value, label)
  begin
    outer_line = __LINE__ + 1
    raise "bare-outer957"
  rescue
    answer = defined?(value.virtual)
    error = $!
    p [:bare_outer, label, answer, error.message,
       error.backtrace.first.include?(":#{outer_line}:in"),
       error.backtrace_locations.first.lineno == outer_line]
  end
rescue Exception => error
  p [:bare_outer, label, :leaked, error.class.name, error.message]
end

[Hash, String, Array].each do |base|
  klass = Class.new(base) { include DefinedHookGuard957 }
  [:gate_raise, :hook_raise, :gate_exception, :hook_exception, :gate_gc_raise, :hook_gc_raise].each do |mode|
    value = klass.new
    value.guard_mode = mode
    defined_guard_bare_rescue957(value, [base.name, mode])
  end
end

[Hash, String, Array].each do |base|
  klass = Class.new(base) { include DefinedHookGuard957 }
  [:gate_action, :hook_action].each do |mode|
    value = klass.new
    nested = klass.new
    nested.guard_mode = :hook_gc_raise
    value.guard_mode = mode
    value.guard_action = proc do
      defined?(nested.virtual)
      GC.start
      raise "nested957"
    end
    defined_guard_bare_rescue957(value, [:nested, base.name, mode])
  end
end

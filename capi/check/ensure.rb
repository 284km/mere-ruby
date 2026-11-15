require '-test-/exception'
$checks = 0

def check(label, value)
  raise label unless value
  $checks += 1
end

def raised(klass)
  begin
    yield
  rescue klass => e
    return e
  end
  raise "expected #{klass}"
end

class EnsureFixture
  def initialize(body, cleanup)
    @body, @cleanup = body, cleanup
  end
  def try_method
    @body.call
  end
  def ensured_method
    @cleanup.call
  end
end

def ensured(body, cleanup)
  Bug::Exception.ensured(EnsureFixture.new(body, cleanup))
end

[Object.new, nil, false, 'return value'].each do |value|
  calls = 0
  result = ensured(-> { value }, -> { calls += 1; :ignored })
  check('body result identity', result.equal?(value))
  check('normal cleanup once', calls == 1)
end

body_error = RuntimeError.new('body')
cleanup_error = ArgumentError.new('cleanup')
seen = nil
caught = raised(RuntimeError) do
  ensured(-> { raise body_error }, -> { seen = $!; GC.start; [1].detect { true } })
end
check('body exception identity', caught.equal?(body_error))
check('pending exception visible in ensure', seen.equal?(body_error))
check('bang restored outside rescue', $!.nil?)

caught = raised(ArgumentError) do
  ensured(-> { raise body_error }, -> { raise cleanup_error })
end
check('cleanup overrides body', caught.equal?(cleanup_error))
check('cleanup cause is body', caught.cause.equal?(body_error))

caught = raised(ArgumentError) { ensured(-> { :ok }, -> { raise cleanup_error }) }
check('cleanup overrides successful body', caught.equal?(cleanup_error))

caught = raised(RuntimeError) do
  ensured(-> { raise body_error }, -> { begin; raise 'handled'; rescue; end; GC.start })
end
check('rescue within cleanup preserves body', caught.equal?(body_error))

order = []
result = ensured(-> {
  ensured(-> { order << :inner_body; :value }, -> { order << :inner_ensure; GC.start })
}, -> { order << :outer_ensure })
check('nested result', result == :value)
check('nested cleanup order', order == [:inner_body, :inner_ensure, :outer_ensure])

calls = 0
tag = Object.new
value = Object.new
result = catch(tag) { ensured(-> { throw tag, value }, -> { calls += 1; GC.start }) }
check('throw value identity', result.equal?(value))
check('throw cleanup once', calls == 1)

caught = raised(ArgumentError) do
  catch(tag) { Bug::Exception.ensure_raise(value, cleanup_error) { |v| check('yield argument identity', v.equal?(value)); throw tag } }
end
check('exception overrides throw', caught.equal?(cleanup_error))
caught = raised(ArgumentError) { Bug::Exception.ensure_raise(value, cleanup_error) { value } }
check('yield success still raises cleanup', caught.equal?(cleanup_error))
caught = raised(ArgumentError) { Bug::Exception.ensure_raise(value, cleanup_error) }
check('missing block still runs cleanup', caught.equal?(cleanup_error))

# The receiver leaves Ruby frames before cleanup allocates and collects.
20.times do |i|
  result = ensured(-> { ['native-result-' + i.to_s, ['payload' * 300]] }, -> { GC.start; GC.start })
  check('C held result survives GC', result == ['native-result-' + i.to_s, ['payload' * 300]])
end

class PrivateEnsureFixture
  private
  def try_method; :private_result; end
  def ensured_method; GC.start; end
end
check('rb_funcall permits private methods', Bug::Exception.ensured(PrivateEnsureFixture.new) == :private_result)

class MissingEnsureFixture
  def method_missing(name, *args)
    name == :try_method ? :missing_result : nil
  end
end
check('rb_funcall dispatches method_missing', Bug::Exception.ensured(MissingEnsureFixture.new) == :missing_result)

caught = raised(NoMethodError) { Bug::Exception.ensured(Object.new) }
check('builtin error from cleanup materialized', caught.name == :ensured_method)

def return_across_native(events)
  body = proc { return :returned }
  ensured(body, -> { events << :cleanup; GC.start })
  :unreachable
end
events = []
check('return crosses native boundary', return_across_native(events) == :returned)
check('return runs cleanup', events == [:cleanup])

caught = raised(ArgumentError) do
  Bug::Exception.ensure_raise(value, cleanup_error) { break :broken }
end
check('cleanup exception overrides block break', caught.equal?(cleanup_error))

# A primitive error has no explicit $exc until the boundary materializes it.
seen = nil
caught = raised(ZeroDivisionError) do
  ensured(-> { 1 / 0 }, -> { seen = $!; GC.start })
end
check('primitive error class', caught.is_a?(ZeroDivisionError))
check('primitive error visible to cleanup', seen.equal?(caught))

# Existing rescue state must be restored after a successful native ensure.
outer = RuntimeError.new('outer rescue')
begin
  raise outer
rescue
  before = $!
  ensured(-> { :ok }, -> { check('outer exception visible', $!.equal?(outer)) })
  check('outer exception restored', $!.equal?(before))
end

nested = RuntimeError.new('nested')
caught = raised(RuntimeError) do
  ensured(-> { raise body_error }, -> {
    inner = raised(RuntimeError) { ensured(-> { raise nested }, -> { GC.start }) }
    check('nested exception identity', inner.equal?(nested))
  })
end
check('outer pending outcome survives nested exception', caught.equal?(body_error))

# Resuming an already-raised exception must not report a second Ruby raise.
traced = RuntimeError.new('traced')
traced.set_backtrace(['native-witness.rb:17'])
events = []
trace = TracePoint.new(:raise) { |event| events << event.raised_exception if event.raised_exception.equal?(traced) }
trace.enable do
  caught = raised(RuntimeError) { ensured(-> { raise traced }, -> { GC.start }) }
  check('traced exception identity', caught.equal?(traced))
end
check('one Ruby raise event', events.length == 1)
check('backtrace preserved', traced.backtrace == ['native-witness.rb:17'])

puts "native ensure contracts: #{$checks} passed"

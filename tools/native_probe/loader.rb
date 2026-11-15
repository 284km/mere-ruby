$checks=0
def check(name, value)
  raise name unless value
  $checks += 1
end
def raised(kind)
  begin
    yield
  rescue kind => e
    return e
  end
  raise "expected #{kind}"
end
check('first require', require('loader_fixture') == true)
check('repeat require', require('loader_fixture') == false)
check('native suffix alias', require('loader_fixture.so') == false)
check('one Init call', LoaderFixture.init_count == 1)
loaded = $LOADED_FEATURES.find { |f| f.end_with?('/loader_fixture.bundle') }
check('loaded feature has native suffix', !loaded.nil?)
check('absolute path identity', require(loaded) == false)
check('symlink identity', require(File.join(ENV.fetch('LOADER_LIB'), 'alias', 'loader_fixture.bundle')) == false)
box = LoaderFixture::Box.new('payload')
GC.start
check('native initialize and getter', box.value == 'payload')
check('instance receiver', box.identity.equal?(box))
check('singleton receiver', LoaderFixture::Box.receiver.equal?(LoaderFixture::Box))
check('operator method registration', box[3,4] == 7)
check('zero argument module function', LoaderFixture.count == 1)
check('two arguments', box.sum(3,4) == 7)
check('native arity', box.method(:sum).arity == 2)
check('zero argument arity', box.method(:value).arity == 0)
raised(ArgumentError) { box.sum(1) }
check('method visibility', LoaderFixture::Box.private_instance_methods.include?(:initialize))
check('module function', LoaderFixture.echo(box).equal?(box))
check('module function private instance copy', LoaderFixture.private_instance_methods.include?(:echo))
check('block forwarding', box.yielding(4) { |n| n + 1 } == 5)
check('block break', box.yielding(4) { break :stopped } == :stopped)
e = raised(RuntimeError) { box.explode }
check('C exception message', e.message == 'native failure')
class LoaderChild < LoaderFixture::Box
  def value
    super + '-child'
  end
  alias copied_identity identity
end
child = LoaderChild.new('value')
check('allocator subclass identity', child.class == LoaderChild)
check('normal super dispatch', child.value == 'value-child')
check('inherited native singleton receiver', LoaderChild.receiver.equal?(LoaderChild))
check('native alias', child.copied_identity.equal?(child))
allocated = LoaderFixture::Box.allocate
check('allocate skips initialize', allocated.value.nil?)
class LoaderFixture::Box
  def self.allocate
    :ruby_override
  end
end
check('Ruby allocate override', LoaderFixture::Box.allocate == :ruby_override)
check('new uses allocator independently', LoaderFixture::Box.new(9).value == 9)
check('nested native require', require('loader_nested') == true)
check('nested definition', defined?(LoaderNested) == 'constant')
check('nested dependency did not reinitialize', LoaderFixture.init_count == 1)
raised(RuntimeError) { require 'loader_retry' }
check('failed Init not loaded', !$LOADED_FEATURES.any? { |f| f.end_with?('/loader_retry.bundle') })
check('partial method remains callable', LoaderRetry.attempts == 1)
check('retry succeeds', require('loader_retry') == true)
check('same resident library state', LoaderRetry.ready == 2)
check('successful retry cached', require('loader_retry') == false)
check('Ruby source wins same-name extension', require('loader_shadow') == true && $loader_shadow == :ruby)
raised(LoadError) { require 'loader_missing_init' }
check('missing Init not loaded', !$LOADED_FEATURES.any? { |f| f.end_with?('/loader_missing_init.bundle') })
check('relative require from Ruby file', require('relative_driver') == true && $relative_native == false)
# Removing a loaded feature permits reinitialization, as in CRuby.
$LOADED_FEATURES.delete(loaded)
check('feature removal permits reload', require('loader_fixture') == true)
check('reload invokes Init', LoaderFixture.init_count == 2)
if ENV['MERE_LOADER_TEST'] == '1'
  class NativeProbe; end
  before = NativeProbe.__loader_stat(0)
  raised(LoadError) { require 'loader_wrongabi' }
  raised(LoadError) { require 'loader_wrongabi' }
  check('ABI mismatch not cached as loaded', !$LOADED_FEATURES.any? { |f| f.end_with?('/loader_wrongabi.bundle') })
  check('failed opens do not retain handles', NativeProbe.__loader_stat(0) == before)
  check('C call resources released', NativeProbe.__native_resources == 0)
  check('temporary roots released', NativeProbe.__typed_stat(11) == 0)
end
puts "native loader contracts: #{$checks} passed"

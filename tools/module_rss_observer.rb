# Read the original child result in the parent without changing its input or timeout.
require 'envutil'

module ModuleRssParentObserver
  def invoke_ruby(*args, **options, &block)
    selected = args[1].is_a?(String) && args[1].include?('300_000.times(&code)')
    if selected
      File.write(ENV.fetch('MODULE_RSS_CAPTURE_INPUT'), args[1])
    end
    result = super(*args, **options, &block)
    if selected
      STDERR.puts "\nMODULE_RSS_OBSERVER_BEGIN"
      STDERR.write result[1] if result[1]
      STDERR.puts 'MODULE_RSS_OBSERVER_END'
    end
    result
  end
end
EnvUtil.singleton_class.prepend(ModuleRssParentObserver)

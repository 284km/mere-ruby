# Observe the original child in its parent, without replacing any argument,
# stdin byte, return value, or upstream timeout.
module RSSProbeObserver
  def invoke_ruby(args, stdin = "", *rest, **options, &block)
    selected = stdin.include?("Module.new.clone") && stdin.include?("1_000_000.times(&code)")
    File.binwrite(ENV.fetch("RSS_PROBE_INPUT"), stdin) if selected
    result = super
    if selected
      STDERR.write("\nRSS_PROBE_CHILD_BEGIN\n", result[1], "RSS_PROBE_CHILD_END\n")
    end
    result
  end
end
EnvUtil.singleton_class.prepend(RSSProbeObserver)

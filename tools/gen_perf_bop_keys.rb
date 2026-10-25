# Generates perf_bop_keys in main.mere: every Class#method whose redefinition
# makes the reference ruby print "Redefining 'C#m' disables interpreter and
# JIT optimizations" under Warning[:performance]. It is vm.c's
# vm_opt_method_def_table asked through its effect: the table is keyed by
# method DEFINITION, so a method sharing a definition with a basic operation
# (Proc#[] with Proc#call, Array#- ...) warns too, which reading the OP()
# list in vm.c cannot tell.
#
#   ~/.rbenv/versions/4.0.9/bin/ruby tools/gen_perf_bop_keys.rb
#
# Each candidate is redefined in a forked child, as a wrapper that keeps the
# original's behaviour, and the child's stderr is read for the warning.
hits = []
klasses = [Integer, Float, String, Array, Hash, Symbol, Regexp, NilClass, TrueClass, FalseClass, Proc, Time]
klasses.each do |k|
  ms = k.instance_methods(false) + k.private_instance_methods(false)
  ms.sort.each do |m|
    r, w = IO.pipe
    pid = fork do
      r.close
      $stderr.reopen(w)
      Warning[:performance] = true
      orig = k.instance_method(m)
      begin
        k.send(:define_method, m) { |*a, **kw, &b| orig.bind_call(self, *a, **kw, &b) }
      rescue Exception
      end
      exit!(0)
    end
    w.close
    out = r.read
    Process.wait(pid)
    hits << "#{k}##{m}" if out.include?("Redefining")
  end
end
puts hits.join(" ")

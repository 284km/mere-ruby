require 'stringio'

captured = StringIO.new
original_stderr = $stderr
original_verbose = $VERBOSE
$stderr = captured
$VERBOSE = true

eval(<<~'RUBY', TOPLEVEL_BINDING, 'copied_methods.rb', 1)
  class AliasWarnings
    def source; :original end
    alias_method :target, :source
    def target; :first end
    def target; :second end
    def source; :first end
    def source; :second end
  end
  class DefineMethodWarnings
    def source; :original end
    define_method(:target, instance_method(:source))
    def target; :first end
    def target; :second end
    def source; :first end
    def source; :second end
  end
  class KeywordAliasWarnings
    def source; :original end
    alias target source
    def target; :first end
    def target; :second end
    def source; :first end
    def source; :second end
  end
RUBY

$VERBOSE = original_verbose
$stderr = original_stderr
puts captured.string

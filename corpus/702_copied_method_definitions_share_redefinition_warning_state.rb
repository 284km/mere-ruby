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
  class CloneWarningSource
    def value; :before end
  end
  CloneWarningCopy = CloneWarningSource.clone
  class CloneWarningSource
    def value; :after end
  end
  class CloneWarningCopy
    def value; :after end
  end
  clone_object = Object.new
  def clone_object.value; :before end
  cloned_object = clone_object.clone
  def clone_object.value; :after end
  def cloned_object.value; :after end
  module ImportWarningSource
    def imported; :before end
  end
  module ImportWarningRefinement
    refine Object do
      import_methods ImportWarningSource
      def imported; :after end
    end
  end
  module ImportWarningSource
    def imported; :after end
  end
  class ReflectiveAliasWarnings
    def source; :before end
    method(:alias_method).call(:target, :source)
    def target; :after end
    def source; :after end
    def target; :again end
  end
  class ReflectiveCopyWarnings
    def source; :before end
    installer = Module.instance_method(:define_method).bind(self)
    installer.call(:target, instance_method(:source))
    def target; :after end
    def source; :after end
    def target; :again end
  end
RUBY

$VERBOSE = original_verbose
$stderr = original_stderr
puts captured.string

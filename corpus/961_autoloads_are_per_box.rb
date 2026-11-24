# An autoload is a constant not yet loaded, and each box has its own. The
# main box loading Pathname's core used to take the autoload away from every
# box, so in the root box -- whose constants are the boot's -- `require
# "pathname"`, whose file names Pathname to load the core, raised NameError
# (test_box's test_calling_root_box_methods_does_not_change_user_boxes_newly_created).
# The reads run in a child started with RUBY_BOX=1, as corpus 647 and 853 do.
# (The child's stderr names the program: not compared.)
child = <<~'CHILD'
  require 'pathname'
  Pathname.new('.').find { break }
  p Object.constants.include?(:Find)
  p Ruby::Box.root.eval("require 'pathname'; Pathname.new('one/two').basename.to_s")
  p Ruby::Box.root.eval("Pathname.new('.').find { break }; Object.constants.include?(:Find)")
  b1 = Ruby::Box.new
  p b1.eval("Object.constants.include?(:Find)")
  p b1.eval("Pathname('a/b').dirname.to_s")

  # a program's own autoloads: one registered in main is not a new box's,
  # one a box registers and loads is not main's, and each is still there
  # (or gone) in its own box after the other box ran
  require 'tmpdir'
  dir = Dir.mktmpdir
  fa = File.join(dir, 'box_auto_a_961.rb')
  fb = File.join(dir, 'box_auto_b_961.rb')
  File.write(fa, "module BoxAutoA961; LOADED_IN = :main; end\n")
  File.write(fb, "module BoxAutoB961; LOADED_IN = :box; end\n")
  autoload :BoxAutoA961, fa
  p Object.autoload?(:BoxAutoA961) == fa
  b2 = Ruby::Box.new
  p b2.eval("[Object.autoload?(:BoxAutoA961), Object.const_defined?(:BoxAutoA961)]")
  p b2.eval("autoload :BoxAutoB961, #{fb.dump}; [Object.autoload?(:BoxAutoB961) ? :pending : :none, BoxAutoB961::LOADED_IN, Object.autoload?(:BoxAutoB961)]")
  p [Object.autoload?(:BoxAutoB961), Object.const_defined?(:BoxAutoB961)]
  p Object.autoload?(:BoxAutoA961) == fa
  p [BoxAutoA961::LOADED_IN, Object.autoload?(:BoxAutoA961)]
  p b2.eval("[Object.autoload?(:BoxAutoA961), Object.const_defined?(:BoxAutoA961), Object.autoload?(:BoxAutoB961), BoxAutoB961::LOADED_IN]")
CHILD
IO.popen({"RUBY_BOX" => "1"}, [RbConfig.ruby, "-e", child], err: File::NULL) { |io| print io.read }

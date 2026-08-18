# An autoload registered on an enclosing module is found from anywhere inside
# that nesting -- as a bare constant, and as the head of a scoped path. Only
# the innermost scope (M::B::A) and the bare top-level name used to be tried,
# so a library reading its own autoloaded sibling from inside one of its own
# classes raised NameError. Bundler::Dsl reaches Bundler::SourceList this way.
File.write("/tmp/mrb_al_thing.rb",
           "module Outer\n  class Thing\n    def hi; 'hi from Thing'; end\n  end\nend\n")
File.write("/tmp/mrb_al_source.rb",
           "module Outer\n  module Source\n" \
           "    autoload :Rubygems, '/tmp/mrb_al_source_rubygems'\n  end\nend\n")
File.write("/tmp/mrb_al_source_rubygems.rb",
           "module Outer\n  module Source\n    class Rubygems\n" \
           "      def name; 'rubygems source'; end\n    end\n  end\nend\n")
File.write("/tmp/mrb_al_holder.rb",
           "module Outer\n  class Holder\n    def make; Thing.new.hi; end\n" \
           "    def deep; Source::Rubygems.new.name; end\n  end\nend\n")

module Outer
  autoload :Thing,  "/tmp/mrb_al_thing"
  autoload :Source, "/tmp/mrb_al_source"
  autoload :Holder, "/tmp/mrb_al_holder"

  # written in the same file as the autoload declarations ...
  class Sibling
    def make; Thing.new.hi; end
    def deep; Source::Rubygems.new.name; end
    def missing; NoSuchThingAnywhere; end
  end
end

p Outer::Sibling.new.make
p Outer::Sibling.new.deep
# ... and from a class that is itself autoloaded out of another file
p Outer::Holder.new.make
p Outer::Holder.new.deep
# a name that is registered nowhere is still a NameError (the message names the
# lexical scope in ruby and only the constant here, so compare the class)
begin
  Outer::Sibling.new.missing
rescue NameError => e
  p e.class
end
# a fired autoload is consumed: the registration is gone and the constant stays
p Outer.autoload?(:Thing)
p Outer::Thing.new.hi

# File.readable? / writable? / executable?, and a path that is not there is
# none of the three.
File.write("/tmp/mrb_al_plain.txt", "x")
p [File.readable?("/tmp/mrb_al_plain.txt"),
   File.writable?("/tmp/mrb_al_plain.txt"),
   File.executable?("/tmp/mrb_al_plain.txt")]
p [File.readable?("/tmp/mrb_al_nope"),
   File.writable?("/tmp/mrb_al_nope"),
   File.executable?("/tmp/mrb_al_nope")]
p [File.readable?("/bin/sh"), File.executable?("/bin/sh")]
p File.writable?("/tmp")

%w[mrb_al_thing.rb mrb_al_source.rb mrb_al_source_rubygems.rb mrb_al_holder.rb
   mrb_al_plain.txt].each { |f| File.delete("/tmp/#{f}") }

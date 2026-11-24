# `class Thru < Assoc`: the superclass's name is a constant read. An
# autoload registered in a scope nearer than the one that already holds the
# name is what the name means there, and it is loaded first. The class
# statement took the nearest scope that already HELD the name, so with
# Outer::Assoc loaded and Outer::Pre's own Assoc still an autoload, Thru
# became a subclass of Outer::Assoc. activerecord's
# Preloader::ThroughAssociation < Association is that shape: it inherited
# Associations::Association#initialize, "given 6, expected 2".
require 'tmpdir'
dir = Dir.mktmpdir
File.write(File.join(dir, "inner_assoc_965.rb"), "module Outer965; class Pre; class Assoc; def self.who = :inner; end; end; end\n")
File.write(File.join(dir, "inner_thru_965.rb"), "module Outer965\n  class Pre\n    class Thru < Assoc\n    end\n  end\nend\n")
File.write(File.join(dir, "inner_mod_965.rb"), "module Outer965; class Pre; module Mix; def mixed = :inner; end; end; end\n")
$LOAD_PATH.unshift dir
module Outer965
  class Assoc; def self.who = :outer; end
  module Mix; def mixed = :outer; end
  class Pre
    autoload :Assoc, "inner_assoc_965"
    autoload :Thru, "inner_thru_965"
    autoload :Mix, "inner_mod_965"
    class Branch
      def pick = Thru
    end
  end
end
# the superclass named in a file that an autoload loads (the walker's path)
t = Outer965::Pre::Branch.new.pick
p t.superclass, t.who, Outer965::Pre.autoload?(:Assoc)

# ...and named in a class body, a nested body, and through eval
module Outer965
  class Pre2
    autoload :Assoc, "inner_assoc2_965"
  end
end
File.write(File.join(dir, "inner_assoc2_965.rb"), "module Outer965; class Pre2; class Assoc; def self.who = :inner2; end; end; end\n")
module Outer965
  class Pre2
    class Local < Assoc; end
    class Deep; class Deeper < Assoc; end; end
  end
end
p Outer965::Pre2::Local.superclass, Outer965::Pre2::Deep::Deeper.superclass.who
module Outer965
  class Pre3
    autoload :Assoc, "inner_assoc3_965"
    def self.make = eval("class Evald < Assoc; end; Evald")
  end
end
File.write(File.join(dir, "inner_assoc3_965.rb"), "module Outer965; class Pre3; class Assoc; def self.who = :inner3; end; end; end\n")
p Outer965::Pre3.make.superclass.who

# the outer one is still the answer where no nearer autoload is
module Outer965
  class Plain
    class Sub < Assoc; end
  end
end
p Outer965::Plain::Sub.superclass
# include names its module the same way a read does
module Outer965
  class Pre
    class Mixer; include Mix; end
  end
end
p Outer965::Pre::Mixer.new.mixed

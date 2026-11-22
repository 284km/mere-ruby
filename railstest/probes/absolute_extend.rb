module AbsoluteExtendFactory
  module Feature
    def installed_feature
      :routes_installed
    end
  end
  def self.with(routes)
    raise "wrong factory input" unless routes == :routes
    Feature
  end
end
module LexicalNamespace
  AbsoluteExtendFactory = Module.new
  class Controller
    extend ::AbsoluteExtendFactory.with(:routes)
  end
end
p LexicalNamespace::Controller.installed_feature

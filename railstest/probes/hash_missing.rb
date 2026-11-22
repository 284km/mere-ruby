class Options < Hash
  def method_missing(name, *args)
    p [:hook, name, args]
    :handled
  end
  def respond_to_missing?(name, include_private = false)
    true
  end
end
options = Options.new
p options.class
p options.railties_load_path = []
p options.unrecognized

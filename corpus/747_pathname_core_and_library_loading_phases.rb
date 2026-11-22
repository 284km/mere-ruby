path = Pathname('one/two')
p [:core, path.to_s, path.respond_to?(:find)]
p [:identity, Kernel.Pathname(path).equal?(path)]
p [:library, require('pathname'), path.respond_to?(:find)]
p [:repeat, require('pathname')]
p [:constructor, Pathname.new('three/four').basename.to_s]
begin
  Pathname.new
rescue ArgumentError => error
  p [:arity, error.class]
end
begin
  Pathname.new("bad\0path")
rescue ArgumentError => error
  p [:nul, error.class]
end

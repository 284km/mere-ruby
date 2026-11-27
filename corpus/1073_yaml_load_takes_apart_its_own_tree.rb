# safe_load and unsafe_load take apart the node tree they built, once its
# Ruby value is made: a handle the parse left on the C stack kept the whole
# tree alive otherwise. Nothing they answer is a node, so nothing changes --
# and a tree Psych.parse or parse_stream answers is the caller's, whole.
require "yaml"
require "tempfile"

text = <<~Y
  base: &b
    name: 基本
    list: [1, 2, {k: v}]
  copy: *b
  str: !!str 12
  seq:
    - a
    - [b, c]
Y

p YAML.load(text, aliases: true)
p YAML.unsafe_load(text)
p YAML.safe_load(text, aliases: true)
p YAML.safe_load("a: :sym\n", permitted_classes: [Symbol])
p YAML.load("--- []\n"), YAML.load(""), YAML.unsafe_load("", fallback: :none)
p YAML.load_stream("--- 1\n--- [2]\n"), YAML.load_stream("--- a\n--- b\n").size

# an object revived through init_with, from a tagged mapping
class Pt
  attr_reader :x, :y
  def init_with(coder) = (@x, @y = coder["x"], coder["y"])
end
pt = YAML.unsafe_load("--- !ruby/object:Pt\nx: 1\ny: [2, 3]\n")
p [pt.class, pt.x, pt.y]

# the files' loads go the same way
Tempfile.create(["t1073", ".yml"]) do |f|
  f.write(text)
  f.flush
  p YAML.load_file(f.path, aliases: true)["copy"], YAML.unsafe_load_file(f.path)["seq"], YAML.safe_load_file(f.path, aliases: true)["str"]
end

# Psych.parse's tree is the caller's: whole, and usable after a load
tree = Psych.parse(text)
YAML.load(text, aliases: true)
p tree.class, tree.children.size, tree.root.children.size
p tree.to_ruby
p tree.root.children.map { |n| n.class.name.split("::").last }.first(4)
stream = Psych.parse_stream("--- 1\n--- [2, 3]\n")
YAML.unsafe_load("--- x\n")
p stream.children.size, stream.children.map(&:to_ruby)
p stream.children[1].root.children.size

# what a load answered stays whole when the next load runs
a = YAML.load("k: [1, [2, 3], {x: y}]\n")
b = YAML.load("k: [4]\n")
p a, b

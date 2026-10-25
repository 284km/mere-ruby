# Dir.tmpdir without TMPDIR's trailing slash, an indented frozen_string_literal
# comment and one that says false, Process.argv0 after $0 changed, and a
# backtick that does not hand the program's pipe to its command

require "tmpdir"
require "tempfile"
p Dir.tmpdir.end_with?("/"), Dir.tmpdir == File.expand_path(Dir.tmpdir)
Tempfile.create(["c395", ".rb"]) { |t| p t.path.include?("//") }

src = "    # frozen_string_literal: true\n    \"x\".frozen?\n"
p eval(src)
p eval("# -*- frozen-string-literal: false -*-\n\"y\".frozen?")

$0 = "renamed"
p Process.argv0 == __FILE__, Process.argv0.frozen?, $0

r, w = IO.pipe
out = `sh -c 'echo 1 >&#{w.fileno}' 2>&1`
w.close
p r.read, out.empty?
p $?.success?

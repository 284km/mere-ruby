# A regexp literal that does not compile is a SyntaxError of the file it is
# in, or of the eval, and its message is ruby's.
#
# There are two kinds. A literal Prism's own regexp parser refuses -- a
# parenthesis that is not closed, a repeat of nothing, an escape cut short --
# is one of Prism's syntax errors: "<path>:<line>: syntax error found" and
# the frame, with every other such error of the source, the lines around
# them, `^~~` under the characters. A literal only the regexp engine refuses
# -- a class that does not end, a property nobody knows, a name nobody
# defined -- is found when the literal is compiled: "<path>:<line>: " and the
# reason, of the first such literal alone, with no frame.
require "tmpdir"
dir = Dir.mktmpdir("c817")
short = ->(s) { s.to_s.gsub(File.realpath(dir), "D").gsub(dir, "D") }
lines = ->(n) { (1..n).map { |i| "v#{i} = #{i}\n" } }
with = ->(n, h) { a = lines.(n); h.each { |i, s| a[i - 1] = s }; a.join }

files = {
  # Prism's: where the frame's lines begin and end
  "mid" => with.(12, 6 => "v6 = /(un/\n"),
  "first" => with.(12, 1 => "v1 = /(un/\n"),
  "second" => with.(3, 2 => "X = /(unclosed/\n"),
  "last" => with.(12, 12 => "v12 = /(un/\n"),
  "last_no_newline" => with.(12, 12 => "v12 = /(un/"),
  "no_newline_after" => "1\n/(x/\n3\n4",
  "no_newline_one_after" => "1\n/(x/\n3",
  "no_newline_three_after" => "1\n/(x/\n3\n4\n5",
  "wide_numbers" => with.(120, 105 => "v105 = /(un/\n"),
  # ...two errors, and what is shown between them
  "adjacent" => with.(12, 3 => "v3 = /(a/\n", 4 => "v4 = /(b/\n"),
  "one_between" => with.(12, 3 => "v3 = /(a/\n", 5 => "v5 = /(b/\n"),
  "four_between" => with.(12, 3 => "v3 = /(a/\n", 8 => "v8 = /(b/\n"),
  "five_between" => with.(14, 3 => "v3 = /(a/\n", 9 => "v9 = /(b/\n"),
  "six_between_and_wider" => with.(14, 3 => "v3 = /(a/\n", 10 => "v10 = /(b/\n"),
  "same_line" => with.(12, 3 => "v3 = [/(a/, /(bc/]\n"),
  # ...the mark
  "tabs" => with.(5, 3 => "\t\tv3 = /(ab/\n"),
  "multibyte_before" => with.(5, 3 => "v3 = 'あい'; w = /(a/\n"),
  "column_zero" => with.(5, 3 => "/(a/\n"),
  "nested_group" => with.(5, 3 => "v3 = /((a)/\n"),
  "named_group" => with.(5, 3 => "v3 = /(?<n>a/\n"),
  "over_two_lines" => with.(5, 3 => "v3 = /(a\n", 4 => "b/\n"),
  "percent_r" => with.(5, 3 => "v3 = %r{(a}\n"),
  "long_line" => with.(5, 3 => "v3 = " + "x + " * 20 + "/(abc/ + " + "y + " * 20 + "1\n"),
  # ...its other refusals
  "repeat_of_nothing" => with.(5, 3 => "v3 = /*a/\n"),
  "group_option" => with.(5, 3 => "v3 = /(?z)/\n"),
  "comment_not_closed" => with.(5, 3 => "v3 = /a(?#/\n"),
  "hex_escape" => with.(5, 3 => "v3 = /\\x/\n"),
  "empty_class" => with.(5, 3 => "v3 = /[]/\n"),
  # the engine's: the reason on one line, the first alone
  "close_unmatched" => with.(5, 3 => "v3 = /a)/\n"),
  "class_not_closed" => with.(5, 3 => "v3 = /[a-/\n"),
  "property" => with.(5, 3 => "v3 = /\\p{Foo}/\n"),
  "name_undefined" => with.(5, 3 => "v3 = /(?<n>a)\\k<m>/\n"),
  "group_name" => with.(5, 3 => "v3 = /(?<1>a)/\n"),
  "repeat_range" => with.(5, 3 => "v3 = /a{2,1}/\n"),
  "two_of_the_engines" => with.(5, 3 => "v3 = /[a-/\n", 4 => "v4 = /a)/\n"),
  # one of each: Prism's is said, the engine's is not reached
  "prism_then_engine" => with.(5, 3 => "v3 = /a(b/ix\n", 4 => "v4 = /[a-/\n"),
  # not errors
  "fine" => with.(5, 3 => "v3 = /(a)[b-c]\\p{Alpha}/\n"),
}

files.each do |name, src|
  path = File.join(dir, "c817_#{name}.rb")
  File.write(path, src)
  puts "== #{name}"
  begin
    p require(path)
  rescue SyntaxError => e
    puts short.(e.message)
    p [e.path == path, e.message.end_with?("\n"), $LOADED_FEATURES.include?(path)]
  end
  # the same source in an eval, at another file's line 10
  begin
    eval(src, TOPLEVEL_BINDING, "evald.rb", 10)
    puts "eval: fine"
  rescue SyntaxError => e
    puts e.message
  end
end

# an eval's own forms
["/(/", "x = 1\ny = /a)/\nz = 2", "a = /(?<n>.)\\k<n>/; b = /*/"].each do |src|
  begin
    eval(src)
    puts "fine"
  rescue SyntaxError => e
    puts e.message.sub(/\(eval at .*?:\d+\)/, "(eval)")
  end
end
# a literal's warning names the line it is on, in an eval that starts at
# another line too
err = $stderr
rd, wr = IO.pipe
$stderr = wr
begin
  eval("x = 1\n\ny = /[a-a-z]/\n", TOPLEVEL_BINDING, "warned.rb", 20)
  path = File.join(dir, "c817_warned.rb")
  File.write(path, "v1 = 1\nv2 = /[a-a-z]/\n")
  require path
ensure
  $stderr = err
  wr.close
end
puts rd.read.lines.map { short.(_1) }
# ...and it is said once: a main script's, and a file's it requires (the VM's
# compiler makes a Regexp of the literal too, and said it again)
File.write(File.join(dir, "c817_main.rb"), "x = 1\ny = /[b-b-c]/\nrequire_relative 'c817_warned'\np :ran\n")
puts IO.popen([RbConfig.ruby, File.join(dir, "c817_main.rb")], err: [:child, :out], &:read).lines.map { short.(_1) }
# a literal built at run time is the engine's to refuse, as a RegexpError
begin
  v = "("
  /#{v}a/
rescue RegexpError => e
  puts e.class, e.message
end

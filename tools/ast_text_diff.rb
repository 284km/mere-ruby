# Compare two directories of trees in text form (tools/ast_on_cruby.rb text
# --out, tools/ast_dump --out): how many files agree, and for those that do
# not, where each first differs -- grouped by the node the reference has
# there, so the commonest disagreement is the first line of the answer.
#
#   ruby tools/ast_text_diff.rb ORACLE_DIR CANDIDATE_DIR [-n EXAMPLES] [-v]
#
# -n is how many examples to print for each group (default 1); -v prints
# every differing file's first difference.
oracle, cand = ARGV.shift(2)
abort "usage: ast_text_diff.rb ORACLE_DIR CANDIDATE_DIR [-n EXAMPLES] [-v]" unless oracle && cand
examples = (i = ARGV.index("-n")) ? ARGV[i + 1].to_i : 1
verbose = ARGV.include?("-v")
same = 0
total = 0
lines_same = 0
lines_total = 0
groups = Hash.new { |h, k| h[k] = [] }
Dir.children(oracle).sort.each do |name|
  total += 1
  a = File.readlines(File.join(oracle, name))
  b = File.exist?(File.join(cand, name)) ? File.readlines(File.join(cand, name)) : []
  lines_total += a.size
  if a == b
    same += 1
    lines_same += a.size
    next
  end
  i = (0...[a.size, b.size].min).find { |k| a[k] != b[k] } || [a.size, b.size].min
  lines_same += i
  want = a[i]&.strip || "(end)"
  got = b[i]&.strip || "(end)"
  # (the group: the reference's node type, and the candidate's when it is another)
  wt = want[/\A[A-Z_0-9]+/] || want
  gt = got[/\A[A-Z_0-9]+/] || got
  key = wt == gt ? wt : "#{wt} / #{gt}"
  # the nodes above the difference, innermost last
  path = []
  depth = a[i] ? a[i][/\A */].size : 0
  (i - 1).downto(0) do |k|
    d = a[k][/\A */].size
    if d < depth
      path.unshift(a[k].strip[/\A\S+ \S+/])
      depth = d
    end
  end
  groups[key] << [name, i + 1, want, got, path.last(3).join(" > ")]
end
printf("%d files: %d agree, %d differ; %d of %d lines before a first difference\n", total, same, total - same, lines_same, lines_total)
groups.sort_by { |_, v| -v.size }.each do |key, list|
  puts "#{list.size}\t#{key}"
  list.first(verbose ? list.size : examples).each do |name, line, want, got, path|
    puts "\t#{name}:#{line}  in #{path}"
    puts "\t  want #{want[0, 200]}"
    puts "\t  got  #{got[0, 200]}"
  end
end

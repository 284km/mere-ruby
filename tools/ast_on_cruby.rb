# The parse.y AST as the oracle, on the REFERENCE ruby -- for building
# RubyVM::AbstractSyntaxTree out of Prism's tree without a mere-ruby build
# in the loop.
#
# ruby 4.0.9 has both halves: Prism (the tree mere-ruby has) and parse.y's
# RubyVM::AbstractSyntaxTree (the tree test/ruby/test_ast.rb asks for). A
# translator from the first to the second can be written in Ruby, checked
# here against the real thing over every file test_ast reads, and only then
# moved into mere-ruby. One file here is milliseconds; the same comparison
# through mere-ruby is the length of a CI shard.
#
#   ruby tools/ast_on_cruby.rb dump FILE...
#       the oracle's canonical form of each file (what `check` compares)
#   ruby tools/ast_on_cruby.rb check CANDIDATE.rb --ruby-src DIR [--locations] [--node-id] [PATH...]
#       CANDIDATE.rb defines AstCandidate.parse(source) and returns its root
#       node; PATHs default to DIR/test/**/*.rb, the set test_ast's
#       test_ranges / test_not_cared / test_all_tokens read. Prints one line
#       per file that differs (with the first differing place), then totals.
#   ruby tools/ast_on_cruby.rb check self --ruby-src DIR
#       the oracle against itself: every file must match, or this harness
#       is wrong
#
# A candidate's node answers what RubyVM::AbstractSyntaxTree::Node answers:
# #type, #children, #first_lineno, #first_column, #last_lineno,
# #last_column, and #locations (objects with the same four readers) when
# --locations is given. #node_id is compared only with --node-id: parse.y
# numbers its nodes its own way, and test_ast asks for an id's relations,
# not its value.
#
# Run it with the reference (tools/ref_ruby.sh): another ruby's parse.y is a
# different oracle.

module AstOracle
  module_function

  # A node as nested arrays: [type, [fl, fc, ll, lc], locations, node_id,
  # children]. A child that is no node is kept as its #inspect, so a Symbol
  # table, a literal and nil compare by value and print readably.
  def canon(node, locations: false, node_id: false)
    return node.inspect unless node.respond_to?(:type) && node.respond_to?(:children)
    [
      node.type,
      [node.first_lineno, node.first_column, node.last_lineno, node.last_column],
      locations ? Array(node.locations).map { |l| l && [l.first_lineno, l.first_column, l.last_lineno, l.last_column] } : nil,
      node_id ? node.node_id : nil,
      node.children.map { |c| c.is_a?(Array) ? c.map { |e| canon(e, locations:, node_id:) } : canon(c, locations:, node_id:) },
    ]
  end

  # The first place two canonical forms differ, as a path of child indexes.
  def first_diff(a, b, path = [])
    return nil if a == b
    if a.is_a?(Array) && b.is_a?(Array) && a.size == b.size
      a.each_index do |i|
        d = first_diff(a[i], b[i], path + [i])
        return d if d
      end
    end
    [path, short(a), short(b)]
  end

  # The same path, read as the nodes it passes: "SCOPE > BLOCK > IF.pos".
  def describe(tree, path)
    names = []
    cur = tree
    i = 0
    while i < path.size
      node = cur.is_a?(Array) && cur.size == 5 && cur[0].is_a?(Symbol)
      if node
        names << cur[0].to_s
        field = path[i]
        if field == 4 && i + 1 < path.size
          cur = cur[4][path[i + 1]]
          i += 2
          # (a child that is a list: the element's index)
          if cur.is_a?(Array) && !(cur.size == 5 && cur[0].is_a?(Symbol)) && i < path.size
            names[-1] += "[#{path[i - 1]}][#{path[i]}]"
            cur = cur[path[i]]
            i += 1
          end
          next
        end
        names[-1] += "." + %w[type pos locations node_id children][field].to_s
        break
      end
      cur = cur[path[i]] if cur.is_a?(Array)
      i += 1
    end
    names.join(" > ")
  end

  def short(v)
    s = v.inspect
    s.size > 160 ? s[0, 160] + "..." : s
  end

  def oracle(source)
    RubyVM::AbstractSyntaxTree.parse(source)
  end
end

if $0 == __FILE__
  mode = ARGV.shift
  case mode
  when "dump"
    ARGV.each do |f|
      p AstOracle.canon(AstOracle.oracle(File.read(f)), locations: true, node_id: true)
    end
  when "check"
    cand = ARGV.shift or abort "usage: ast_on_cruby.rb check CANDIDATE.rb --ruby-src DIR [--locations] [--node-id] [PATH...]"
    src = nil
    opts = { locations: false, node_id: false }
    paths = []
    while (a = ARGV.shift)
      case a
      when "--ruby-src" then src = ARGV.shift
      when "--locations" then opts[:locations] = true
      when "--node-id" then opts[:node_id] = true
      else paths << a
      end
    end
    if paths.empty?
      abort "check: give PATHs or --ruby-src DIR (its test/**/*.rb is test_ast's set)" unless src
      paths = Dir.glob("test/**/*.rb", base: src).sort.map { |p| File.join(src, p) }
    end
    if cand == "self"
      parse = ->(s) { AstOracle.oracle(s) }
    else
      load File.expand_path(cand)
      parse = ->(s) { AstCandidate.parse(s) }
    end
    match = differ = refused = 0
    t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    paths.each do |f|
      s = File.read(f)
      want = begin
        AstOracle.canon(AstOracle.oracle(s), **opts)
      rescue SyntaxError
        # (a file parse.y refuses is not a question test_ast asks either)
        next
      end
      got = begin
        AstOracle.canon(parse.(s), **opts)
      rescue NotImplementedError, StandardError, ScriptError => e
        refused += 1
        puts "REFUSED #{f}: #{e.class}: #{e.message[0, 160]}"
        next
      end
      if want == got
        match += 1
      else
        differ += 1
        path, w, g = AstOracle.first_diff(want, got)
        puts "DIFF #{f} at #{AstOracle.describe(want, path)}\n  want #{w}\n  got  #{g}"
      end
    end
    printf("%d files: MATCH %d, DIFF %d, REFUSED %d (%.1fs)\n", match + differ + refused, match, differ, refused,
           Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0)
    exit(differ + refused == 0 ? 0 : 1)
  else
    abort "usage: ruby tools/ast_on_cruby.rb dump FILE... | check CANDIDATE.rb|self --ruby-src DIR [--locations] [--node-id] [PATH...]"
  end
end

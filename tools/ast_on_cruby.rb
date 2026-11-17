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
#   ruby tools/ast_on_cruby.rb text [--locations] [--tolerant] [--out DIR] [-e CODE | FILE...]
#       the oracle's tree as text, one node a line (AstOracle.text below):
#       what a candidate that is not Ruby is compared with -- the translator
#       in Mere prints the same form (tools/ast_dump.mere)
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

  # The same tree as text, one node a line, for a candidate that is not Ruby
  # (tools/ast_dump.mere prints this form from the Mere translator, and
  # tools/ast_text_diff.rb compares the two):
  #
  #   <indent>TYPE fl:fc-ll:lc child child ...
  #
  # A child that is a node is `*` and its own lines follow, one level in, in
  # the order of the `*`s; an Array is `[child,child]`. Everything else is
  # written by its bytes, so that nothing depends on how a value inspects:
  #
  #   nil true false     themselves
  #   :name              a Symbol (`:x<hex>` unless every byte is printable)
  #   I-ff               an Integer, in hex
  #   F<16 hex>          a Float's bits
  #   R<I>/<I>           a Rational          C<value>   an imaginary's part
  #   S(enc)<hex>        a String            X(enc,options)<hex>   a Regexp
  #   E(name)            an Encoding
  #
  # With locations: true the line ends with ` @` and each of #locations
  # after the first as fl:fc-ll:lc (or nil), `;` between.
  def text(node, out, depth = 0, locations: false)
    kids = []
    line = +"#{" " * depth}#{node.type} #{node.first_lineno}:#{node.first_column}-#{node.last_lineno}:#{node.last_column}"
    node.children.each { |c| line << " " << text_child(c, kids) }
    if locations
      locs = node.locations.drop(1)
      line << " @" << locs.map { |l| l ? "#{l.first_lineno}:#{l.first_column}-#{l.last_lineno}:#{l.last_column}" : "nil" }.join(";") unless locs.empty?
    end
    out << line << "\n"
    kids.each { |k| text(k, out, depth + 1, locations: locations) }
    out
  end

  def text_child(c, kids)
    case c
    when RubyVM::AbstractSyntaxTree::Node then kids << c; "*"
    when Array then "[" + c.map { |e| text_child(e, kids) }.join(",") + "]"
    when nil then "nil"
    when true then "true"
    when false then "false"
    when Symbol then text_sym(c)
    when Integer then text_int(c)
    when Float then "F" + [c].pack("G").unpack1("H*")
    when Rational then "R" + text_int(c.numerator) + "/" + text_int(c.denominator)
    when Complex then "C" + text_child(c.imaginary, kids)
    when String then "S(#{c.encoding.name})" + c.b.unpack1("H*")
    when Regexp then "X(#{c.encoding.name},#{c.options})" + c.source.b.unpack1("H*")
    when Encoding then "E(#{c.name})"
    else raise "ast_on_cruby: a child of class #{c.class}"
    end
  end

  def text_sym(sym)
    b = sym.name.b
    b.match?(/\A[!-~]+\z/) && !b.match?(/[\[\],*]/) ? ":" + b : ":x" + b.unpack1("H*")
  end

  def text_int(i)
    "I" + (i < 0 ? "-" : "") + i.abs.to_s(16)
  end
end

if $0 == __FILE__
  mode = ARGV.shift
  case mode
  when "dump"
    ARGV.each do |f|
      p AstOracle.canon(AstOracle.oracle(File.read(f)), locations: true, node_id: true)
    end
  when "text"
    # text [--locations] [--tolerant] [--out DIR] [-e CODE | FILE...]: the text form of
    # each program -- to stdout, or one file a program under DIR (the path
    # with every `/` an `_`, and `.ast` added)
    locations = !!ARGV.delete("--locations")
    tolerant = !!ARGV.delete("--tolerant")
    outdir = (i = ARGV.index("--out")) ? ARGV.slice!(i, 2)[1] : nil
    if (i = ARGV.index("-e"))
      print AstOracle.text(RubyVM::AbstractSyntaxTree.parse(ARGV[i + 1], error_tolerant: tolerant), +"", locations: locations)
    else
      ARGV.each do |f|
        t = begin
          AstOracle.text(RubyVM::AbstractSyntaxTree.parse_file(f, error_tolerant: tolerant), +"", locations: locations)
        rescue SyntaxError
          "SyntaxError\n"
        rescue StandardError => e
          # (a tree the reference cannot answer in full: a literal whose
          #  value raises when it is made, say)
          "#{e.class}\n"
        end
        outdir ? File.write(File.join(outdir, f.tr("/", "_") + ".ast"), t) : print(t)
      end
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

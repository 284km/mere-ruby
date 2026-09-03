# Which names of ruby's core classes does mere-ruby not answer at all?
#
#   ruby tools/missing_names.rb list   > names.txt      # ruby: the names, one per line
#   ./mere-ruby tools/missing_names.rb probe names.txt # mere-ruby: the ones it lacks
#
# The list is ruby's own (instance_methods(false) + private ones, and the
# class's singleton methods), so it cannot be a claim of ours. The probe CALLS
# each name on a sample receiver and counts only "undefined method" -- an
# ArgumentError, TypeError or anything else means the name exists. Names that
# would end or block the process are skipped by name.
SAMPLES = {   # factories: every probe gets a fresh receiver
  "Integer" => -> { 1 }, "Float" => -> { 1.5 }, "String" => -> { "s" }, "Array" => -> { [1] }, "Hash" => -> { {a: 1} },
  "Range" => -> { (1..3) }, "Symbol" => -> { :s }, "NilClass" => -> { nil }, "TrueClass" => -> { true }, "FalseClass" => -> { false },
  "Rational" => -> { Rational(1, 2) }, "Complex" => -> { Complex(1, 2) }, "Proc" => -> { proc { |x| x } },
  "Method" => -> { 1.method(:+) }, "UnboundMethod" => -> { Integer.instance_method(:+) },
  "Regexp" => -> { Regexp.new("x") }, "MatchData" => -> { Regexp.new("x").match("x") }, "Time" => -> { Time.at(0) },
  "Struct" => -> { Struct.new(:a).new(1) }, "Exception" => -> { StandardError.new("m") },
  "Enumerator" => -> { [1].each }, "Comparable" => -> { 1 }, "Enumerable" => -> { [1] }, "Kernel" => -> { Object.new },
  "Numeric" => -> { 1 }, "Object" => -> { Object.new }, "Module" => -> { Module.new }, "Class" => -> { Class.new },
  "Encoding" => -> { Encoding::UTF_8 }, "Dir" => -> { Dir }, "File" => -> { File }, "IO" => -> { $stdout }, "Math" => -> { Math },
  "Process" => -> { Process }, "ObjectSpace" => -> { ObjectSpace }, "Marshal" => -> { Marshal }, "GC" => -> { GC },
  "Signal" => -> { Signal }, "Random" => -> { Random.new(1) }, "Thread" => -> { Thread.current },
}
SKIP = %w[exit exit! abort sleep gets readline readlines fork exec system spawn loop raise fail throw
          catch binding trap kill wait wait2 waitpid detach daemon exit_status! at_exit warn puts print p
          pp display putc syscall select instance_eval instance_exec class_eval module_eval eval
          `  freeze srand readpartial read sysread readchar readbyte getc getbyte each_line each_byte
          each_char each_codepoint each_grapheme_cluster times upto downto step each each_with_index
          each_with_object each_entry each_slice each_cons cycle lazy to_enum enum_for each_pair
          each_key each_value each_index reverse_each pass stop join value run wakeup].freeze
mode, file = ARGV
if mode == "list"
  SAMPLES.each_key do |cn|
    k = Object.const_get(cn)
    names = []
    if k.is_a?(Module)
      names += k.instance_methods(false).map { |m| "#{cn}##{m}" }
      names += k.private_instance_methods(false).map { |m| "#{cn}##{m}" } if cn == "Kernel"
      names += k.singleton_methods(false).map { |m| "#{cn}.#{m}" }
    end
    names.uniq.sort.each { |n| puts n }
  end
else
  missing = Hash.new { |h, k| h[k] = [] }
  total = 0
  File.readlines(file).map(&:chomp).each do |line|
    i = line.index("#") || line.index(".")
    cn, sep, m = line[0...i], line[i], line[(i + 1)..]
    next if SKIP.include?(m)
    next unless SAMPLES.key?(cn)
    recv = sep == "#" ? SAMPLES[cn].call : Object.const_get(cn)
    total += 1
    $stderr.puts line if ENV["MN_TRACE"]
    # "undefined method" with no arguments, then again with one (the receiver
    # itself): an operator or a method that insists on an argument answers
    # ArgumentError/TypeError to the second call when it exists at all.
    undefined = lambda do |*a|
      begin
        r9 = sep == "#" ? SAMPLES[cn].call : recv
        r9.__send__(m.to_sym, *a)
        false
      rescue NoMethodError => e
        e.message.start_with?("undefined method") && e.message.include?("'#{m}'")
      rescue Exception
        false
      end
    end
    missing[cn] << m if undefined.call && undefined.call(sep == "#" ? SAMPLES[cn].call : recv)
  end
  missing.each_value(&:uniq!)
  n = missing.values.sum(&:size)
  puts "#{n} of #{total} names undefined"
  missing.sort_by { |cn, ms| -ms.size }.each { |cn, ms| puts "#{cn} (#{ms.size}): #{ms.sort.join(' ')}" }
end

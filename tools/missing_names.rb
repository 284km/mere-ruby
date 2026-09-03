# Which of ruby's core-class names does mere-ruby not answer?
#
#   ruby tools/missing_names.rb list   > names.txt      # ruby: the names
#   ./mere-ruby tools/missing_names.rb probe names.txt  # mere-ruby: the verdict
#
# The list is ruby's own (instance_methods(false), Kernel's private ones, and
# each class's singleton methods), so it cannot be a claim of ours.
#
# Every name is asked TWICE, because the two spellings are two questions:
#   direct  eval("recv.name")     -- the call as a program writes it
#   send    recv.__send__(:name)  -- the same call through the dispatcher
# and each is tried with no argument, then with one (the receiver itself), so
# that a method which merely insists on an argument is not counted as absent.
# Only "undefined method" counts as absent; ArgumentError, TypeError, anything
# else means the name exists.
#
#   ABSENT    neither spelling reaches it -- a name to implement
#   SEND-ONLY direct works, send does not -- one name with two answers, which
#             is a dispatcher gap and not a missing method
#
# Asking only one of the two is how the first version of this file reported
# `Math.log` and `Time#strftime` as send gaps when they are simply absent.
#
# Names that would end or block the process are skipped by name.
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
  absent = Hash.new { |h, k| h[k] = [] }
  sendonly = Hash.new { |h, k| h[k] = [] }
  total = 0
  File.readlines(file).map(&:chomp).each do |line|
    i = line.index("#") || line.index(".")
    cn, sep, m = line[0...i], line[i], line[(i + 1)..]
    next if SKIP.include?(m)
    next unless SAMPLES.key?(cn)
    total += 1
    $stderr.puts line if ENV["MN_TRACE"]
    fresh = -> { sep == "#" ? SAMPLES[cn].call : Object.const_get(cn) }
    undefined = lambda do |how, argc|
      recv = fresh.call
      begin
        if how == :send
          argc == 0 ? recv.__send__(m.to_sym) : recv.__send__(m.to_sym, recv)
        else
          # the call as written: `recv.name` / `recv.name(recv)`, through eval
          # so that the name is a real method call and not a dispatcher entry
          eval(argc == 0 ? "recv.#{m}" : "recv.#{m}(recv)")
        end
        false
      rescue NoMethodError => e
        e.message.start_with?("undefined method") && e.message.include?("'#{m}'")
      rescue Exception
        false
      end
    end
    no_send = undefined.call(:send, 0) && undefined.call(:send, 1)
    next unless no_send
    # only names the sender cannot reach are worth a second question
    no_direct = undefined.call(:direct, 0) && undefined.call(:direct, 1)
    (no_direct ? absent : sendonly)[cn] << m
  end
  [["ABSENT", absent], ["SEND-ONLY", sendonly]].each do |label, h|
    h.each_value(&:uniq!)
    n = h.values.sum(&:size)
    puts "#{label}: #{n} of #{total} names"
    h.sort_by { |cn, ms| -ms.size }.each { |cn, ms| puts "  #{cn} (#{ms.size}): #{ms.sort.join(' ')}" }
    puts
  end
end

# Which string builders grow faster than their input? Each operation runs at n
# and at 4n; linear is a ratio of about 4, and a ratio above 10 (on a run long
# enough to time) is printed with SUPERLINEAR. note 290 found nine that way --
# Random#bytes, reverse, inspect, dump, scrub, center, format("%-*s"),
# Array#to_h / Enumerable#to_h, gsub(str, str) -- all the same mistake: a Mere
# `str` is immutable, and `acc ++ piece` per step copies the result so far.
#
#   ./mere-ruby bench/quad_strings.rb [n]      (n defaults to 16384)
#   ruby bench/quad_strings.rb [n]             the reference: every row near 4
def t; t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC); yield; Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0; end
OPS = {
  "Random#bytes"   => ->(n) { Random.new(1).bytes(n) },
  "upcase"         => ->(n) { ("a" * n).upcase },
  "downcase"       => ->(n) { ("A" * n).downcase },
  "swapcase"       => ->(n) { ("aB" * (n/2)).swapcase },
  "capitalize"     => ->(n) { ("ab" * (n/2)).capitalize },
  "tr"             => ->(n) { ("abc" * (n/3)).tr("a", "x") },
  "delete"         => ->(n) { ("abc" * (n/3)).delete("b") },
  "squeeze"        => ->(n) { ("aab" * (n/3)).squeeze },
  "reverse"        => ->(n) { ("abc" * (n/3)).reverse },
  "gsub str"       => ->(n) { ("abc" * (n/3)).gsub("b", "x") },
  "gsub rx"        => ->(n) { ("abc" * (n/3)).gsub(/b/, "x") },
  "inspect"        => ->(n) { ("a\n" * (n/2)).inspect },
  "dump"           => ->(n) { ("a\n" * (n/2)).dump },
  "pack C*"        => ->(n) { ([65] * n).pack("C*") },
  "pack m"         => ->(n) { ["a" * n].pack("m") },
  "unpack m"       => ->(n) { [("a" * n)].pack("m").unpack1("m") },
  "Array#join"     => ->(n) { (["ab"] * (n/2)).join(",") },
  "Array#inspect"  => ->(n) { ([1] * (n/2)).inspect },
  "Hash#inspect"   => ->(n) { (0...(n/8)).to_h { |i| [i, i] }.inspect },
  "Array#to_h"     => ->(n) { (0...(n/8)).map { |i| [i, i] }.to_h },
  "Integer#to_s(2)"=> ->(n) { (2 ** (n/4)).to_s(2) },
  "String#*"       => ->(n) { "ab" * (n/2) },
  "center"         => ->(n) { "a".center(n) },
  "succ"           => ->(n) { ("a" * n).succ },
  "encode utf16"   => ->(n) { ("a" * n).encode("UTF-16LE") },
  "scrub"          => ->(n) { ("a\xff" * (n/2)).scrub },
  "unicode_normalize" => ->(n) { ("é" * (n/2)).unicode_normalize(:nfd) },
  "format %s"      => ->(n) { format("%s", "a" * n) },
  "sprintf %-*s"   => ->(n) { format("%-*s", n, "a") },
  "StringIO write" => ->(n) { require "stringio"; io = StringIO.new; (n/16).times { io.write("a" * 16) }; io.string },
  "<< loop"        => ->(n) { s = +""; n.times { s << "a" }; s },
  "each_char join" => ->(n) { ("ab" * (n/2)).each_char.to_a.join },
  "split"          => ->(n) { ("a," * (n/2)).split(",") },
  "lines"          => ->(n) { ("a\n" * (n/2)).lines },
  "Marshal.dump"   => ->(n) { Marshal.dump("a" * n) },
  "JSON.generate"  => ->(n) { require "json"; JSON.generate(["a" * 8] * (n/8)) },
}
n = (ARGV[0] || 16384).to_i
OPS.each do |name, f|
  begin
    a = t { f.(n) }; b = t { f.(n * 4) }
    printf("%-18s %8.4f %8.4f  x%.1f%s\n", name, a, b, b / [a, 1e-6].max, (b / [a, 1e-6].max > 10 && b > 0.05) ? "  <-- SUPERLINEAR" : "")
  rescue => e
    printf("%-18s error %s\n", name, e.class)
  end
end

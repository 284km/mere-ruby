# A builtin that builds its whole answer first and then yields it must keep
# it while the block runs: a collection in the block took the rest.
# - String#split with a block yielded the pieces after one as "", and
#   Bundler's lockfile parser, which reads a lockfile with
#   `split(/((?:\r?\n)+)/) { |line| ... }`, then saw no PLATFORMS ("Your
#   bundle only supports platforms []").
# - Array#zip with a block stopped on a swept tuple.

lock = "GEM\n  remote: https://rubygems.org/\n  specs:\n" +
       (1..40).map { |i| "    gem#{i} (#{i}.0)\n" }.join +
       "\nPLATFORMS\n  ruby\n\nDEPENDENCIES\n" +
       (1..10).map { |i| "  gem#{i}\n" }.join + "\nBUNDLED WITH\n   4.0.20\n"

def read_sections(lock)
  sections = Hash.new { |h, k| h[k] = [] }
  current = nil
  lock.split(/((?:\r?\n)+)/) do |line|
    next if line.match?(/^\s*$/)
    if /^[^\s]/.match?(line)
      current = line
    elsif current && line =~ /^  (.*)$/
      sections[current] << $1.strip
    end
  end
  sections
end

original = GC.stress
begin
  GC.stress = true
  sections = read_sections(lock)
  p sections.keys
  p sections["PLATFORMS"], sections["DEPENDENCIES"].size, sections["GEM"].size, sections["GEM"].last

  text = (1..60).map { |i| "line #{i}" }.join("\n")
  got = []
  ret = text.split(/\n/) { |l| got << l.upcase }
  p got.size, got.count(&:empty?), got.first, got.last, ret.equal?(text)
  got = []
  text.split(/(\n)/) { |l| got << l }
  p got.size, got.count(&:empty?), got.last
  got = []
  text.split("\n") { |l| got << l }
  p got.size, got.count(&:empty?)
  got = []
  text.split(" ", 30) { |l| got << l }
  p got.size, got.count(&:empty?), got.last.size

  a = (1..60).map { |i| "e#{i}" }
  got = []
  p a.zip(a.dup) { |x, y| got << x + y }
  p got.size, got.count(&:empty?), got.last
  got = []
  a.zip(a.map(&:upcase), 1..60) { |t| got << t }
  p got.size, got.last
ensure
  GC.stress = original
end

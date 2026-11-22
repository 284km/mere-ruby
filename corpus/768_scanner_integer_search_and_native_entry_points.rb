require "strscan"

[false, true].each do |fixed|
  [:skip_until, :exist?, :scan_until, :check_until].each do |operation|
    scanner = StringScanner.new("é:abc:z", fixed_anchor: fixed)
    scanner.pos = 2
    result = scanner.public_send(operation, /(?<end>z)/)
    p [fixed, operation, result, scanner.pos, scanner.charpos,
       scanner.matched, scanner.captures, scanner[:end], scanner.pre_match, scanner.post_match]
    p [scanner.unscan.pos, scanner.matched?]
    p [scanner.public_send(operation, /absent/), scanner.pos, scanner.matched?, scanner.captures]
  end
  [false, true].each do |advance|
    [false, true].each do |ret_string|
      scanner = StringScanner.new("é:abc:z", fixed_anchor: fixed)
      scanner.pos = 2
      p [fixed, advance, ret_string, scanner.search_full(/z/, advance, ret_string),
         scanner.pos, scanner.matched, scanner.pre_match, scanner.post_match]
    end
  end
end

# CRuby's skip entries run their own scan, without calling a Ruby override
# of scan or scan_until on the scanner.
class ScannerWithOverriddenScan < StringScanner
  attr_reader :calls
  def initialize(text)
    super(text)
    @calls = []
  end
  def scan(*)
    @calls << :scan
    "override"
  end
  def scan_until(*)
    @calls << :scan_until
    "override"
  end
end
scanner = ScannerWithOverriddenScan.new("abcd")
p [scanner.skip(/a/), scanner.pos, scanner.matched, scanner.calls]
p [scanner.skip_until(/d/), scanner.pos, scanner.matched, scanner.calls]
p [scanner.skip(/absent/), scanner.pos, scanner.matched, scanner.calls]
# ...and so do scan_full and scan_integer
scanner = ScannerWithOverriddenScan.new("abcd")
p [scanner.scan_full(/a/, true, true), scanner.pos, scanner.calls]
p [scanner.scan_full(/b/, false, false), scanner.pos, scanner.matched, scanner.calls]
p [scanner.scan_full(/absent/, true, true), scanner.pos, scanner.matched, scanner.calls]
scanner = ScannerWithOverriddenScan.new("12ab")
p [scanner.scan_integer, scanner.pos, scanner.calls]
p [scanner.scan_integer, scanner.pos, scanner.matched, scanner.calls]
scanner = ScannerWithOverriddenScan.new("-0x1fz")
p [scanner.scan_integer(base: 16), scanner.pos, scanner.calls]

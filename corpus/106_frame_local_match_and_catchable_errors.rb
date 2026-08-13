# `$~` belongs to the frame that matched: a method's match is invisible to its
# caller, and the caller's is invisible to the method.
def match_inside
  "abc" =~ /b/
  $~[0]
end
p match_inside
p $~.nil?
p Regexp.last_match.nil?

"xyz" =~ /y/
p $~[0]

def clean
  $~.nil?
end
p clean
p $~[0]

def with_group
  "hello" =~ /e(l+)/
  [$1, $~.pre_match]
end
p with_group
p $1

# a block is not a frame: it shares the method's match
def via_block
  ["a1"].map { |s| s =~ /(\d)/ ? $1 : nil }
end
p via_block

# the numbered globals follow $~ through every shape of match
"2026-08-14" =~ /(\d+)-(\d+)-(\d+)/
p [$1, $2, $3, $4, $~[0], $~.captures, $&, $`, $']
p "a1b2".gsub(/(\d)/) { "<#{$1}>" }
p "x=1, y=2".scan(/(\w)=(\d)/)
"no" =~ /(z)/
p [$1, $~]

# The primitives that do not apply to a receiver raise a NoMethodError a ruby
# program can rescue, rather than an interpreter-level failure.
def try
  yield
rescue NoMethodError
  :no_method
rescue StandardError => e
  "other: #{e.class}"
end
p try { 1.length }
p try { nil.size }
p try { :sym.empty? }
p try { nil[0] }
p try { Object.new.to_a }

# ...and nil answers the conversions it has
p [nil.to_i, nil.to_f, nil.to_a, nil.to_s]

# String#to_i / #to_f read as far as they can and answer 0 when that is
# nowhere, rather than refusing the string.
p ["".to_i, "abc".to_i, "12".to_i, "12abc".to_i, " 42 ".to_i, "-7".to_i]
p ["1_000".to_i, "3.9".to_i, "0x1f".to_i, "  -12x".to_i, "007".to_i]
p ["".to_f, "abc".to_f, "3.9".to_f, "1_0.2_5".to_f, ".5".to_f, "-.5".to_f]
p ["1e3".to_f, "1.5e-3".to_f, "1e".to_f, "1.2.3".to_f, "0x1f".to_f]
p ["ff".to_i(16), "101".to_i(2), Integer("42"), Float("1.5")]

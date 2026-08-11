# `alias $NEW $OLD` aliases a global: the new name reads and writes the old
# one's slot. (That is all `English` is.)
alias $NEW $OLD
$OLD = 1
p $NEW
$NEW = 2
p $OLD, $NEW
p defined?($NEW)

alias $ERR $!
begin
  raise ArgumentError, "boom"
rescue
  p $ERR.class.to_s, $ERR.message
end

# $& / $` / $' are views on the last match
"hello world" =~ /o w/
p $&, $`, $'
p $~.class.to_s, $~[0]
p $~.pre_match, $~.post_match, $~.begin(0), $~.end(0), $~.string

"abc" =~ /z/
p $~

require "English"
begin
  raise TypeError, "t"
rescue
  p $ERROR_INFO.class.to_s
end
"one two" =~ /e t/
p $MATCH, $PREMATCH, $POSTMATCH

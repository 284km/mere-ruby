# The predefined globals: what is read-only, what coerces, and what is an
# alias of what.
#
# language/predefined_spec failed 75 of its assertions. Almost all of it was
# one shape: mere-ruby ACCEPTED every assignment and answered nil for every
# switch, where ruby refuses, coerces, or has a default.
#
#   - the match globals are READ-ONLY. A literal `$& = ""` is refused by the
#     parser (SyntaxError "Can't set variable $&"); reached through an ALIAS it
#     is a NameError naming the alias. The alias table tells them apart.
#   - $!, $:, $", $< and $? are read-only too, always by NameError -- and every
#     spelling has to be caught, so $LOAD_PATH / $-I / $LOADED_FEATURES /
#     $FILENAME are now real ALIASES rather than separate slots that happened
#     to hold the same array.
#   - $/ $-0 $\ $, must be Strings, and the message names the SPELLING that was
#     written, so `$-0` and `$/` -- one setting -- say different things. $; also
#     takes a Regexp. $~ takes a MatchData or nil. $. converts with #to_int,
#     $0 with #to_str, and $stdout/$stderr must have a #write.
#   - $VERBOSE keeps only nil / false / true: anything else truthy becomes true.
#   - $-d $-v $-w are aliases of $DEBUG / $VERBOSE; $-a $-l $-p read as false.
#   - $+ is the last NON-NIL capture, not the last group.
#   - `gets` sets $_, and sets it to nil at EOF.

require 'stringio'

def t(label)
  puts "%-40s %s" % [label, (yield).inspect]
rescue Exception => e
  puts "%-40s <%s: %s>" % [label, e.class, e.message]
end

# A SyntaxError's REPORT is formatted differently here (ruby quotes the source
# line and points at the column), so only the class is compared for those.
def tc(label)
  puts "%-40s %s" % [label, (yield).inspect]
rescue Exception => e
  puts "%-40s <%s>" % [label, e.class]
end

# $+ is the last capture that PARTICIPATED
"foo" =~ /(f)(o+)/
puts "$+                                       #{$+.inspect}"
puts "$~.captures.last                         #{$~.captures.last.inspect}"
"xy" =~ /(x)(a)?(y)/
puts "$+ with a nil group                      #{$+.inspect}"
puts "$~.captures                              #{$~.captures.inspect}"

# read-only: the match globals, direct and through an alias
tc('$& = "" (direct)')        { eval %q{$& = ""} }
tc('$` = "" (direct)')        { eval %q{$` = ""} }
tc("$' = \"\" (direct)")     { eval %q{$' = ""} }
tc('$+ = "" (direct)')        { eval %q{$+ = ""} }
tc('$1 = "" (direct)')        { eval %q{$1 = ""} }
t('aliased $& then assign')  { eval %q{alias $cp_amp $&; $cp_amp = ""} }
eval %q{alias $cp_amp2 $&}
puts "aliased $& then read                    #{$cp_amp2.class.inspect}"
t('aliased $` then assign')  { eval %q{alias $cp_bq $`; $cp_bq = ""} }
t('aliased $+ then assign')  { eval %q{alias $cp_pl $+; $cp_pl = ""} }

# read-only by name, in every spelling
['$!', '$:', '$LOAD_PATH', '$-I', '$"', '$LOADED_FEATURES', '$<', '$FILENAME', '$?'].each do |g|
  t("#{g} = []") { eval "#{g} = []" }
end

# the aliases really are one slot
t('$LOAD_PATH.equal?($:)')   { $LOAD_PATH.equal?($:) }
t('$-I.equal?($:)')          { $-I.equal?($:) }
t('$LOADED_FEATURES eq $"')  { $LOADED_FEATURES.equal?($") }
t('$PROGRAM_NAME.equal?($0)'){ $PROGRAM_NAME.equal?($0) }
t('$-0.equal?($/)')          { $-0.equal?($/) }
t('$: holds only Strings')   { $:.all? { |x| x.is_a?(String) } }

# what must be a String, named by the spelling written
t('$/ = 1')                  { $/ = 1 }
t('$/ = true')               { $/ = true }
t('$-0 = 1')                 { $-0 = 1 }
t('$\ = 1')                  { $\ = 1 }
t('$, = 1')                  { $, = 1 }
t('$; = 1')                  { $; = 1 }
t('$; = /re/ is allowed')    { old = $;; $; = /re/; v = $;.class; $; = old; v }
t('$/ = "x" is allowed')     { old = $/; $/ = "x"; v = $/; $/ = old; v }

# $~ takes a MatchData or nil
t('$~ = Object.new')         { $~ = Object.new }
t('$~ = 1')                  { $~ = 1 }
t('$~ = nil is allowed')     { $~ = nil; $~.inspect }

# the converting ones
t('$. = "x"')                { $. = "x" }
t('$. = 5 is allowed')       { $. = 5; $. }
t('$0 = nil')                { $0 = nil }
t('$0 = "prog" is allowed')  { $0 = "prog"; $0 }
t('$stdout = nil')           { $stdout = nil }
t('$stdout = Object.new')    { $stdout = Object.new }

# the switches
t('$DEBUG default')          { $DEBUG }
t('$-d tracks $DEBUG')       { $DEBUG = true; v = $-d; $DEBUG = false; v }
t('$-d = writes $DEBUG')     { $-d = true; v = [$-d, $DEBUG]; $DEBUG = false; v }
t('$-a')                     { $-a }
t('$-l')                     { $-l }
t('$-p')                     { $-p }
t('$VERBOSE = 1 becomes true'){ old = $VERBOSE; $VERBOSE = 1; v = $VERBOSE; $VERBOSE = old; v }
t('$VERBOSE = "x" -> true')  { old = $VERBOSE; $VERBOSE = "x"; v = $VERBOSE; $VERBOSE = old; v }
t('$VERBOSE = false stays')  { old = $VERBOSE; $VERBOSE = false; v = $VERBOSE; $VERBOSE = old; v }
t('$VERBOSE = nil stays')    { old = $VERBOSE; $VERBOSE = nil; v = $VERBOSE; $VERBOSE = old; v }
t('$-v follows $VERBOSE')    { old = $VERBOSE; $VERBOSE = false; v = $-v; $VERBOSE = old; v }
t('$-w follows $VERBOSE')    { old = $VERBOSE; $VERBOSE = true; v = $-w; $VERBOSE = old; v }

# an ordinary global is still ordinary
t('$my_global = 1')          { $my_global = 1; $my_global }

# gets sets $_ -- and nils it at EOF
io = StringIO.new("foo\nbar\n")
t('$_ before any read')      { $_ }
t('$_ after the first gets') { io.gets; $_ }
t('$_ after the second')     { io.gets; $_ }
t('$_ at EOF')               { io.gets; $_ }

# a standard stream's encodings
t('STDOUT.external_encoding'){ STDOUT.external_encoding }
t('STDOUT.internal_encoding'){ STDOUT.internal_encoding }
t('STDERR.external_encoding'){ STDERR.external_encoding }
t('STDIN.external_encoding')  { STDIN.external_encoding.class }
t('respond_to?(:external_encoding)') { STDOUT.respond_to?(:external_encoding) }
t('respond_to?(:set_encoding)')      { STDOUT.respond_to?(:set_encoding) }
t('set_encoding answers self'){ STDOUT.set_encoding("UTF-8").equal?(STDOUT) }
t('set_encoding records both'){ STDERR.set_encoding("IBM775", "IBM866")
                                [STDERR.external_encoding.to_s, STDERR.internal_encoding.to_s] }
t('STDOUT.equal?(STDOUT)')   { STDOUT.equal?(STDOUT) }
t('STDOUT.equal?(STDERR)')   { STDOUT.equal?(STDERR) }
t('$stdout.equal?(STDOUT)')  { $stdout.equal?(STDOUT) }

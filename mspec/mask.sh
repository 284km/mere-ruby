#!/bin/sh
# mspec/mask.sh -- SOURCE this. What a recorded line may say.
#
# Two rules live here, and they live in ONE place because a record is checked
# into a PUBLIC repo: every tool that writes one has to mask the same way. When
# `strip_noise` was a private function inside scoreboard.sh, the second tool
# that needed it would have had to copy it -- and a rule written twice becomes
# two rules the moment one of them is corrected.
#
#   strip_noise  masks what identifies the MACHINE (paths, tmpdirs, $HOME,
#                addresses) and what is an object DUMP rather than a cause.
#   clip_cause   bounds the length, because the field's contract is "short
#                enough to read in a table".
#
# ⚠ Whatever a tool writes with these still has to be listed in
#   record_hygiene.sh, which checks a FIXED set of files: a record nobody
#   listed is a record nobody checks.

# A verdict alone does not say WHERE to work. The sweep used to compute one and
# throw the output away (`rm -f "$raw"` below), so 603 DIFFs were 603 unknowns:
# the tags files named the files and nothing else. Classifying by message first
# is the difference between fixing one name and guessing among hundreds -- on
# this codebase a batch of 346 errors turned out to be 194 instances of ONE name.
#
# So run_one now echoes "VERDICT<TAB>CAUSE":
#   CRASH -> the abort message from the mere-ruby side
#   DIFF  -> the first line where the two sides disagree
# Only the leading "path:line:" is stripped. The message itself is kept whole,
# quoted identifiers included: normalising it further merges causes that are
# genuinely different, and a bucket that mixes them cannot be acted on.
strip_noise() {  # stdin -> stdout, a line usable as a bucket key
  # $HOME goes the way of the tmpdir and the address: a recorded line is checked
  # into a PUBLIC repo, and the operator's home path is neither a property of the
  # interpreter nor something to publish. This is the same masking rule the other
  # two already are, applied to the third thing that identifies the machine.
  #
  # An ENVIRONMENT DUMP is masked by SHAPE, not by variable name. core/env's
  # specs print ENV, so a failure message carries `"NAME" => "value"` pairs --
  # which is how a session token reached a public commit WITH ITS VALUE on
  # 2026-09-05. record_hygiene.sh had a LIST of variable names and the token was
  # not on it (the session id beside it was); naming variables one at a time
  # cannot keep up with an environment.
  #
  # So a STRING-KEYED HASH LITERAL is collapsed whole: `{"..."` up to its `}`
  # (or to the end of a clipped line) becomes `{...}`. Two earlier versions of
  # this mask tried to keep the keys and rewrite only the values, and both were
  # worse than useless:
  #
  #   - the first knew only ruby 3.4's `"K" => "V"` spacing. The records span
  #     the reference-ruby upgrade and 3.2 writes `"K"=>"V"`, so three older
  #     commits kept the token -- the same question asked in one spelling.
  #   - the second matched pair by pair and ran off its quote boundaries on a
  #     line the other masks had already rewritten, producing
  #     `{"K" => "V"LC_ALL" => "en_US.UTF-8"` -- a mask that leaves half the
  #     text it was meant to remove.
  #
  # A cause is a SUMMARY. Losing the contents of a hash costs a little
  # readability (`{"a" => 1}` collapses too) and removes a whole class of
  # accident: there is no boundary left to get wrong.
  # ⚠ LC_ALL=C on the tools themselves, not on the shell that sources this:
  #   sed refuses a line containing an invalid byte under a UTF-8 locale
  #   ("RE error: illegal byte sequence") and the whole masking stage dies --
  #   on exactly the lines that most need masking. Per-command, so nothing
  #   about the caller's environment changes.
  LC_ALL=C sed -e 's|^[^ ]*\.rb:[0-9]*: |*.rb:N: |' \
      -e 's|/[^ ]*/mrb_[A-Za-z0-9]*|TMPDIR|g' \
      -e 's|/var/folders/[^ ]*|TMPDIR|g' \
      -e "s|${HOME}[^ \"]*|HOME|g" \
      -e 's|{"[^}]*}|{...}|g' \
      -e 's|{"[^}]*$|{...|' \
      -e 's|0x[0-9a-f]*|0xADDR|g' \
  | LC_ALL=C perl -pe 'if (!utf8::decode(my $t = $_)) { s/([\x80-\xFF])/sprintf("\\x%02X", ord($1))/ge }'
  # ⚠ ...and a byte that is not valid UTF-8 is ESCAPED, because a record is a
  #   text file that people and tools read. core/symbol/inspect's `quotes
  #   BINARY symbols` prints a raw 0xA4, and it went into mspec/tags/ and was
  #   pushed: from then on `grep` treated that record as BINARY and answered
  #   nothing without -a, which is the quietest way for a check to pass. Only
  #   lines that fail to decode are touched, so ordinary non-ASCII text (a
  #   Japanese string in a cause, an em dash in a heading) is left alone.
}

# A cause is a SUMMARY -- the one line the two sides first disagree on, kept so
# the failures can be grouped and one of them reproduced. It is not the output.
#
# Nothing enforced that until core/env taught it: those specs print ENV, so once
# `ENV.filter` became reflectable here the first differing line was a Method whose
# inspect carries the entire process environment. An 11KB "cause" went into
# mspec/tags/ and CAUSES.md and was pushed -- PATH, HOME, SSH_AUTH_SOCK, session
# ids and an internal package-index host, in a public repo, inside a field whose
# whole job is to be a short label.
#
# The cap is the fix rather than a mask for ENV specifically: the field's contract
# is "short enough to read in a table", and any object with a large inspect --
# a big hash, a long array, a deep struct -- reaches it the same way.
CAUSE_MAX=${CAUSE_MAX:-240}
clip_cause() {  # $1 = cause -> echoes it, bounded
  printf '%s' "$1" | awk -v n="$CAUSE_MAX" '{ if (length($0) > n) print substr($0,1,n) " ...[clipped]"; else print $0 }'
}

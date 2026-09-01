#!/bin/sh
# Refuse to leave machine-identifying text in the checked-in records.
#
# These files are pushed to a PUBLIC repo. A spec that prints ENV puts the whole
# process environment into a failure message, and the first line of a diff is
# copied verbatim into the records -- that is how PATH, HOME, SSH_AUTH_SOCK, a
# session id and an internal package-index host got published in one commit.
# scoreboard.sh masks $HOME and clips the cause now; this is the check that says
# so, because a mask is a claim and only a check is evidence.
#
#   ./mspec/record_hygiene.sh [file ...]     # default: every tracked record
#
# TWO THINGS THIS GOT WRONG THE FIRST TIME, both of which made it quiet rather
# than wrong -- the worse failure for a detector:
#
#  1. `grep` without -a. A record that carries bytes which are not valid UTF-8
#     is treated as binary and grep says NOTHING. mspec/DIFF_LINES.txt is exactly
#     such a file and it holds three local paths; the first version of this check
#     passed it. The files most likely to have captured raw output are the files
#     most likely to be binary-ish, so -a is not optional here.
#  2. A hardcoded file list. It named tags/, CAUSES.md and SPEC_STATUS.md, and
#     the leak was also in DIFF_LINES.txt, which is a record too. The list now
#     comes from git, so a record added later is covered without editing this.
set -u
LC_ALL=C
export LC_ALL
here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/.." && pwd)"
if [ "$#" -gt 0 ]; then
  files="$*"
else
  files=$(cd "$root" && git ls-files 'mspec/*.txt' 'CAUSES.md' 'SPEC_STATUS.md' 'bootstraptest/*.txt' 2>/dev/null | sed "s|^|$root/|")
fi
[ -n "$files" ] || { echo "no records to check" >&2; exit 2; }
rc=0
# Patterns that identify the machine or its operator rather than the interpreter.
# `/Users/` and `/home/` catch a home path even when $HOME is spelled some other
# way (a different user, a symlink, a sudo run): the masking cannot rely on the
# variable it happened to run with.
# `/var/folders/` is macOS's per-user tmpdir. It is on this list for two
# reasons at once: it names the machine, and the name inside it changes on every
# run, so a record carrying one differs from itself and can no longer show that
# something REAL moved. It sat unmasked in bootstraptest/ERRORS.txt while this
# check read that very file and reported it clean -- the detector only ever
# catches the leaks someone thought of.
for pat in '/Users/' '/home/' '/var/folders/' 'ruby-btest-' 'SSH_AUTH_SOCK' \
           'SECURITYSESSIONID' 'XPC_SERVICE_NAME' \
           'CLAUDE_CODE_SESSION_ID' 'LaunchInstanceID' '__CF_USER_TEXT_ENCODING' \
           'VSCODE_IPC_HOOK' 'GVM_PATH_BACKUP' 'LD_LIBRARY_PATH' 'SSH_AGENT_PID'; do
  hits=$(grep -al -- "$pat" $files 2>/dev/null)
  [ -n "$hits" ] && { echo "LEAK  $pat"; echo "$hits" | sed "s|$root/|        |"; rc=1; }
done
# A cause field long enough to hold an object dump is the mechanism, so bound it
# directly too: the longest line in a record should be a sentence, not a heap.
long=$(awk 'length($0) > 400 { print FILENAME": "length($0)" chars" }' $files 2>/dev/null | head -5)
[ -n "$long" ] && { echo "LONG  a recorded line is over 400 chars (an object dump, not a cause):"; echo "$long" | sed "s|$root/|        |"; rc=1; }
[ "$rc" = 0 ] && echo "records clean ($(echo $files | wc -w | tr -d ' ') files)"
exit $rc

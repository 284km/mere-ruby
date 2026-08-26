#!/bin/sh
# Refuse to leave machine-identifying text in the checked-in records.
#
# These files are pushed to a PUBLIC repo. A spec that prints ENV puts the whole
# process environment into a failure message, and the first line of a diff is
# copied verbatim into mspec/tags/ and CAUSES.md -- that is how PATH, HOME,
# SSH_AUTH_SOCK, a session id and an internal package-index host got published in
# one commit. scoreboard.sh masks $HOME and clips the cause now; this is the check
# that says so, because a mask is a claim and only a check is evidence.
#
#   ./mspec/record_hygiene.sh [file ...]     # default: the records
set -u
LC_ALL=C
export LC_ALL
here="$(cd "$(dirname "$0")" && pwd)"
files="${*:-$here/tags/*.txt $here/../CAUSES.md $here/../SPEC_STATUS.md}"
rc=0
# Patterns that identify the machine or its operator rather than the interpreter.
# `/Users/` and `/home/` catch the home path even when $HOME is spelled some other
# way (a different user, a symlink, a sudo run) -- the masking cannot rely on the
# variable it happens to be running with.
for pat in '/Users/' '/home/' 'SSH_AUTH_SOCK' 'SECURITYSESSIONID' 'XPC_SERVICE_NAME' \
           'CLAUDE_CODE_SESSION_ID' 'LaunchInstanceID' '__CF_USER_TEXT_ENCODING' \
           'VSCODE_IPC_HOOK' 'GVM_PATH_BACKUP' 'LD_LIBRARY_PATH'; do
  hits=$(grep -l -- "$pat" $files 2>/dev/null)
  [ -n "$hits" ] && { echo "LEAK  $pat"; echo "$hits" | sed 's/^/        /'; rc=1; }
done
# A cause field long enough to hold an object dump is the mechanism, so bound it
# directly too: the longest line in a tags file should be a sentence, not a heap.
long=$(awk 'length($0) > 400 { print FILENAME": "length($0)" chars"; }' $here/tags/*.txt 2>/dev/null | head -5)
[ -n "$long" ] && { echo "LONG  a recorded line is over 400 chars (an object dump, not a cause):"; echo "$long" | sed 's/^/        /'; rc=1; }
[ "$rc" = 0 ] && echo "records clean"
exit $rc

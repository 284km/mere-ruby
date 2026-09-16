#!/bin/sh
# Each single-namespace arm of the class dispatcher (File/FileTest, IO, Dir,
# Math) is GUARDED by a name list in name_spec, and the same list answers
# respond_to?. If the arm grows a name the list does not carry, the call is
# refused for a method that is right there; if the list carries a name the arm
# does not implement, respond_to? claims one that is not. Either way the two
# doors disagree, which is the defect this file exists to prevent.
#
# So: re-derive each arm's implemented names from main.mere and compare.
set -u
cd "$(dirname "$0")/.." || exit 2
python3 - "$@" <<'PY'
import io, re, sys

src = io.open('main.mere', encoding='utf-8').read()
spec = io.open('m_state.mere', encoding='utf-8').read()

def arm_body(start_re):
    m = re.search(start_re, src)
    if not m:
        return None
    # the arm runs to its own terminal NoMethodError, which names the namespace.
    end = re.compile(r"raise_exc world \"NoMethodError\" \(\"undefined method '\" \+\+ name \+\+ \"' for \w+\"\)")
    e = end.search(src, m.end())
    return src[m.end():e.end()] if e else None

def spec_names(tag):
    m = re.search(r'else if str_eq tag "%s" then \(?(.*?)\)?\n  else if str_eq tag ' % tag,
                  spec, re.S)
    if not m:
        return None
    lits = re.findall(r'"([^"]*)"', m.group(1))
    return set(x for x in ''.join(lits).split('|') if x)

# (tag, where the arm starts, names the arm implements but that belong to a
#  DIFFERENT namespace sharing the same code)
ARMS = [
    ('filens', r'else if \(\(str_eq c "File" \|\| str_eq c "FileTest"\) \|\| str_eq c "IO"\)', 'ions'),
    ('dirns',  r'else if str_eq c "Dir" && ns_class_method c name', None),
    ('mathns', r'else if str_eq c "Math" && ns_class_method c name', None),
]

rc = 0
for tag, start, shared in ARMS:
    body = arm_body(start)
    if body is None:
        print("ns_names: could not find the %s arm -- the guard or the terminal moved" % tag)
        rc = 1
        continue
    impl = set(re.findall(r'str_eq name "([^"]+)"', body))
    want = spec_names(tag)
    if want is None:
        print("ns_names: no name_spec arm for tag %s" % tag)
        rc = 1
        continue
    if shared:
        sh = spec_names(shared) or set()
        want = want | sh
    missing = sorted(impl - want)
    extra = sorted(want - impl)
    if missing:
        print("ns_names: %s ARM implements names the list refuses:" % tag)
        for n in missing:
            print("    " + n)
        rc = 1
    if extra:
        print("ns_names: %s LIST claims names the arm does not implement:" % tag)
        for n in extra:
            print("    " + n)
        rc = 1
    if not missing and not extra:
        print("ns_names: %-7s %d names, arm and list agree" % (tag, len(impl)))
sys.exit(rc)
PY

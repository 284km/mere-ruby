#!/usr/bin/env python3
"""Run Rails 8.1.4.1's own component tests on two interpreters, file by file.

restore   download the locked archives (the only network step)
install   each interpreter installs Bundler and the locked gems into its own
          empty gem home, from the archives only
run       run selected test files on both sides and classify every test name
compare   per-file differences between two results.json files
"""
import argparse
import concurrent.futures
import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import threading
import urllib.request

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent
RAILSTEST = ROOT.parent
REPO = RAILSTEST.parent
WALL = 600
RSS_KB = 2 * 1024 * 1024
MAX_JOBS = 2
SEED = '12345'
COMPONENTS = ('activesupport', 'activemodel', 'actionview', 'actionpack', 'activejob', 'actionmailer',
              'activerecord', 'railties', 'actioncable', 'activestorage', 'actiontext', 'actionmailbox')
# A result line is `Class#test_name = 0.01 s = .`, read from the start of the
# line: a class name may hold spaces (a `describe "..."` block). A test that
# prints to stdout without a newline puts that output in front of its own
# result line; the name read then carries the output, so it is MISSING on one
# side and EXTRA on the other (or both sides print it alike) -- never a MATCH
# that did not happen.
CASE = re.compile(r'^(.+?#.+?) = ([0-9.]+) s = ([.FES])$', re.M)
CASE_START = re.compile(r'^(.+?#.+?) = ')
CASE_END = re.compile(r'^([0-9.]+) s = ([.FES])$')
# The worse of two verdicts for one name, when a transcript reports it twice
SEVERITY = {'.': 0, 'S': 1, 'F': 2, 'E': 3}
VERDICTS = ('MATCH', 'RED', 'MISSING', 'UNCONFIRMED', 'BOTH', 'EXTRA')
CASE_IDENTITY_POLICIES = ('literal', 'opaque-class-addresses', 'rails-argument-descriptions')
ANONYMOUS_CLASS = re.compile(r'#<Class:0x([0-9a-fA-F]+)>')
# Only this unchanged Rails file generates these three test names from the
# current clock. Its assertions still run on the original, unmodified values.
ARGUMENT_SOURCE_SHA256 = '6ab0a13d10a0c5a881a66bf37908a0381ed507ae8dc99b5b3e4093575b128a2c'
_DATE = r'\d{4}-\d{2}-\d{2}'
_CLOCK = r'\d{2}:\d{2}:\d{2}(?:\.\d+)?'
_TIME = _DATE + '_' + _CLOCK + r'_([+-]\d{4})'
_DATETIME = r'(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun),_\d{2}_(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)_\d{4}_' + _CLOCK + r'_([+-]\d{4})'
_DATE_INSPECT = r'#<Date:_' + _DATE + r'_\(\(-?\d+j,0s,0n\),\+0s,2299161j\)>'
_ARGUMENT_PREFIX = r'ArgumentSerializationTest#test_serializes_Range_-_'
ARGUMENT_CLOCK_CASES = [
    (kind, re.compile(_ARGUMENT_PREFIX + body + r'_verbatim\Z'))
    for kind, body in (('days-ago-to-date', _TIME + r'\.\.' + _DATE_INSPECT),
                       ('hours-ago-to-time', _TIME + r'\.\.' + _TIME),
                       ('weeks-ago-to-datetime', _DATETIME + r'\.\.' + _DATETIME))
]


def argument_clock_values_valid(kind, name):
    """Validate the arithmetic and rendered calendars before dropping clocks."""
    prefix = 'ArgumentSerializationTest#test_serializes_Range_-_'
    first, last = name[len(prefix):-len('_verbatim')].split('..', 1)

    def time_value(value):
        date, clock, offset = value.split('_')
        if int(offset[1:3]) > 23 or int(offset[3:]) > 59:
            raise ValueError('invalid UTC offset')
        whole, point, fraction = clock.partition('.')
        if point:
            clock = whole + '.' + fraction[:6].ljust(6, '0')
        # Older supported Python versions require a colon in the UTC offset
        # and microsecond precision. Sub-microsecond digits do not affect the
        # two-second tolerance and are never made part of an identity.
        return datetime.datetime.fromisoformat(date + 'T' + clock + offset[:3] + ':' + offset[3:])

    def datetime_value(value):
        weekday, day, month, year, clock, offset = value.split('_')
        months = ('Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec')
        stamp = time_value(f'{year}-{months.index(month)+1:02}-{day}_{clock}_{offset}')
        if weekday != ('Mon,', 'Tue,', 'Wed,', 'Thu,', 'Fri,', 'Sat,', 'Sun,')[stamp.weekday()]:
            raise ValueError('weekday disagrees with date')
        return stamp

    try:
        if kind == 'days-ago-to-date':
            start = time_value(first)
            match = re.fullmatch(r'#<Date:_(\d{4}-\d{2}-\d{2})_\(\((-?\d+)j,0s,0n\),\+0s,2299161j\)>', last)
            if not match:
                return False
            end = datetime.date.fromisoformat(match[1])
            if int(match[2]) != end.toordinal() + 1721425:
                return False
            days = (end - start.date()).days
            seconds = start.hour * 3600 + start.minute * 60 + start.second + start.microsecond / 1e6
            # The two clock reads can straddle midnight (including a small
            # clock correction). Otherwise their calendar dates differ by10.
            return days == 10 or (days == 11 and seconds >= 86400 - 2) or (days == 9 and seconds <= 2)
        parser = time_value if kind == 'hours-ago-to-time' else datetime_value
        start, end = parser(first), parser(last)
        expected = 10 * 3600 if kind == 'hours-ago-to-time' else 28 * 86400
        return abs((end - start).total_seconds() - expected) <= 2
    except (ValueError, OverflowError, IndexError):
        return False


SUMMARY = re.compile(r'^(\d+) runs, (\d+) assertions, (\d+) failures, (\d+) errors, (\d+) skips$', re.M)

# Only these unchanged tagged files legitimately contain no runnable tests.
# A missing service can also make a nonempty test file report zero runs.
EMPTY_TEST_SOURCES = {
    'actionpack/test/controller/new_base/render_xml_test.rb': (290, '6aca88be3c0886bd9fc5ae974042053d16a1148f5dbe9484f2e41d7faa0345fb'),
    'actionpack/test/journey/nodes/symbol_test.rb': (0, 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855'),
}


def sha(path):
    digest = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1 << 20), b''):
            digest.update(block)
    return digest.hexdigest()


def write_json(path, data):
    temporary = path.with_suffix('.new')
    temporary.write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n')
    temporary.replace(path)


def lock():
    data = json.loads((ROOT / 'archives.lock.json').read_text())
    for name, expected in data['inputs'].items():
        if sha(ROOT / name) != expected:
            raise ValueError('changed locked input: ' + name)
    files = [p['file'] for p in data['packages']]
    if len(set(files)) != len(files):
        raise ValueError('duplicate locked package')
    for name in files:
        if not re.fullmatch(r'[A-Za-z0-9_.+-]+\.gem', name):
            raise ValueError('invalid archive name')
    return data


def verify(archives, data):
    actual = {p.name for p in archives.iterdir()}
    expected = {p['file'] for p in data['packages']}
    if actual != expected:
        raise ValueError('archive inventory differs from lock')
    for package in data['packages']:
        if sha(archives / package['file']) != package['sha256']:
            raise ValueError('changed archive: ' + package['file'])


def restore(args, data):
    args.archives.mkdir(parents=True, exist_ok=True)
    for package in data['packages']:
        target = args.archives / package['file']
        if not target.exists():
            temporary = target.with_suffix('.part')
            with urllib.request.urlopen('https://rubygems.org/downloads/' + package['file'], timeout=60) as response:
                with temporary.open('wb') as output:
                    shutil.copyfileobj(response, output)
            if sha(temporary) != package['sha256']:
                temporary.unlink()
                raise ValueError('download checksum mismatch: ' + package['file'])
            temporary.replace(target)
    verify(args.archives, data)
    print(f"Verified {len(data['packages'])} archives.")


def clean_environment():
    env = {k: v for k, v in os.environ.items()
           if not k.startswith(('BUNDLE_', 'MERE_RUBY_', 'RBENV_', 'RAILS_'))
           and k not in ('RUBYOPT', 'RUBYLIB', 'GEM_HOME', 'GEM_PATH', 'GEMRC', 'MAKEFLAGS',
                         'RUBYGEMS_GEMDEPS', 'RACK_ENV', 'CI', 'BUILDKITE')}
    env.update(LANG='en_US.UTF-8', GEMRC=os.devnull)
    return env


def reference_facts(reference):
    query = ('require "rbconfig"; require "json"; puts JSON.generate([RUBY_VERSION, '
             'RbConfig::CONFIG["rubylibdir"], File.join(RbConfig::CONFIG["bindir"], "gem")])')
    return json.loads(subprocess.check_output([str(reference), '-e', query], text=True,
                                              env=clean_environment(), timeout=10))


def environment(side_dir, stdlib, mere=False):
    home = side_dir / 'gems'
    env = clean_environment()
    if mere:
        # The standard library mere-ruby is given, on RUBYLIB, so RubyGems sees
        # its default gem specs (see railstest/measure.py's environment).
        env['RUBYLIB'] = stdlib
    # The same bootstrap as the application measurement: each interpreter's own
    # libraries first, the reference standard library only as a fallback.
    env.update(GEM_HOME=str(home), GEM_PATH=str(home), RAILS_SMOKE_RUBY_LIB=stdlib,
               RUBYOPT='--disable-gems -r' + str(RAILSTEST / 'bootstrap.rb'),
               BUNDLE_GEMFILE=str(side_dir / 'bundle' / 'Gemfile'), BUNDLE_FROZEN='true',
               BUNDLE_IGNORE_CONFIG='true', BUNDLE_FORCE_RUBY_PLATFORM='true',
               BUNDLE_USER_HOME=str(side_dir / 'bundler-user'), TMPDIR=str(side_dir / 'tmp'))
    return env


# --env: a setting both sides get alike (activerecord's ARCONN=sqlite3), and
# the record keeps it. The record is published, so neither a secret nor a
# path of this machine may be one; and the settings the runner itself makes
# for each side (the gem home, the bootstrap, the tmp directory) are not
# overridable, nor is mere-ruby's own --mere-env.
RESERVED = ('GEM_HOME', 'GEM_PATH', 'GEMRC', 'RUBYOPT', 'RUBYLIB', 'RAILS_SMOKE_RUBY_LIB', 'TMPDIR',
            'LANG', 'PATH', 'HOME', 'MAKEFLAGS', 'RUBYGEMS_GEMDEPS')
SECRET = re.compile(r'TOKEN|SECRET|PASSW|CREDENTIAL|PRIVATE|API_?KEY|AUTH|COOKIE|SESSION')
LOCAL_PATH = re.compile(r'(?:^|[\s=:,;])[/~]|/Users/|/home/|/private/|/var/folders/')


def shared_settings(items):
    settings = {}
    for item in items:
        key, sep, value = item.partition('=')
        if not sep or not re.fullmatch(r'[A-Z][A-Z0-9_]*', key):
            raise ValueError('--env takes NAME=value with an upper-case NAME: ' + item)
        if key in RESERVED or key.startswith(('BUNDLE_', 'MERE_RUBY_')):
            raise ValueError(f'--env cannot set {key}: the runner makes it for each side'
                             + (' (use --mere-env)' if key.startswith('MERE_RUBY_') else ''))
        if SECRET.search(key):
            raise ValueError(f'--env {key}: a secret is not recorded; the results are published')
        if LOCAL_PATH.search(value):
            raise ValueError(f'--env {key}: a path of this machine is not recorded; the results are published')
        settings[key] = value
    return dict(sorted(settings.items()))


def side_environment(side_dir, stdlib, mere, shared, framework_bootstrap=False):
    """A side's environment: the runner's own, then --env's settings, which
    are the same for both sides"""
    env = environment(side_dir, stdlib, mere=mere)
    if framework_bootstrap:
        env['RUBYOPT'] = '--disable-gems -r' + str(ROOT / 'bootstrap.rb')
    env.update(shared)
    return env


def supervisor():
    sys.path.insert(0, str(REPO / 'unittest'))
    from ci import supervise
    return supervise


def capture(command, env, cwd, stem, supervise):
    stdout, stderr = stem.with_suffix('.stdout'), stem.with_suffix('.stderr')
    wrapper = ['sh', '-c', 'cd "$1" && out=$2 && err=$3 && shift 3 && exec "$@" >"$out" 2>"$err"',
               'capture', str(cwd), str(stdout), str(stderr), *map(str, command)]
    outcome = supervise(wrapper, env, stem.with_suffix('.monitor'), RSS_KB, WALL)
    return outcome, stdout, stderr


def install(args, data):
    check_source(args.source, data)
    verify(args.archives, data)
    version, stdlib, gem = reference_facts(args.reference)
    if version != data['ruby_version']:
        raise ValueError('reference Ruby version differs from lock')
    supervise = supervisor()
    sides = selected_sides(args)
    args.output.mkdir(parents=True, exist_ok=True)
    record_path = args.output / 'install.json'
    record = json.loads(record_path.read_text()) if record_path.exists() else dict(schema=1, sides={})
    record.update(ruby_version=version, rails_version=data['rails_version'],
                  archive_lock_sha256=sha(ROOT / 'archives.lock.json'), wall_seconds=WALL, family_rss_kib=RSS_KB)
    for side, binary in sides:
        side_dir = args.output / side
        if side_dir.exists():
            raise ValueError(f'{side_dir} exists; install into a fresh output directory')
        bundle, home = side_dir / 'bundle', side_dir / 'gems'
        bundle.mkdir(parents=True)
        (side_dir / 'tmp').mkdir()
        home.mkdir()
        for name in ('Gemfile', 'Gemfile.lock'):
            shutil.copy(ROOT / name, bundle / name)
        shutil.copytree(args.archives, bundle / 'vendor/cache')
        env = environment(side_dir, stdlib, mere=side == 'mere')
        if args.sqlite_prefix:
            env['BUNDLE_BUILD__SQLITE3'] = '--enable-system-libraries --with-opt-dir=' + str(args.sqlite_prefix)
        steps = [('bundler', [binary, gem, 'install', bundle / 'vendor/cache/bundler-4.0.20.gem', '--local', '--no-document'],
                  'Successfully installed bundler-4.0.20'),
                 ('dependencies', [binary, home / 'gems/bundler-4.0.20/exe/bundle', 'install', '--local', '--jobs', '1'],
                  'Bundle complete!')]
        rows = record['sides'][side] = dict(binary_sha256=sha(binary), sqlite_build='system-prefix' if args.sqlite_prefix else 'packaged')
        for stage, command, marker in steps:
            outcome, stdout, stderr = capture(command, env, bundle, side_dir / stage, supervise)
            passed = outcome['exit'] == 0 and outcome['limit'] is None and marker in stdout.read_text(errors='replace')
            rows[stage] = dict(outcome, state='PASS' if passed else 'FAIL', stdout_sha256=sha(stdout), stderr_sha256=sha(stderr))
            write_json(record_path, record)
            print(side, stage, rows[stage]['state'], outcome['seconds'], 's', outcome['peak_rss_kb'], 'KiB', flush=True)
            if not passed:
                break
        if rows.get('dependencies', {}).get('state') == 'PASS':
            rows['component_lib'] = component_lib_parity(args.source, home)
            write_json(record_path, record)
    return 0 if all(r.get('dependencies', {}).get('state') == 'PASS' for r in record['sides'].values()) else 1


def component_lib_parity(source, home):
    """The installed component gems' lib/ must be the tagged source's lib/."""
    result = {}
    for component in COMPONENTS:
        installed = home / 'gems' / f'{component}-8.1.4.1' / 'lib'
        if not installed.is_dir():
            raise ValueError(f'{component}-8.1.4.1 is not installed in {home}')
        tagged = source / component / 'lib'
        names = sorted(str(p.relative_to(tagged)) for p in tagged.rglob('*') if p.is_file())
        mine = sorted(str(p.relative_to(installed)) for p in installed.rglob('*') if p.is_file())
        differ = [n for n in names if n in mine and sha(tagged / n) != sha(installed / n)]
        result[component] = dict(files=len(names), only_source=len(set(names) - set(mine)),
                                 only_installed=len(set(mine) - set(names)), differ=len(differ))
        if result[component]['only_source'] or result[component]['only_installed'] or differ:
            raise ValueError(f'installed {component} lib differs from the tagged source: {result[component]}')
    return result


def selected_sides(args):
    sides = []
    if args.side in ('both', 'reference'):
        sides.append(('reference', args.reference))
    if args.side in ('both', 'mere'):
        if not args.binary or args.binary.with_name('.build_mode').read_text().strip() != 'O2':
            raise ValueError('--binary must name a normal O2 build with its .build_mode')
        sides.append(('mere', args.binary))
    return sides


def check_install_binary(install_record, side, binary_sha, allowed):
    """The native extensions in a gem home were built by the interpreter that
    installed them (for mere-ruby, against its C API). A run with another
    binary would measure that binary on someone else's extensions."""
    installed_by = install_record['sides'][side].get('binary_sha256')
    if installed_by != binary_sha and not allowed:
        raise ValueError(f'{side}: the binary is not the one that installed this gem home ({installed_by}); '
                         'install again, or pass --other-install-binary to record the difference')
    return installed_by == binary_sha


def check_source(source, data):
    head = subprocess.check_output(['git', '-C', str(source), 'rev-parse', 'HEAD'], text=True).strip()
    if head != data['rails_source_commit']:
        raise ValueError(f'Rails source is {head}, not the locked {data["rails_source_commit"]}')
    if subprocess.check_output(['git', '-C', str(source), 'status', '--porcelain', '--untracked-files=no'], text=True):
        raise ValueError('Rails source checkout has local changes')
    return head


def select_files(source, selections):
    files = []
    for selection in selections:
        path = source / selection
        if path.is_file():
            found = [path]
        elif path.is_dir():
            found = sorted(path.rglob('*_test.rb'))
        else:
            raise ValueError('no such test path: ' + selection)
        for item in found:
            relative = item.relative_to(source)
            if relative.parts[0] not in COMPONENTS or relative.parts[1] != 'test':
                raise ValueError('not a component test file: ' + str(relative))
            if str(relative) not in files:
                files.append(str(relative))
    if not files:
        raise ValueError('empty selection')
    return files


def reported_cases(text):
    """Verbose minitest prints a name before running a test, and its result
    afterwards. A test's logger can insert whole lines between these parts.
    Keep that explicit name pending; never assign a result without one.
    """
    pending = None
    for line in text.splitlines():
        complete = CASE.fullmatch(line)
        if complete:
            yield complete.groups()
            pending = None
        else:
            start = CASE_START.match(line)
            end = CASE_END.fullmatch(line)
            if start:
                pending = start.group(1)
            elif end and pending is not None:
                yield pending, *end.groups()
                pending = None


def parse(stdout, outcome):
    text = stdout.read_text(encoding='utf-8', errors='replace')
    cases, duplicates = {}, []
    for identity, _seconds, verdict in reported_cases(text):
        if identity in cases:
            duplicates.append(identity)
            # the worse verdict stands: a name reported F then . is not a pass
            if SEVERITY[verdict] < SEVERITY[cases[identity]]:
                verdict = cases[identity]
        cases[identity] = verdict
    summaries = SUMMARY.findall(text)
    summary = dict(zip(('runs', 'assertions', 'failures', 'errors', 'skips'), map(int, summaries[-1]))) if summaries else None
    if outcome['limit']:
        state = outcome['limit']
    elif summary is None:
        state = 'INCOMPLETE'
    elif duplicates or len(summaries) != 1 or summary['runs'] != len(cases):
        state = 'COUNT_MISMATCH'
    elif (sum(v == 'F' for v in cases.values()), sum(v == 'E' for v in cases.values()),
          sum(v == 'S' for v in cases.values())) != (summary['failures'], summary['errors'], summary['skips']):
        state = 'REPORT_MISMATCH'
    elif summary['runs'] == 0:
        state = 'ZERO'
    elif outcome['exit'] != (1 if summary['failures'] + summary['errors'] else 0):
        # minitest exits 0 or 1 by its own summary; a signal after the summary
        # (exit -11) or any other code is a crash at exit, kept visible
        state = 'EXIT_ERROR'
    else:
        state = 'COMPLETE'
    return dict(state=state, summary=summary, cases=cases, duplicates=duplicates)


# mere-ruby transcripts whose own lines and summary disagree: a `.` line there
# is not evidence of a pass
UNTRUSTED = ('COUNT_MISMATCH', 'REPORT_MISMATCH')


def case_identity_aliases(reference, mere, policy='literal', source_sha256=None):
    """Pair unique opaque class descriptions, preserving address relationships.

    Raw identities stay in the record. Incomplete inventories and ambiguous
    shapes cannot establish a pairing, even when their surviving tests pass.
    """
    if policy not in CASE_IDENTITY_POLICIES:
        raise ValueError('unknown case identity policy: ' + policy)
    if policy == 'literal' or reference['state'] != 'COMPLETE' or mere['state'] != 'COMPLETE':
        return {}

    def shape(name):
        if policy == 'rails-argument-descriptions' and source_sha256 == ARGUMENT_SOURCE_SHA256:
            for kind, pattern in ARGUMENT_CLOCK_CASES:
                match = pattern.fullmatch(name)
                if match and argument_clock_values_valid(kind, name):
                    # Preserve each endpoint's UTC offset. Only the clock's
                    # date/time text is volatile, not the test's type or form.
                    # Arithmetic, weekday and Julian-day checks above must
                    # succeed independently on each side before any pairing.
                    return (('rails-clock', kind, *match.groups()),), [], True
        pieces, addresses, slots, start = [], [], {}, 0
        for match in ANONYMOUS_CLASS.finditer(name):
            address = int(match.group(1), 16)
            pieces.extend((name[start:match.start()], slots.setdefault(address, len(slots))))
            addresses.append(address)
            start = match.end()
        pieces.append(name[start:])
        return tuple(pieces), addresses, bool(addresses)

    inventories = []
    for side in (reference, mere):
        groups = {}
        for name in side['cases']:
            key, addresses, volatile = shape(name)
            if volatile:
                groups.setdefault(key, []).append(name)
        inventories.append(groups)
    left, right = inventories
    pairs = [(name, name) for name in reference['cases'] if name in mere['cases']]
    for key, names in left.items():
        others = right.get(key, [])
        if len(names) == len(others) == 1:
            rname, mname = names[0], others[0]
            if rname not in mere['cases'] and mname not in reference['cases']:
                pairs.append((rname, mname))
    forward, backward = {}, {}
    for rname, mname in pairs:
        for raddr, maddr in zip(shape(rname)[1], shape(mname)[1]):
            forward.setdefault(raddr, set()).add(maddr)
            backward.setdefault(maddr, set()).add(raddr)
    return {mname: rname for rname, mname in pairs if rname != mname
            and all(len(forward[raddr]) == len(backward[maddr]) == 1
                    for raddr, maddr in zip(shape(rname)[1], shape(mname)[1]))}


def classify(reference, mere, identity_policy='literal', source_sha256=None):
    """Every reference test name gets one verdict; mere-only names are EXTRA."""
    aliases = case_identity_aliases(reference, mere, identity_policy, source_sha256)
    mere_cases = {aliases.get(name, name): verdict for name, verdict in mere['cases'].items()} if aliases else mere['cases']
    verdicts = {}
    untrusted = mere.get('state') in UNTRUSTED
    for name, verdict in reference['cases'].items():
        if verdict != '.':
            verdicts[name] = 'BOTH'
        elif name not in mere_cases:
            verdicts[name] = 'MISSING'
        elif mere_cases[name] == '.':
            verdicts[name] = 'UNCONFIRMED' if untrusted else 'MATCH'
        else:
            verdicts[name] = 'RED'
    for name in mere_cases:
        if name not in reference['cases']:
            verdicts[name] = 'EXTRA'
    return verdicts


def mere_settings(items):
    """--mere-env: settings for mere-ruby's side only (MERE_RUBY_VM=1 measures
    the VM instead of the evaluator), checked before anything is made"""
    settings = {}
    for item in items:
        key, sep, value = item.partition('=')
        if not sep or not key.startswith('MERE_RUBY_'):
            raise ValueError('--mere-env takes MERE_RUBY_*=value only: ' + item)
        settings[key] = value
    return settings


def run(args, data):
    mere_env = mere_settings(args.mere_env)
    shared = shared_settings(args.env)
    source_head = check_source(args.source, data)
    files = select_files(args.source, args.paths)
    sources = {name: dict(source_bytes=(args.source / name).stat().st_size,
                          source_sha256=sha(args.source / name)) for name in files}
    version, stdlib, _gem = reference_facts(args.reference)
    supervise = supervisor()
    sides = selected_sides(args)
    install_record = json.loads((args.gems / 'install.json').read_text())
    for side, binary in sides:
        if install_record['sides'].get(side, {}).get('dependencies', {}).get('state') != 'PASS':
            raise ValueError(f'{side} has no successful installation in {args.gems}')
        # The native extensions in a gem home were built by the interpreter
        # that installed them (for mere-ruby, against its C API). A run with
        # another binary measures that binary on someone else's extensions.
        check_install_binary(install_record, side, sha(binary), args.other_install_binary)
    if args.output.exists():
        raise ValueError('--output must not exist; use a fresh directory')
    args.output.mkdir(parents=True)
    trees = {}
    for side, _binary in sides:
        # A private copy of the tagged tree per side: tests write fixtures and
        # tmp files beside themselves, and the two sides run concurrently.
        tree = args.output / side / 'rails'
        tree.mkdir(parents=True)
        archive = subprocess.Popen(['git', '-C', str(args.source), 'archive', data['rails_source_commit']], stdout=subprocess.PIPE)
        subprocess.check_call(['tar', '-x', '-C', str(tree)], stdin=archive.stdout)
        if archive.wait() != 0:
            raise ValueError('git archive failed')
        (args.output / side / 'logs').mkdir()
        trees[side] = tree
    record = dict(schema=1, kind='RAILS_FRAMEWORK_TESTS', ruby_version=version, rails_version=data['rails_version'],
                  rails_source_commit=source_head,
                  source_ref=subprocess.check_output(['git', '-C', str(REPO), 'rev-parse', 'HEAD'], text=True).strip(),
                  runner_sha256=sha(Path(__file__)), archive_lock_sha256=sha(ROOT / 'archives.lock.json'),
                  framework_bootstrap=args.framework_bootstrap,
                  bootstrap_sha256=sha((ROOT if args.framework_bootstrap else RAILSTEST) / 'bootstrap.rb'),
                  binary_sha256=sha(args.binary) if args.binary else None, reference_sha256=sha(args.reference),
                  seed=SEED, wall_seconds=WALL, family_rss_kib=RSS_KB, jobs=args.jobs, env=shared,
                  install_binary_sha256={side: install_record['sides'][side].get('binary_sha256') for side, _b in sides},
                  selected_files=files, require_all_pass=args.require_all_pass, files={})
    lock_ = threading.Lock()
    record['mere_env'] = mere_env
    if getattr(args, 'case_identity_policy', 'literal') != 'literal':
        record['case_identity_policy'] = args.case_identity_policy

    def one(side, binary, name):
        component, relative = name.split('/', 1)
        side_dir = args.gems / side
        env = side_environment(side_dir, stdlib, side == 'mere', shared, args.framework_bootstrap)
        if side == 'mere':
            env.update(mere_env)
        stem = args.output / side / 'logs' / name.replace('/', '__')
        command = [binary, '-w', '-Itest', relative, '-v', '--seed', SEED]
        outcome, stdout, _stderr = capture(command, env, trees[side] / component, stem, supervise)
        parsed = parse(stdout, outcome)
        with lock_:
            entry = record['files'].setdefault(name, dict(sides={}, **sources[name]))
            entry['sides'][side] = dict(outcome, state=parsed['state'], summary=parsed['summary'],
                                        duplicates=parsed['duplicates'], cases=parsed['cases'])
            print(f"{side:9} {parsed['state']:15} {outcome['seconds']:8.1f}s {outcome['peak_rss_kb']:8} KiB  {name}", flush=True)
            write_json(args.output / 'results.json', record)

    schedule(sides, files, args.jobs, one)
    if args.binary and sha(args.binary) != record['binary_sha256']:
        raise ValueError('binary changed during the run')
    summarize(record)
    write_json(args.output / 'results.json', record)
    report(record)
    return 1 if args.require_all_pass and not all_pass(record, files) else 0


def all_pass(record, selected_files):
    """A strict gate, separate from the runner's usual measurement-only exit.

    Every selected file must finish on both sides, with the same test
    inventory and no failure, error or skip on either interpreter. Account
    separately for upstream files that define no runnable tests.
    """
    if not selected_files or set(record['files']) != set(selected_files):
        return False
    for name, entry in record['files'].items():
        if empty_entry(name, entry):
            continue
        sides = entry['sides']
        if set(sides) != {'reference', 'mere'}:
            return False
        aliases = case_identity_aliases(sides['reference'], sides['mere'],
                                       record.get('case_identity_policy', 'literal'), entry.get('source_sha256'))
        mere_names = {aliases.get(name, name) for name in sides['mere']['cases']}
        if sides['reference']['cases'].keys() != mere_names:
            return False
        for side in sides.values():
            if side['state'] != 'COMPLETE' or not side['cases']:
                return False
            if any(verdict != '.' for verdict in side['cases'].values()):
                return False
    return True


def empty_entry(name, entry):
    source = (entry.get('source_bytes'), entry.get('source_sha256'))
    if source != EMPTY_TEST_SOURCES.get(name):
        return False
    sides = entry['sides']
    if set(sides) != {'reference', 'mere'}:
        return False
    for side in sides.values():
        if side['cases'] or side.get('exit', 0) != 0 or side.get('limit'):
            return False
        if side['state'] == 'ZERO' and side['summary'] == dict(runs=0, assertions=0, failures=0, errors=0, skips=0):
            continue
        if entry.get('source_bytes') == 0 and side['state'] == 'INCOMPLETE' and side['summary'] is None:
            continue
        return False
    return True


def schedule(sides, files, jobs, one):
    """Each side runs its files one after another: the files of one side share
    its tree copy, gem home and TMPDIR (activerecord's sqlite3 tests share a
    fixture database), so two of them must never overlap. jobs 2 runs the two
    SIDES at once; jobs 1 runs everything in sequence."""
    def side_queue(side, binary):
        for name in files:
            one(side, binary, name)

    if jobs == 1:
        for side, binary in sides:
            side_queue(side, binary)
    else:
        with concurrent.futures.ThreadPoolExecutor(max_workers=len(sides)) as pool:
            for future in [pool.submit(side_queue, side, binary) for side, binary in sides]:
                future.result()


def summarize(record):
    totals = {}
    for name, entry in record['files'].items():
        sides = entry['sides']
        if 'reference' not in sides or 'mere' not in sides:
            continue
        reference, mere = sides['reference'], sides['mere']
        policy = record.get('case_identity_policy', 'literal')
        aliases = case_identity_aliases(reference, mere, policy, entry.get('source_sha256'))
        if policy != 'literal':
            entry['case_identity_aliases'] = aliases
        if empty_entry(name, entry):
            entry['verdict'] = 'EMPTY'
            verdicts = {}
        elif reference['state'] != 'COMPLETE':
            # Without a healthy reference there is nothing to compare against.
            entry['verdict'] = 'REFERENCE_' + reference['state']
            verdicts = {}
        else:
            verdicts = classify(reference, mere, policy, entry.get('source_sha256'))
            entry['verdict'] = 'COMPARED'
        # Did both sides run the common tests in the same order? (the same
        # --seed is not enough: a library that draws random numbers between
        # the shuffle's draws changes it). A result that may depend on order
        # is then visible.
        mere_order = [aliases.get(name, name) for name in mere['cases']]
        common = set(reference['cases']) & set(mere_order)
        entry['same_order'] = ([n for n in reference['cases'] if n in common]
                               == [n for n in mere_order if n in common])
        counts = {k: sum(v == k for v in verdicts.values()) for k in VERDICTS}
        entry.update(counts=counts, red=sorted(n for n, v in verdicts.items() if v == 'RED'),
                     missing=sorted(n for n, v in verdicts.items() if v == 'MISSING'),
                     unconfirmed=sorted(n for n, v in verdicts.items() if v == 'UNCONFIRMED'),
                     extra=sorted(n for n, v in verdicts.items() if v == 'EXTRA'))
        component = name.split('/', 1)[0]
        row = totals.setdefault(component, dict(files=0, empty_files=0, reference_unusable=0, mere_incomplete=0, order_differs=0,
                                                **{k: 0 for k in VERDICTS}))
        row['files'] += 1
        row['empty_files'] += entry['verdict'] == 'EMPTY'
        row['reference_unusable'] += entry['verdict'] not in ('COMPARED', 'EMPTY')
        row['mere_incomplete'] += entry['verdict'] == 'COMPARED' and mere['state'] != 'COMPLETE'
        row['order_differs'] += entry['verdict'] == 'COMPARED' and not entry['same_order']
        for key, value in counts.items():
            row[key] += value
    record['components'] = totals


def report(record):
    print(f"{'component':14} {'files':>5} {'empty':>5} {'refbad':>6} {'mere!':>5} {'order':>5} {'MATCH':>6} {'RED':>5} {'MISS':>5} {'UNCF':>5} {'BOTH':>5} {'EXTRA':>5}")
    for component, row in record.get('components', {}).items():
        print(f"{component:14} {row['files']:5} {row.get('empty_files', 0):5} {row['reference_unusable']:6} {row['mere_incomplete']:5} {row['order_differs']:5} "
              f"{row['MATCH']:6} {row['RED']:5} {row['MISSING']:5} {row['UNCONFIRMED']:5} {row['BOTH']:5} {row['EXTRA']:5}")


def compare(args):
    old = json.loads(args.base.read_text())
    new = json.loads(args.new.read_text())
    policy = old.get('case_identity_policy', 'literal')
    if policy not in CASE_IDENTITY_POLICIES or policy != new.get('case_identity_policy', 'literal'):
        raise ValueError('compare requires the same supported case identity policy in both records')
    worse = 0
    for name in sorted(set(old['files']) | set(new['files'])):
        a, b = old['files'].get(name), new['files'].get(name)
        before, after = (classify_entry(a, policy) if a else {}), (classify_entry(b, policy) if b else {})
        if policy != 'literal' and a and b and 'reference' in a['sides'] and 'reference' in b['sides']:
            source_sha = a.get('source_sha256') if a.get('source_sha256') == b.get('source_sha256') else None
            aliases = case_identity_aliases(a['sides']['reference'], b['sides']['reference'], policy, source_sha)
            # An EXTRA with the old spelling must not collide with a mapped test.
            aliases = {key: value for key, value in aliases.items() if value not in after}
            after = {aliases.get(key, key): value for key, value in after.items()}
        lost = sorted(n for n, v in before.items() if v == 'MATCH' and after.get(n) != 'MATCH')
        gained = sorted(n for n, v in after.items() if v == 'MATCH' and before.get(n) != 'MATCH')
        if not (a and b and 'counts' in a and 'counts' in b):
            # a file (or its mere-ruby side) gone from the new record loses
            # every MATCH it had; one that is new gains its own
            print(f"{name}: only in the {'base' if a else 'new'} record, or not compared in one of them"
                  + (f" ({len(lost)} MATCH lost)" if lost else ""))
        elif lost or gained or a['counts'] != b['counts']:
            print(f"{name}: MATCH {a['counts']['MATCH']} -> {b['counts']['MATCH']}, RED {a['counts']['RED']} -> {b['counts']['RED']}, "
                  f"MISSING {a['counts']['MISSING']} -> {b['counts']['MISSING']}")
            for n in lost:
                print('   lost', n)
            for n in gained:
                print('   gained', n)
        worse += len(lost)
    return 1 if worse else 0


def classify_entry(entry, identity_policy='literal'):
    sides = entry['sides']
    if entry.get('verdict') != 'COMPARED' or 'mere' not in sides or 'reference' not in sides:
        return {}
    return classify(sides['reference'], sides['mere'], identity_policy, entry.get('source_sha256'))


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('command', choices=('restore', 'install', 'run', 'compare'))
    parser.add_argument('paths', nargs='*', help='run: test files or directories, relative to --source')
    parser.add_argument('--archives', type=Path)
    parser.add_argument('--reference', type=Path)
    parser.add_argument('--binary', type=Path)
    parser.add_argument('--source', type=Path, help='a checkout of the locked Rails commit')
    parser.add_argument('--gems', type=Path, help='run: the install output directory')
    parser.add_argument('--output', type=Path)
    parser.add_argument('--side', choices=('both', 'reference', 'mere'), default='both')
    parser.add_argument('--sqlite-prefix', type=Path)
    parser.add_argument('--jobs', type=int, default=MAX_JOBS)
    parser.add_argument('--env', action='append', default=[], metavar='NAME=VALUE',
                        help='run: a setting both sides get alike (repeatable; recorded in the results)')
    parser.add_argument('--mere-env', action='append', default=[], metavar='MERE_RUBY_X=V',
                        help='run: a setting for mere-ruby only (repeatable; recorded in the results)')
    parser.add_argument('--other-install-binary', action='store_true',
                        help='run: allow a binary other than the one that installed --gems (recorded in the results)')
    parser.add_argument('--framework-bootstrap', action='store_true',
                        help='run: restore bundled_gems, did_you_mean and error_highlight startup (recorded)')
    parser.add_argument('--case-identity-policy', choices=CASE_IDENTITY_POLICIES, default='literal',
                        help='run: opt into named description pairing; original names and aliases are retained')
    parser.add_argument('--require-all-pass', action='store_true',
                        help='run: exit 1 unless every selected file completes on both sides with all tests passing')
    parser.add_argument('--base', type=Path)
    parser.add_argument('--new', type=Path)
    args = parser.parse_intermixed_args()
    if args.command != 'run' and args.case_identity_policy != 'literal':
        parser.error('--case-identity-policy is only used by run')
    for key in ('archives', 'reference', 'binary', 'source', 'gems', 'output', 'sqlite_prefix', 'base', 'new'):
        if getattr(args, key) is not None:
            setattr(args, key, getattr(args, key).resolve())
    if not 1 <= args.jobs <= MAX_JOBS:
        parser.error(f'--jobs must be 1..{MAX_JOBS}: the machine is shared')
    if args.framework_bootstrap and args.command != 'run':
        parser.error('--framework-bootstrap requires run')
    if args.require_all_pass and (args.command != 'run' or args.side != 'both'):
        parser.error('--require-all-pass requires run --side both')
    if args.command == 'compare':
        if not (args.base and args.new):
            parser.error('compare requires --base and --new')
        return compare(args)
    data = lock()
    if args.command == 'restore':
        if not args.archives:
            parser.error('restore requires --archives')
        restore(args, data)
        return 0
    if args.command == 'install':
        if not all((args.archives, args.reference, args.output, args.source)):
            parser.error('install requires --archives, --reference, --source and --output')
        return install(args, data)
    if not all((args.reference, args.source, args.gems, args.output, args.paths)):
        parser.error('run requires --reference, --source, --gems, --output and paths')
    return run(args, data)


if __name__ == '__main__':
    sys.exit(main())

#!/usr/bin/env python3
"""Restore locked Rails archives, or measure a real app on two interpreters."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import urllib.request

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parent
REPO = ROOT.parent
WALL = 600
RSS_KB = 2 * 1024 * 1024
STAGES = ('bundler', 'dependencies', 'migration', 'boot', 'tests', 'http')
TESTS = {
    'NoteTest#test_create_read_update_delete',
    'NoteTest#test_validation_and_callback',
    'NoteTest#test_fixtures_and_model_autoload',
    'NoteTest#test_transaction_rollback',
    'NotesTest#test_routing_erb_and_html_escaping',
    'NotesTest#test_http_create_cookie_session_update_and_delete',
}


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def fixture_hash():
    digest = hashlib.sha256()
    for path in sorted((ROOT / 'app').rglob('*')):
        if path.is_file():
            digest.update(str(path.relative_to(ROOT / 'app')).encode() + b'\0')
            digest.update(path.read_bytes() + b'\0')
    return digest.hexdigest()


def write_json(path, data):
    temporary = path.with_suffix('.new')
    temporary.write_text(json.dumps(data, indent=2) + '\n')
    temporary.replace(path)


def lock():
    data = json.loads((ROOT / 'archives.lock.json').read_text())
    for name, expected in data['inputs'].items():
        if sha(ROOT / 'app' / name) != expected:
            raise ValueError('changed locked input: ' + name)
    if len({p['file'] for p in data['packages']}) != len(data['packages']):
        raise ValueError('duplicate locked package')
    for package in data['packages']:
        if not re.fullmatch(r'[A-Za-z0-9_.+-]+\.gem', package['file']):
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
    print(f"Verified {len(data['packages'])} source archives; no extensions are shared.")


def clean_environment():
    env = {k: v for k, v in os.environ.items()
           if not k.startswith(('BUNDLE_', 'MERE_RUBY_', 'RBENV_'))
           and k not in ('RUBYOPT', 'RUBYLIB', 'GEM_HOME', 'GEM_PATH', 'GEMRC',
                         'MAKEFLAGS', 'RUBYGEMS_GEMDEPS', 'RAILS_ENV', 'RACK_ENV')}
    env.update(LANG='en_US.UTF-8', GEMRC=os.devnull)
    return env


def mere_settings(pairs):
    """--mere-env NAME=VALUE: a setting of mere-ruby's own for its side only
    (MERE_RUBY_VM=1 runs each file on the ISeq VM). clean_environment drops
    every inherited MERE_RUBY_ name; these are the ones the run asks for,
    and the result records them."""
    out = {}
    for pair in pairs or []:
        name, sep, value = pair.partition('=')
        if not sep or not name.startswith('MERE_RUBY_') or not value:
            raise ValueError('--mere-env takes MERE_RUBY_<NAME>=<value>: ' + pair)
        out[name] = value
    return out


def environment(home, app, stdlib, user, sqlite_prefix, mere=False, settings=None):
    env = clean_environment()
    if mere:
        env.update(settings or {})
        # mere-ruby takes the standard library it is given on RUBYLIB, and a
        # `<x>/lib/ruby/4.0.0` there with gems/4.0.0/specifications/default
        # beside it names the tree whose DEFAULT gem specs RubyGems sees (its
        # rubylibprefix; no other RbConfig path changes). Without them Bundler
        # was not activated as a gem: a direct `bin/rails` read bundler.rb from
        # the fallback library and the boot audit found no installed Bundler.
        # The reference has its own library and specs; RUBYLIB there would put
        # its library first and select its default Bundler instead.
        env['RUBYLIB'] = stdlib
    env.update(LANG='en_US.UTF-8', GEM_HOME=str(home), GEM_PATH=str(home),
               GEMRC=os.devnull, RAILS_SMOKE_RUBY_LIB=stdlib, RAILS_ENV='test',
               RUBYOPT='--disable-gems -r' + str(ROOT / 'bootstrap.rb'),
               BUNDLE_GEMFILE=str(app / 'Gemfile'), BUNDLE_FROZEN='true',
               BUNDLE_IGNORE_CONFIG='true', BUNDLE_FORCE_RUBY_PLATFORM='true',
               BUNDLE_USER_HOME=str(user), RAILS_SMOKE_GEM_HOME=str(home),
               RAILS_SMOKE_LOCK=str(ROOT / 'archives.lock.json'))
    if sqlite_prefix:
        env['BUNDLE_BUILD__SQLITE3'] = '--enable-system-libraries --with-opt-dir=' + str(sqlite_prefix)
    return env


def successful(stage, outcome, stdout):
    if outcome['exit'] != 0 or outcome['limit'] is not None:
        return False
    if stage == 'tests':
        summary = re.search(r'^(\d+) runs, (\d+) assertions, (\d+) failures, (\d+) errors, (\d+) skips$', stdout, re.M)
        names = re.findall(r'^((?:NoteTest|NotesTest)#test_\S+) = ', stdout, re.M)
        return bool(summary and tuple(map(int, summary.groups())) == (6, 31, 0, 0, 0)
                    and len(names) == len(TESTS) and set(names) == TESTS)
    markers = {'bundler': 'Successfully installed bundler-4.0.20',
               'dependencies': 'Bundle complete!',
               'migration': 'CreateNotes: migrated',
               'boot': 'rails-boot-ok', 'http': 'puma-http-ok'}
    return markers[stage] in stdout


def measure(args, data):
    verify(args.archives, data)
    if args.output.exists():
        raise ValueError('--output must not exist; use a fresh directory')
    query = 'require "rbconfig"; require "json"; puts JSON.generate([RUBY_VERSION, RbConfig::CONFIG["rubylibdir"], File.join(RbConfig::CONFIG["bindir"], "gem")])'
    version, stdlib, gem = json.loads(subprocess.check_output(
        [str(args.reference), '-e', query], text=True, env=clean_environment(), timeout=10))
    if version != data['ruby_version']:
        raise ValueError('reference Ruby version differs from lock')
    if not args.binary.is_file() or args.binary.with_name('.build_mode').read_text().strip() != 'O2':
        raise ValueError('--binary must name a normal O2 build with its .build_mode')
    settings = mere_settings(args.mere_env)
    sys.path.insert(0, str(REPO / 'unittest'))
    from ci import supervise
    args.output.mkdir(parents=True)
    record = dict(schema=1, ruby_version=version, rails_version=data['rails_version'],
                  source_ref=subprocess.check_output(['git', '-C', str(REPO), 'rev-parse', 'HEAD'], text=True).strip(),
                  binary_sha256=sha(args.binary), reference_sha256=sha(args.reference),
                  archive_lock_sha256=sha(ROOT / 'archives.lock.json'), fixture_sha256=fixture_hash(),
                  runner_sha256=sha(ROOT / 'measure.py'), bootstrap_sha256=sha(ROOT / 'bootstrap.rb'),
                  wall_seconds=WALL, family_rss_kib=RSS_KB,
                  sqlite_build='system-prefix' if args.sqlite_prefix else 'packaged',
                  mere_env=settings, sides={})
    for side, binary in [('reference', args.reference), ('mere', args.binary)]:
        work = args.output / side
        app, home = work / 'app', work / 'gems'
        shutil.copytree(ROOT / 'app', app)
        for directory in ('storage', 'tmp', 'log'):
            (app / directory).mkdir(exist_ok=True)
        shutil.copytree(args.archives, app / 'vendor/cache')
        home.mkdir()
        env = environment(home, app, stdlib, work / 'bundler-user', args.sqlite_prefix, mere=side == 'mere',
                          settings=settings)
        commands = [
            [binary, gem, 'install', app / 'vendor/cache/bundler-4.0.20.gem', '--local', '--no-document'],
            [binary, home / 'gems/bundler-4.0.20/exe/bundle', 'install', '--local', '--jobs', '1'],
            [binary, 'bin/rails', 'db:migrate'],
            [binary, 'bin/rails', 'runner', 'script/boot.rb'],
            [binary, 'bin/rails', 'test', '-v', '--seed', '12345'],
            [binary, 'bin/rails', 'runner', 'script/http.rb'],
        ]
        rows = record['sides'][side] = {}
        blocked = False
        for stage, command in zip(STAGES, commands):
            if blocked:
                rows[stage] = dict(state='NOT_RUN', reason='preceding stage failed')
            else:
                stdout, stderr = work / (stage + '.stdout'), work / (stage + '.stderr')
                capture = ['sh', '-c', 'out=$1; err=$2; shift 2; exec "$@" >"$out" 2>"$err"',
                           'capture', str(stdout), str(stderr), *map(str, command)]
                previous = Path.cwd()
                try:
                    os.chdir(app)
                    outcome = supervise(capture, env, work / (stage + '.monitor'), RSS_KB, WALL)
                finally:
                    os.chdir(previous)
                passed = successful(stage, outcome, stdout.read_text(errors='replace'))
                rows[stage] = dict(outcome, state='PASS' if passed else 'FAIL',
                                   stdout=str(stdout.relative_to(args.output)), stderr=str(stderr.relative_to(args.output)),
                                   stdout_sha256=sha(stdout), stderr_sha256=sha(stderr))
                blocked = not passed
            write_json(args.output / 'results.json', record)
            print(side, stage, rows[stage]['state'], flush=True)
        if side == 'reference' and blocked:
            record['state'] = 'REFERENCE_UNAVAILABLE'
            write_json(args.output / 'results.json', record)
            return 2
    verify(args.archives, data)
    if (fixture_hash() != record['fixture_sha256'] or sha(args.binary) != record['binary_sha256']
            or sha(args.reference) != record['reference_sha256']
            or sha(ROOT / 'archives.lock.json') != record['archive_lock_sha256']
            or sha(ROOT / 'measure.py') != record['runner_sha256']
            or sha(ROOT / 'bootstrap.rb') != record['bootstrap_sha256']):
        raise ValueError('measurement input changed during run')
    record['state'] = 'MATCH' if all(r['state'] == 'PASS' for rows in record['sides'].values() for r in rows.values()) else 'RED'
    write_json(args.output / 'results.json', record)
    return 0 if record['state'] == 'MATCH' else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=('restore', 'measure'))
    parser.add_argument('--archives', type=Path, required=True)
    parser.add_argument('--reference', type=Path)
    parser.add_argument('--binary', type=Path)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--sqlite-prefix', type=Path)
    parser.add_argument('--mere-env', action='append', metavar='MERE_RUBY_NAME=VALUE')
    args = parser.parse_args()
    for key in ('archives', 'reference', 'binary', 'output', 'sqlite_prefix'):
        if getattr(args, key) is not None:
            setattr(args, key, getattr(args, key).resolve())
    data = lock()
    if args.command == 'restore':
        restore(args, data)
        return 0
    if not all((args.reference, args.binary, args.output)):
        parser.error('measure requires --reference, --binary and --output')
    return measure(args, data)


if __name__ == '__main__':
    sys.exit(main())

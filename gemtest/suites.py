#!/usr/bin/env python3
"""Restore pinned upstream sources, then measure each original gem test file offline."""
import argparse
from collections import Counter
import hashlib
import json
import os
import platform
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'unittest'))
from ci import supervise

WALL = 600
RSS_KB = 2097152
TALLY = re.compile(r'(\d+) (?:runs|tests), (\d+) assertions, (\d+) failures, (\d+) errors, (\d+) skips')
TEST_UNIT_TALLY = re.compile(r'(\d+) tests, (\d+) assertions, (\d+) failures, (\d+) errors,\s*'
                             r'(\d+) pendings, (\d+) omissions, (\d+) notifications')
ANSI = re.compile(r'\x1b\[[0-9;]*m')


def sha(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def tree(path):
    """Include untracked additions too: they can shadow a locked library."""
    digest = hashlib.sha256()
    for file in sorted(path.rglob('*')):
        relative = file.relative_to(path)
        if '.git' in relative.parts:
            continue
        if file.is_symlink():
            raise ValueError(f'symlink in source tree: {relative}')
        if file.is_file():
            digest.update(relative.as_posix().encode() + b'\0' + file.read_bytes() + b'\0')
    return digest.hexdigest()


def save(path, value):
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + '\n')


def call(command, **kwargs):
    return subprocess.check_output(command, text=True, env=dict(os.environ, LANG='en_US.UTF-8'), **kwargs).strip()


def verify(cache, lock):
    for source in lock['sources']:
        path = cache / source['name']
        if tree(path) != source['tree_sha256']:
            raise ValueError(f"source missing or changed: {source['name']}")
    for package in lock['packages']:
        path = cache / 'packages' / f"{package['name']}-{package['version']}.gem"
        if not path.is_file() or sha(path) != package['sha256']:
            raise ValueError(f"package missing or changed: {package['name']}")
        if tree(cache / 'home/gems' / f"{package['name']}-{package['version']}") != package['tree_sha256']:
            raise ValueError(f"installed package changed: {package['name']}")
    home = cache / 'home'
    if {p.name for p in (home / 'gems').iterdir()} != {f"{p['name']}-{p['version']}" for p in lock['packages']}:
        raise ValueError('installed dependency inventory differs from lock')
    receipt = cache / 'home.sha256'
    if not receipt.is_file() or tree(home) != receipt.read_text().strip():
        raise ValueError('installed dependency tree changed; restore into a fresh cache')


def restore(args, lock):
    cache = args.cache
    cache.mkdir(parents=True, exist_ok=True)
    for source in lock['sources']:
        path = cache / source['name']
        if not path.exists():
            subprocess.run(['git', 'init', '-q', str(path)], check=True)
            subprocess.run(['git', '-C', str(path), 'fetch', '--depth=1', source['url'], source['sha']], check=True)
            subprocess.run(['git', '-C', str(path), 'checkout', '--detach', '-q', 'FETCH_HEAD'], check=True)
        if tree(path) != source['tree_sha256']:
            raise ValueError(f"source digest mismatch: {source['name']}")
    archives = cache / 'packages'
    archives.mkdir(exist_ok=True)
    for package in lock['packages']:
        path = archives / f"{package['name']}-{package['version']}.gem"
        if not path.exists():
            with urllib.request.urlopen(package['url'], timeout=60) as response:
                data = response.read()
            if hashlib.sha256(data).hexdigest() != package['sha256']:
                raise ValueError(f"archive digest mismatch: {package['name']}")
            path.write_bytes(data)
        if sha(path) != package['sha256']:
            raise ValueError(f"archive digest mismatch: {package['name']}")
    home = cache / 'home'
    if not home.exists():
        # Gem::Package validates the actual specs and dependency closure before
        # installing. No resolver, extension build, or implicit download runs.
        script = r'''
require 'rubygems/package'
require 'fileutils'
packages = ARGV.drop(1).map { |file| Gem::Package.new(file) }
specs = packages.map(&:spec)
specs.each do |spec|
  abort "native dependency: #{spec.name}" unless spec.extensions.empty? && spec.platform == Gem::Platform::RUBY
  spec.runtime_dependencies.each do |dep|
    abort "unlocked dependency: #{dep}" unless specs.any? { |s| s.name == dep.name && dep.requirement.satisfied_by?(s.version) }
  end
end
packages.each do |package|
  spec = package.spec
  package.extract_files(File.join(ARGV[0], 'gems', spec.full_name))
  Dir.mkdir(File.join(ARGV[0], 'specifications')) unless Dir.exist?(File.join(ARGV[0], 'specifications'))
  File.write(File.join(ARGV[0], 'specifications', "#{spec.full_name}.gemspec"), spec.to_ruby)
end
'''
        with tempfile.TemporaryDirectory(prefix='home-', dir=cache) as staging:
            staged = Path(staging) / 'home'
            staged.mkdir()
            subprocess.run([str(args.reference), '--disable-gems', '-rrubygems', '-e', script, str(staged)] +
                           [str(archives / f"{p['name']}-{p['version']}.gem") for p in lock['packages']], check=True)
            staged.rename(home)
        (cache / 'home.sha256').write_text(tree(home) + '\n')
    verify(cache, lock)
    print('Verified all locked sources and pure Ruby dependencies.')


def tally(stdout, stderr, framework=None):
    text = ANSI.sub('', stdout + '\n' + stderr)
    if framework == 'test-unit-gem':
        found = TEST_UNIT_TALLY.findall(text)
        if not found:
            return None
        counts = dict(zip(('tests', 'assertions', 'failures', 'errors', 'pendings', 'omissions', 'notifications'),
                          map(int, found[-1])))
        counts['skips'] = counts['pendings'] + counts['omissions']
        return counts
    found = TALLY.findall(text)
    return dict(zip(('tests', 'assertions', 'failures', 'errors', 'skips'), map(int, found[-1]))) if found else None


def healthy(side):
    counts = side['tally']
    return (side['exit'] == 0 and side['limit'] is None and side.get('source_verified', True) and counts is not None
            and counts['tests'] > counts['skips'] and counts['assertions'] > 0
            and counts['failures'] == counts['errors'] == 0)


def verdict(reference, mere):
    limits = {reference['limit'], mere['limit']}
    if 'MEMORY_LIMIT' in limits:
        return 'MEMORY'
    if 'WALL_LIMIT' in limits:
        return 'TIMEOUT'
    if not healthy(reference):
        return 'BOTH'
    if healthy(mere) and reference['tally'] == mere['tally']:
        return 'MATCH'
    return 'RED'


# Keep separate byte streams while reusing CI's process-family bounds and cleanup.
EXEC = '''import os,sys
os.chdir(sys.argv[1])
for fd,path in ((1,sys.argv[2]),(2,sys.argv[3])):
    stream=os.open(path,os.O_WRONLY|os.O_CREAT|os.O_TRUNC,0o600)
    os.dup2(stream,fd)
os.execve(sys.argv[4],sys.argv[4:],os.environ)
'''


def run_side(args, suite, file, side, env, output, lock):
    with tempfile.TemporaryDirectory(prefix='gem-suite-') as temporary:
        scratch = Path(temporary)
        for name in suite['load_sources']:
            shutil.copytree(args.cache / name, scratch / name, ignore=shutil.ignore_patterns('.git'))
        source = scratch / suite['name']
        libraries = [source / directory for directory in suite['load_paths']]
        libraries += [scratch / name / 'lib' for name in suite['load_sources'] if name != suite['name']]
        if suite.get('framework') == 'cruby-test-unit':
            libraries += [args.ruby_src / 'tool/lib']
        if suite.get('framework') == 'test-unit-gem':
            libraries += [args.cache / 'home/gems' / f"{p['name']}-{p['version']}" / 'lib' for p in lock['packages']]
        binary = args.reference if side == 'reference' else args.binary
        command = [str(binary), '--disable-gems', '-I', os.pathsep.join(map(str, libraries)),
                   '-r', str(ROOT / 'gemtest/suite_bootstrap.rb'), '-r', 'rubygems']
        for preload in suite.get('preload', []):
            command += ['-r', str(source / preload)]
        command += [file]
        command += ['--order=alphabetic'] if suite.get('framework') == 'test-unit-gem' else ['--seed', '1']
        if args.verbose:
            command += ['--verbose']
        stdout = output / (side + '.stdout')
        stderr = output / (side + '.stderr')
        source_record = output / (side + '.source.txt')
        side_env = dict(env, MERE_SUITE_RUBY_LIB=str(args.ruby_src / 'lib'),
                        MERE_SUITE_SOURCE_ROOT=str(source), MERE_SUITE_SOURCE_RECORD=str(source_record),
                        RUBY=str(binary), UNITTEST_CHILD_RUBY=str(binary),
                        RUBYLIB=os.pathsep.join(map(str, libraries + args.runtime_paths[side] + [args.ruby_src / 'lib'])),
                        PATH=str(ROOT / 'unittest/child-bin') + os.pathsep + env.get('PATH', os.defpath))
        result = supervise([sys.executable, '-c', EXEC, str(source), str(stdout), str(stderr)] + command,
                           side_env, output / (side + '.monitor'), RSS_KB, WALL)
        result['source_files'] = [line for line in source_record.read_text().splitlines() if line] if source_record.exists() else []
        result['source_verified'] = bool(result['source_files'])
        result['source_record'] = source_record.name
        result['tally'] = tally(stdout.read_text(errors='replace'), stderr.read_text(errors='replace'), suite.get('framework'))
        result['stdout'] = stdout.name
        result['stderr'] = stderr.name
        # Raw logs stay in the run directory; portable records contain no paths.
        result['stdout_sha256'] = sha(stdout)
        result['stderr_sha256'] = sha(stderr)
        return result


def compare(rows, baseline, same_platform=True):
    prior = {(row['gem'], row['file']): row for row in baseline['rows']}
    current = {(row['gem'], row['file']): row for row in rows}
    errors = []
    if set(current) != set(prior):
        errors.append('test file inventory changed')
    for key, old in prior.items():
        new = current.get(key)
        if new is None:
            continue
        if old['classification'] == 'MATCH' and new['classification'] != 'MATCH':
            errors.append(f'{key}: MATCH regressed to {new["classification"]}')
        # Reference regressions must not hide a new mere-ruby failure as BOTH.
        if healthy(old['reference']) and (not healthy(new['reference']) or
                (same_platform and old['reference']['tally'] != new['reference']['tally'])):
            errors.append(f'{key}: reference coverage changed')
    return errors


def baseline_errors(result, baseline, lock=None):
    if baseline['lock_sha256'] != result['lock_sha256']:
        # A reference upgrade keeps every gem source, package digest, test file
        # and command unchanged. Reconstruct the old lock and verify its exact
        # digest before comparing the historical results; never relabel them.
        previous = dict(lock or {})
        previous.update(ruby_version='4.0.9',
                        ruby_source_sha='3e93b23afcec3433f6aecc34b5d832799d754238')
        previous_digest = hashlib.sha256((json.dumps(previous, indent=2) + '\n').encode()).hexdigest()
        if (previous.get('schema') != 1
                or not lock or lock.get('ruby_version') != '4.0.10'
                or lock.get('ruby_source_sha') != 'a704b7cd95a42cc0cf5f307137bf3aac0285b915'
                or result.get('reference_version') != '4.0.10'
                or baseline.get('reference_version') != '4.0.9'
                or previous_digest != baseline['lock_sha256']):
            raise ValueError('baseline lock differs')
    if baseline['platform'] != result['platform']:
        raise ValueError('baseline platform differs; select the matching platform snapshot')
    return compare(result['rows'], baseline)


def measure(args, lock):
    verify(args.cache, lock)
    if call([str(args.reference), '--disable-gems', '-e', 'print RUBY_VERSION']) != lock['ruby_version']:
        raise ValueError('reference version differs from lock')
    if call(['git', '-C', str(args.ruby_src), 'rev-parse', 'HEAD']) != lock['ruby_source_sha']:
        raise ValueError('Ruby source revision differs from lock')
    subprocess.run(['git', '-C', str(args.ruby_src), 'diff', '--exit-code', 'HEAD', '--', 'lib'], check=True, stdout=subprocess.DEVNULL)
    if (ROOT / '.build_mode').read_text().strip() != 'O2':
        raise ValueError('measurement requires an O2 build')
    args.runtime_paths = {
        side: call(['sh', str(ROOT / 'tools/runtime_load_path.sh'), str(binary)], timeout=20).split(os.pathsep)
        for side, binary in [('reference', args.reference), ('mere', args.binary)]
    }
    args.output.mkdir(parents=True, exist_ok=False)
    env = {key: value for key, value in os.environ.items()
           if not key.startswith(('RUBY', 'GEM_', 'BUNDLE_', 'MERE_', 'MT_')) and key not in ('COVERAGE', 'SEPARATE')}
    env.update(LANG='en_US.UTF-8', GEM_HOME=str(args.cache / 'home'), GEM_PATH=str(args.cache / 'home'),
               MERE_RUBY_NO_GEMS='1', MT_NO_PLUGINS='1', NO_COLOR='1', TERM='dumb')
    rows = []
    result = dict(schema=1, platform=platform.system(), lock_sha256=sha(args.lock), source_sha=call(['git', '-C', str(ROOT), 'rev-parse', 'HEAD']),
                  binary_sha256=sha(args.binary), reference_version=lock['ruby_version'],
                  limits=dict(wall_seconds=WALL, rss_kb=RSS_KB), rows=rows)
    for suite in lock['suites']:
        if args.gem and suite['name'] not in args.gem:
            continue
        for file in suite['files']:
            if args.file and file not in args.file:
                continue
            output = args.output / suite['name'] / file
            output.mkdir(parents=True)
            row = dict(gem=suite['name'], version=suite['version'], file=file)
            for side in ('reference', 'mere'):
                row[side] = run_side(args, suite, file, side, env, output, lock)
            row['classification'] = verdict(row['reference'], row['mere'])
            rows.append(row)
            result['summary'] = {name: dict(Counter(r['classification'] for r in rows if r['gem'] == name))
                                 for name in sorted({r['gem'] for r in rows})}
            save(args.output / 'results.json', result)
            print(suite['name'], file, row['classification'], row['reference']['tally'], row['mere']['tally'], flush=True)
    if not rows:
        raise ValueError('no test files selected')
    verify(args.cache, lock)
    if sha(args.binary) != result['binary_sha256'] or sha(args.lock) != result['lock_sha256']:
        raise ValueError('binary or lock changed during measurement; discard this run')
    if args.baseline:
        baseline = json.loads(args.baseline.read_text())
        errors = baseline_errors(result, baseline, lock)
        result['regressions'] = errors
        save(args.output / 'results.json', result)
        if errors:
            raise ValueError('\n'.join(errors))
    print(json.dumps(result['summary'], sort_keys=True))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('restore', 'measure'))
    parser.add_argument('--lock', type=Path, default=ROOT / 'gemtest/suites.lock.json')
    parser.add_argument('--cache', type=Path, required=True)
    parser.add_argument('--reference', type=Path, required=True)
    parser.add_argument('--binary', type=Path, default=ROOT / 'mere-ruby')
    parser.add_argument('--ruby-src', type=Path)
    parser.add_argument('--output', type=Path)
    parser.add_argument('--gem', action='append')
    parser.add_argument('--file', action='append')
    parser.add_argument('--baseline', type=Path)
    parser.add_argument('--verbose', action='store_true', help='ask the upstream runner to name each test')
    args = parser.parse_args()
    for key in ('lock', 'cache', 'reference', 'binary', 'ruby_src', 'output', 'baseline'):
        value = getattr(args, key)
        if value is not None:
            setattr(args, key, value.resolve())
    lock = json.loads(args.lock.read_text())
    if args.action == 'restore':
        restore(args, lock)
    else:
        if args.output is None or args.ruby_src is None:
            parser.error('measure requires --output and --ruby-src')
        measure(args, lock)


if __name__ == '__main__':
    main()

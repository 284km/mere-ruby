#!/usr/bin/env python3
"""Check dependency setup with an unavailable unrelated apt repository."""
import json
import os
import shutil
import sys
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'tools/linux_build_deps.sh'


class LinuxBuildDependencies(unittest.TestCase):
    def run_setup(self, *args, **settings):
        with tempfile.TemporaryDirectory(prefix='mere-linux-deps-test-') as directory:
            root = Path(directory)
            bins = root / 'bin'
            bins.mkdir()
            programs = {
                'sudo': 'exec "$@"\n',
                'apt-get': '''
printf 'apt-get %s\n' "$*" >> "$TEST_DEPS_LOG"
case "$1" in
  update) exit "${TEST_UPDATE_STATUS:-0}" ;;
  install)
    if [ "${TEST_INSTALL_STATUS:-0}" != 0 ]; then exit "$TEST_INSTALL_STATUS"; fi
    touch "$TEST_DEPS_STATE"
    ;;
  *) exit 99 ;;
esac
''',
                'pkg-config': '''
printf 'pkg-config %s\n' "$*" >> "$TEST_DEPS_LOG"
if [ "$1" = --exists ]; then
  [ "${TEST_PKG_NEVER:-0}" = 0 ] || exit 1
  [ "${TEST_READY:-0}" = 1 ] || [ -f "$TEST_DEPS_STATE" ]
else
  printf '%s\n' '-lssl -lcrypto'
fi
''',
                'clang': '''
printf 'clang %s\n' "$*" >> "$TEST_DEPS_LOG"
[ "${TEST_CC_STATUS:-0}" = 0 ] || exit "$TEST_CC_STATUS"
test_output=''
while [ "$#" -gt 0 ]; do
  if [ "$1" = -o ]; then shift; test_output="$1"; fi
  shift
done
[ -n "$test_output" ] || exit 98
printf '#!/bin/sh\nexit %s\n' "${TEST_RUN_STATUS:-0}" > "$test_output"
chmod +x "$test_output"
''',
            }
            for name, body in programs.items():
                path = bins / name
                path.write_text('#!/bin/sh\nset -eu\n' + body)
                path.chmod(0o755)
            env = os.environ.copy()
            env.update(PATH=str(bins) + ':' + env['PATH'],
                       TEST_DEPS_LOG=str(root / 'commands.log'),
                       TEST_DEPS_STATE=str(root / 'installed'))
            env.update({key: str(value) for key, value in settings.items()})
            result = subprocess.run(['sh', str(SCRIPT), *args], env=env,
                                    text=True, capture_output=True, timeout=10)
            log = root / 'commands.log'
            return result, log.read_text() if log.exists() else ''

    def test_ready_toolchain_does_not_contact_apt(self):
        result, log = self.run_setup(TEST_READY=1)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertNotIn('apt-get', log)
        self.assertTrue(any(row.startswith('clang ') for row in log.splitlines()))

    def test_ready_gem_libraries_are_linked_and_executed(self):
        result, log = self.run_setup('--with-gem-libraries', TEST_READY=1)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn('pkg-config --exists openssl libxml-2.0 libxslt sqlite3', log)
        self.assertIn('-DMERE_WITH_GEM_LIBS=1', log)
        self.assertNotIn('apt-get', log)

    def test_failed_index_update_can_still_install_verified_packages(self):
        result, log = self.run_setup('--with-gem-libraries', TEST_UPDATE_STATUS=100)
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn('Some package indexes did not update', result.stderr)
        self.assertIn('apt-get update', log)
        self.assertIn('libxml2-dev libxslt1-dev libsqlite3-dev', log)
        self.assertTrue(any(row.startswith('clang ') for row in log.splitlines()))

    def test_normal_installation(self):
        result, log = self.run_setup()
        self.assertEqual(0, result.returncode, result.stderr)
        self.assertIn('apt-get install -y clang libssl-dev pkg-config', log)

    def test_failed_installation_is_not_waived(self):
        result, log = self.run_setup(TEST_UPDATE_STATUS=100, TEST_INSTALL_STATUS=42)
        self.assertEqual(42, result.returncode)
        self.assertFalse(any(row.startswith('clang ') for row in log.splitlines()))

    def test_missing_package_metadata_after_installation_still_fails(self):
        result, log = self.run_setup(TEST_PKG_NEVER=1)
        self.assertNotEqual(0, result.returncode)
        self.assertFalse(any(row.startswith('clang ') for row in log.splitlines()))

    def test_runtime_probe_failure_is_not_waived(self):
        result, log = self.run_setup(TEST_RUN_STATUS=44)
        self.assertEqual(44, result.returncode)
        self.assertTrue(any(row.startswith('clang ') for row in log.splitlines()))

    def test_compiler_failure_is_not_waived(self):
        result, log = self.run_setup(TEST_READY=1, TEST_CC_STATUS=43)
        self.assertEqual(43, result.returncode)
        self.assertIn('apt-get install', log)

    def test_unknown_argument_does_not_install_anything(self):
        result, log = self.run_setup('--unknown')
        self.assertEqual(2, result.returncode)
        self.assertEqual('', log)


# Keep the real compiler/header probes alongside the mocked installer cases.
class LinuxBuildDepsCheck(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="mere-build-deps-check-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.calls = self.bin / "calls.jsonl"
        self.status = self.bin / "sudo-status"
        self.status.write_text("97")
        sudo = self.bin / "sudo"
        sudo.write_text("#!" + sys.executable + "\n" + '''import json, pathlib, sys
root = pathlib.Path(__file__).parent
with (root / "calls.jsonl").open("a") as log:
    log.write(json.dumps(sys.argv[1:]) + "\\n")
sys.exit(int((root / "sudo-status").read_text()))
''')
        sudo.chmod(0o755)
        self.env = dict(os.environ, LANG="en_US.UTF-8",
                        PATH=str(self.bin) + os.pathsep + os.environ["PATH"])

    def run_setup(self):
        return subprocess.run(["sh", str(ROOT / "tools/linux_build_deps.sh")],
                              env=self.env, text=True, capture_output=True, timeout=20)

    def break_headers(self):
        libraries = subprocess.check_output(["pkg-config", "--libs", "openssl"],
                                            env=self.env, text=True).strip()
        include = self.root / "include/openssl"
        include.mkdir(parents=True)
        (include / "ssl.h").write_text("#error deliberately unusable OpenSSL headers\n")
        metadata = self.root / "pkgconfig"
        metadata.mkdir()
        (metadata / "openssl.pc").write_text(
            "Name: Broken header probe\nDescription: negative setup control\n"
            "Version: 3.0\nLibs: " + libraries + "\nCflags: -I" + str(include.parent) + "\n")
        self.env["PKG_CONFIG_PATH"] = str(metadata)

    def test_existing_compiler_and_ssl_need_no_installer(self):
        self.assertIsNotNone(shutil.which("clang"))
        result = self.run_setup()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(self.calls.exists(), result.stdout + result.stderr)

    def test_missing_headers_propagate_installer_failure(self):
        self.break_headers()
        result = self.run_setup()
        self.assertEqual(result.returncode, 97, result.stdout + result.stderr)
        self.assertEqual([json.loads(s) for s in self.calls.read_text().splitlines()],
                         [["apt-get", "update"], ["apt-get", "install", "-y", "clang", "libssl-dev", "pkg-config"]])

    def test_successful_installer_cannot_hide_bad_headers(self):
        self.break_headers()
        self.status.write_text("0")
        result = self.run_setup()
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual([json.loads(s) for s in self.calls.read_text().splitlines()],
                         [["apt-get", "update"],
                          ["apt-get", "install", "-y", "clang", "libssl-dev", "pkg-config"]])



if __name__ == '__main__':
    unittest.main()

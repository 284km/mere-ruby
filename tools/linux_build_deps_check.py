#!/usr/bin/env python3
"""Use real C/OpenSSL probes to check offline setup and failed installation."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


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
                         [["apt-get", "update"]])

    def test_successful_installer_cannot_hide_bad_headers(self):
        self.break_headers()
        self.status.write_text("0")
        result = self.run_setup()
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual([json.loads(s) for s in self.calls.read_text().splitlines()],
                         [["apt-get", "update"],
                          ["apt-get", "install", "-y", "clang", "libssl-dev", "pkg-config"]])


if __name__ == "__main__":
    unittest.main()

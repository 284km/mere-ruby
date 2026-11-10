"""Use the native CLI's OpenSSL provider selection for embedding probes."""
from pathlib import Path
import os
import platform
import shlex
import shutil
import subprocess


def openssl_flags():
    prefix = os.environ.get('OPENSSL_PREFIX', '')
    if not prefix and platform.system() == 'Darwin' and shutil.which('brew'):
        prefix = subprocess.check_output(['brew', '--prefix', 'openssl@3'], text=True).strip()
    if prefix:
        root = Path(prefix).resolve()
        if not (root / 'include/openssl/ssl.h').is_file():
            raise SystemExit('OPENSSL_PREFIX has no OpenSSL headers')
        return (['-I' + str(root / 'include')],
                ['-L' + str(root / 'lib'), '-Wl,-rpath,' + str(root / 'lib'),
                 '-lssl', '-lcrypto'])
    if shutil.which('pkg-config') and subprocess.run(
            ['pkg-config', '--exists', 'openssl >= 3.0'], check=False).returncode == 0:
        return tuple(shlex.split(subprocess.check_output(
            ['pkg-config', option, 'openssl'], text=True))
                     for option in ['--cflags', '--libs'])
    return [], ['-lssl', '-lcrypto']

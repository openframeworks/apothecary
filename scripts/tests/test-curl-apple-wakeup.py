#!/usr/bin/env python3
"""Test the actual curl patch and wakeup function with Apple/GNU macro profiles."""
import hashlib
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request

root = Path(__file__).resolve().parents[2]
formula = root / 'apothecary/formulas/curl/curl.sh'
text = formula.read_text()
version = re.search(r'^VER=(\S+)$', text, re.M)[1]
tag = re.search(r'^VER_D=(\S+)$', text, re.M)[1]
expected = re.search(r'^SHA256="([a-f0-9]{64})"$', text, re.M)[1]
compiler = shutil.which('clang')
if not compiler:
    raise RuntimeError('Clang is required for the curl wakeup regression')

def run(args, **kwargs):
    result = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, **kwargs)
    if result.returncode:
        raise RuntimeError(result.stdout)
    return result.stdout

with tempfile.TemporaryDirectory(prefix='curl-apple-wakeup-') as directory:
    fixture = Path(directory)
    archive = Path(sys.argv[1]) if len(sys.argv) > 1 else fixture / 'curl.tar.gz'
    if len(sys.argv) <= 1:
        url = f'https://github.com/curl/curl/releases/download/curl-{tag}/curl-{version}.tar.gz'
        with urllib.request.urlopen(url, timeout=60) as response:
            archive.write_bytes(response.read())
    if hashlib.sha256(archive.read_bytes()).hexdigest() != expected:
        raise RuntimeError('curl source SHA-256 mismatch; refusing to extract')
    with tarfile.open(archive) as source:
        for name in ('lib/socketpair.c', 'src/tool_paramhlp.c'):
            destination = fixture / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(source.extractfile(f'curl-{version}/{name}').read())
    command = ['bash', '-e', '-c', 'source "$1"; TYPE=osx; FORMULA_DIR="$2"; prepare',
               'curl-wakeup-test', str(formula), str(formula.parent)]
    run(command, cwd=fixture)
    patched = (fixture / 'lib/socketpair.c').read_bytes()
    run(command, cwd=fixture)
    assert (fixture / 'lib/socketpair.c').read_bytes() == patched, 'prepare must be repeatable'
    source = patched.decode()
    start = source.index('static int wakeup_pipe(')
    function = source[start:source.index('\n#elif defined(HAVE_SOCKETPAIR)', start)]
    for apple in (False, True):
        for have_pipe2 in (False, True):
            prefix = '''
/* Match curl's CMake feature macros: strict C99 hides O_CLOEXEC on glibc. */
#define _GNU_SOURCE 1
#include <stdbool.h>
#include <fcntl.h>
#include <unistd.h>
typedef int curl_socket_t;
#define CURL_SOCKET_BAD (-1)
#define TRUE 1
#define sclose close
static int calls;
static int curlx_nonblock(int fd, int enabled) {
  int flags = fcntl(fd, F_GETFL);
  return fcntl(fd, F_SETFL, enabled ? flags | O_NONBLOCK : flags & ~O_NONBLOCK);
}
#undef __APPLE__
#define HAVE_FCNTL 1
#define HAVE_BUILTIN_AVAILABLE 1
#undef __MAC_OS_X_VERSION_MAX_ALLOWED
#define __MAC_OS_X_VERSION_MAX_ALLOWED 270000
#define pipe2 selected_pipe2
'''
            if apple:
                prefix += '#define __APPLE__ 1\n'
                prefix += 'int selected_pipe2(int fds[2], int flags) __attribute__((error("Apple archive must not import pipe2")));\n'
            else:
                prefix += '''
static int selected_pipe2(int fds[2], int flags) {
  ++calls;
  if(pipe(fds)) return -1;
  for(int i = 0; i < 2; ++i) {
    if(fcntl(fds[i], F_SETFD, FD_CLOEXEC)) return -1;
    if(flags & O_NONBLOCK) if(curlx_nonblock(fds[i], 1)) return -1;
  }
  return 0;
}
'''
            if have_pipe2:
                prefix += '#define HAVE_PIPE2 1\n'
            main = '''
int main(void) {
  for(int nonblocking = 0; nonblocking < 2; ++nonblocking) {
    int fds[2];
    if(wakeup_pipe(fds, nonblocking)) return 1;
    for(int i = 0; i < 2; ++i) {
      if(!(fcntl(fds[i], F_GETFD) & FD_CLOEXEC)) return 2;
      if(!!(fcntl(fds[i], F_GETFL) & O_NONBLOCK) != nonblocking) return 3;
      close(fds[i]);
    }
  }
  return calls == EXPECTED_CALLS ? 0 : 4;
}
'''.replace('EXPECTED_CALLS', str(2 if have_pipe2 and not apple else 0))
            probe = fixture / 'probe.c'
            executable = fixture / 'probe'
            probe.write_text(prefix + function + main)
            run([compiler, '-std=c99', '-Werror=implicit-function-declaration', str(probe), '-o', str(executable)])
            run([str(executable)])
            print(f'{"Apple" if apple else "GNU"}, HAVE_PIPE2={int(have_pipe2)}: wakeup path, close-on-exec and nonblocking flags passed')

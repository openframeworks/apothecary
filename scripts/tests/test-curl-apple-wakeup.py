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
    # Control availability so OS 27 lookup paths also run on older hosts/Linux.
    function = re.sub(r'__builtin_available\([^)]*\)', 'available', function)
    cases = [
        ('Apple older runtime', True, False, 270000, 0, 0, 0, 0, 0),
        ('Apple new runtime, symbol missing', True, False, 270000, 1, 0, 0, 2, 0),
        ('Apple new runtime, symbol found', True, False, 270000, 1, 1, 0, 2, 2),
        ('Apple new runtime, pipe2 fails', True, False, 270000, 1, 1, 1, 2, 2),
        ('Apple old SDK', True, False, 260000, 1, 1, 0, 0, 0),
        ('Apple minimum 27 direct path', True, True, 270000, 1, 1, 0, 0, 2),
        ('GNU pipe2', False, True, 270000, 1, 1, 0, 0, 2),
        ('GNU fallback', False, False, 270000, 1, 1, 0, 0, 0),
    ]
    prefix = r'''
    #define _GNU_SOURCE 1
    #include <stdbool.h>
    #include <fcntl.h>
    #include <unistd.h>
    #include <string.h>
    #include <errno.h>
    #include <dlfcn.h>
    typedef int curl_socket_t;
    #define CURL_SOCKET_BAD (-1)
    #define TRUE 1
    #define sclose close
    #define HAVE_FCNTL 1
    #define HAVE_BUILTIN_AVAILABLE 1
    #undef __APPLE__
    #undef __MAC_OS_X_VERSION_MAX_ALLOWED
    /* PROFILE */
    static int calls, lookups;
    static int curlx_nonblock(int fd, int enabled) {
      int flags = fcntl(fd, F_GETFL);
      return fcntl(fd, F_SETFL, enabled ? flags | O_NONBLOCK : flags & ~O_NONBLOCK);
    }
    static int selected_pipe2(int fds[2], int flags) {
      ++calls;
      if(FAIL_PIPE2) { errno = EMFILE; return -1; }
      if(pipe(fds)) return -1;
      for(int i = 0; i < 2; ++i) {
        if(fcntl(fds[i], F_SETFD, FD_CLOEXEC)) return -1;
        if(flags & O_NONBLOCK) if(curlx_nonblock(fds[i], 1)) return -1;
      }
      return 0;
    }
    static void *selected_dlsym(void *handle, const char *name) {
      ++lookups;
      if(handle != RTLD_DEFAULT || strcmp(name, "pipe2")) return NULL;
      return FOUND ? (void *)selected_pipe2 : NULL;
    }
    #define pipe2 selected_pipe2
    #define dlsym selected_dlsym
    '''
    main = r'''
    int main(void) {
      for(int nonblocking = 0; nonblocking < 2; ++nonblocking) {
        int fds[2] = {-1, -1};
        int result = wakeup_pipe(fds, nonblocking);
        if(FAIL_PIPE2) {
          if(result != -1 || errno != EMFILE || fds[0] != -1 || fds[1] != -1) return 1;
          continue;
        }
        if(result) return 2;
        for(int i = 0; i < 2; ++i) {
          if(!(fcntl(fds[i], F_GETFD) & FD_CLOEXEC)) return 3;
          if(!!(fcntl(fds[i], F_GETFL) & O_NONBLOCK) != nonblocking) return 4;
        }
        if(write(fds[1], "x", 1) != 1) return 5;
        char c;
        if(read(fds[0], &c, 1) != 1 || c != 'x') return 6;
        close(fds[0]); close(fds[1]);
      }
      return calls == CALLS && lookups == LOOKUPS ? 0 : 7;
    }
    '''
    for name, apple, direct, sdk, available, found, fail, lookups, calls in cases:
        defines = f'\n#define __MAC_OS_X_VERSION_MAX_ALLOWED {sdk}\n'
        for key, value in [('available', available), ('FOUND', found), ('FAIL_PIPE2', fail), ('LOOKUPS', lookups), ('CALLS', calls)]:
            defines += f'#define {key} {value}\n'
        if apple:
            defines += '#define __APPLE__ 1\n'
        if direct:
            defines += '#define HAVE_PIPE2 1\n'
        probe = fixture / 'probe.c'
        executable = fixture / 'probe'
        probe.write_text(prefix.replace('/* PROFILE */', defines) + function + main)
        run([compiler, '-std=c99', '-Werror=implicit-function-declaration', str(probe), '-o', str(executable)])
        run([str(executable)])
        print(name + ': lookup selection, descriptor flags and pipe I/O passed')

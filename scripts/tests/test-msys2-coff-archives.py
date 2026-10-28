#!/usr/bin/env python3
"""Cross-link real COFF archives after the engine's MSYS2 normalization."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
tools = Path(os.environ.get('COFF_TEST_LLVM_BIN', '/usr/bin'))


def tool(name):
    candidate = tools / name
    if candidate.is_file():
        return str(candidate)
    result = shutil.which(name)
    if not result:
        raise RuntimeError('Missing regression tool: ' + name)
    return result


clang = os.environ.get('COFF_TEST_CLANG') or tool('clang')
llvm_ar, llvm_nm, lld = map(tool, ('llvm-ar', 'llvm-nm', 'lld'))
gnu_ar = shutil.which('x86_64-w64-mingw32-ar')
if not gnu_ar:
    raise RuntimeError('Install binutils-mingw-w64-x86-64 for the x64 control')
engine = (ROOT / 'apothecary/apothecary').read_text()
start = engine.index('function msys2CpuArch() {')
end = engine.index('function promoteMsys2ArchPath()', start)
functions = engine[start:end]
driver = functions + '''
echoInfo() { echo "$*"; }
echoWarning() { echo "$*" >&2; }
echoVerbose() { :; }
findGnuAr() { printf '%s\n' "$COFF_GNU_AR"; }
findGnuRanlib() { return 1; }
findLlvmAr() { printf '%s\n' "$COFF_LLVM_AR"; }
reindexMsys2GnuArchives "$1"
'''


def run(args, **kwargs):
    try:
        return subprocess.check_output(args, text=True, stderr=subprocess.STDOUT, **kwargs)
    except subprocess.CalledProcessError as error:
        raise RuntimeError(error.output) from error


with tempfile.TemporaryDirectory(prefix='apo-coff-') as directory:
    fixture = Path(directory)
    # copyFormula must propagate normalization failures even without errexit.
    copy_start = engine.index('function copyFormula() {')
    copy_end = engine.index('# clean a given library', copy_start)
    copy_driver = engine[copy_start:copy_end] + '''
echoInfo() { :; }
echoVerbose() { :; }
skipCachedFormula() { return 1; }
copy() { :; }
promoteMsys2ArchPath() { :; }
reindexMsys2GnuArchives() { return 7; }
copyFormula brotli
'''
    (fixture / 'build/brotli').mkdir(parents=True)
    (fixture / 'out').mkdir()
    copied = subprocess.run(['bash', '-c', copy_driver], env=dict(os.environ, TYPE='msys2',
                            BUILD_DIR=str(fixture / 'build'), LIBS_DIR=str(fixture / 'out'),
                            APOTHECARY_DIR=str(fixture)), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
    assert copied.returncode == 7, copied.stdout
    for cpu, target, machine in [('aarch64', 'aarch64-w64-windows-gnu', 'arm64'),
                                 ('x86_64', 'x86_64-w64-windows-gnu', 'x64')]:
        objects = []
        for index, name in enumerate(('BrotliEncoderVersion', 'BrotliDecoderVersion', 'third'), 1):
            folder = fixture / cpu / str(index)
            folder.mkdir(parents=True)
            source, obj = folder / 'provider.c', folder / 'duplicate.o'
            source.write_text(f'int {name}(void) {{ return {index}; }}\n')
            run([clang, '--target=' + target, '-ffreestanding', '-fno-stack-protector', '-c', str(source), '-o', str(obj)])
            objects.append(obj)
        consumer = fixture / cpu / 'consumer.c'
        consumer.write_text('extern int BrotliEncoderVersion(void), BrotliDecoderVersion(void), third(void);\n'
                            'int entry(void) { return BrotliEncoderVersion() + BrotliDecoderVersion() + third(); }\n')
        consumer_obj = consumer.with_suffix('.o')
        run([clang, '--target=' + target, '-ffreestanding', '-fno-stack-protector', '-c', str(consumer), '-o', str(consumer_obj)])
        for duplicate in (False, True):
            root = fixture / (cpu + ('-duplicates' if duplicate else '-unique'))
            libdir = root / 'lib/msys2' / cpu
            libdir.mkdir(parents=True)
            archive = libdir / 'libconsumer.a'
            members = objects
            if not duplicate:
                members = []
                for index, original in enumerate(objects):
                    renamed = original.with_name(f'provider-{index}.o')
                    shutil.copyfile(original, renamed)
                    members.append(renamed)
            run([llvm_ar, '--format=gnu', 'rcs', str(archive), *map(str, members)])
            before = run([llvm_ar, 't', str(archive)]).splitlines()
            env = dict(os.environ, ARCH=cpu, MSYSTEM='CLANGARM64' if cpu == 'aarch64' else 'MINGW64',
                       COFF_GNU_AR=gnu_ar, COFF_LLVM_AR=llvm_ar)
            output = run(['bash', '-e', '-c', driver, 'archive-regression', str(root)], env=env)
            assert '(llvm)' in output if cpu == 'aarch64' else '(gnu)' in output, output
            after = run([llvm_ar, 't', str(archive)]).splitlines()
            assert before == after, (cpu, duplicate, before, after)
            symbols = run([llvm_nm, '--defined-only', str(archive)])
            for name in ('BrotliEncoderVersion', 'BrotliDecoderVersion', 'third'):
                assert name in symbols, (cpu, duplicate, name)
            run([lld, '-flavor', 'link', '/machine:' + machine, '/subsystem:console', '/nodefaultlib',
                 '/entry:entry', '/out:' + str(root / 'consumer.exe'), str(consumer_obj), str(archive)])
            if cpu == 'aarch64':
                unavailable = driver.replace('findLlvmAr() { printf', 'unusedLlvmAr() { printf')
                unavailable = 'findLlvmAr() { return 1; }\n' + unavailable
                missing = subprocess.run(['bash', '-e', '-c', unavailable, 'archive-regression', str(root)], env=env,
                                         stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
                assert missing.returncode != 0, 'ARM64 must not fall back to host GNU ar'
            invalid = libdir / 'broken.a'
            invalid.write_bytes(b'not an archive\n')
            rejected = subprocess.run(['bash', '-e', '-c', driver, 'archive-regression', str(root)], env=env,
                                      stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            assert rejected.returncode != 0, 'Failed archive normalization must stop packaging'
            invalid.unlink()
            print(f'{cpu}: {"duplicate" if duplicate else "unique"} members preserved and COFF consumer linked')

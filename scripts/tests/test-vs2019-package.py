#!/usr/bin/env python3
import hashlib
import importlib.util
import json
from pathlib import Path
import tempfile
import sys
import unittest
import zipfile

sys.dont_write_bytecode = True

spec = importlib.util.spec_from_file_location(
    "v142_package", Path(__file__).resolve().parents[1] / "vs/verify-v142-package.py")
package = importlib.util.module_from_spec(spec)
spec.loader.exec_module(package)


class PackageVerification(unittest.TestCase):
    def check_package(self, changes=None, payload=b"archive fixture", library="zlib"):
        fields = {"cppStandard": "17", "compilerVersion":
                  "Microsoft (R) C/C++ Optimizing Compiler Version 19.29.30158 for x64",
                  "buildCommit": "a" * 40, "binary": "example.lib",
                  "binarySha": hashlib.sha256(b"archive fixture").hexdigest()}
        fields.update(changes or {})
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "package.zip"
            with zipfile.ZipFile(archive, "w") as output:
                output.writestr(f"{library}/lib/vs/x64/example.lib", payload)
                output.writestr(f"{library}/lib/vs/x64/example.pkl", "".join(
                    f"{key} = {json.dumps(value)}\n" for key, value in fields.items()))
            return package.verify(archive, "1" if library == "zlib" else "2", "a" * 40)

    def test_matching_bundles(self):
        for library in ["zlib", "fmt"]:
            with self.subTest(library=library):
                self.assertEqual(len(self.check_package(library=library)["binaries"]), 1)

    def test_reject_wrong_standard_compiler_or_commit(self):
        for change in [{"cppStandard": "23"}, {"compilerVersion": "Version 19.44.1"},
                       {"compilerVersion": ""}, {"buildCommit": "b" * 40}]:
            with self.subTest(change=change), self.assertRaises(ValueError):
                self.check_package(change)

    def test_reject_changed_binary(self):
        with self.assertRaisesRegex(ValueError, "SHA-256 mismatch"):
            self.check_package(payload=b"different archive")

    def test_reject_binary_path(self):
        with self.assertRaisesRegex(ValueError, "invalid binary"):
            self.check_package({"binary": "../example.lib"})

    def test_freetype_metadata_uses_packaged_windows_filename(self):
        commit = "a" * 40
        zlib_bytes = b"zlib archive fixture"
        freetype_bytes = b"freetype archive fixture"
        common = {
            "cppStandard": "17",
            "compilerVersion": "Microsoft (R) C/C++ Optimizing Compiler Version 19.29.30158 for x64",
            "buildCommit": commit,
        }
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / "package.zip"
            with zipfile.ZipFile(archive, "w") as output:
                output.writestr("zlib/lib/vs/x64/zlib.lib", zlib_bytes)
                output.writestr("zlib/lib/vs/x64/zlib.pkl", "".join(
                    f"{key} = {json.dumps(value)}\n" for key, value in {
                        **common,
                        "binary": "zlib.lib",
                        "binarySha": hashlib.sha256(zlib_bytes).hexdigest(),
                    }.items()))
                output.writestr("freetype/lib/vs/x64/freetype.lib", freetype_bytes)
                output.writestr("freetype/lib/vs/x64/freetype.pkl", "".join(
                    f"{key} = {json.dumps(value)}\n" for key, value in {
                        **common,
                        "binary": "freetype.lib",
                        "binarySha": hashlib.sha256(freetype_bytes).hexdigest(),
                    }.items()))
            result = package.verify(archive, "1", commit)
        record = next(item for item in result["binaries"] if item["metadata"].startswith("freetype/"))
        self.assertEqual(record["binary"], "freetype.lib")
        self.assertEqual(record["binarySha"], hashlib.sha256(freetype_bytes).hexdigest())


if __name__ == "__main__":
    unittest.main()

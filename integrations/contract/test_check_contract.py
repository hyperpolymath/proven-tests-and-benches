# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath) <jonathan.jewell@open.ac.uk>

import contextlib
import io
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

import check_contract as checker


class MainTests(unittest.TestCase):
    def invoke(self, *args):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            status = checker.main(["check_contract.py", *args])
        return status, output.getvalue()

    def test_contract_errors_from_both_dispatch_paths(self):
        for function, args in (
            ("run_surface", ("proven-tests",)),
            ("validate_file", ("validate-file", "report.json", "proven-tests")),
        ):
            with self.subTest(function=function):
                with patch.object(checker, function, side_effect=checker.ContractError("broken input")):
                    status, output = self.invoke(*args)
                self.assertEqual(status, 2)
                self.assertIn("NO CHECK PERFORMED: broken input", output)

    def test_missing_and_unparseable_files(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "report.json"
            for contents in (None, "{"):
                if contents is not None:
                    path.write_text(contents, encoding="utf-8")
                with self.subTest(contents=contents):
                    status, output = self.invoke("validate-file", str(path), "proven-tests")
                    self.assertEqual(status, 2)
                    self.assertIn("NO CHECK PERFORMED", output)

            surface = Path(directory) / "proven-tests"
            surface.mkdir()
            with patch.object(checker, "ROOT", directory):
                for contents in (None, "{"):
                    if contents is not None:
                        (surface / "cases.json").write_text(contents, encoding="utf-8")
                    with self.subTest(cases=contents):
                        status, output = self.invoke("proven-tests")
                        self.assertEqual(status, 2)
                        self.assertIn("NO CHECK PERFORMED", output)

    def test_dispatch_preserves_return_codes(self):
        for function, args in (
            ("run_surface", ("cicd-squabbler",)),
            ("validate_file", ("validate-file", "report.json", "proven-tests")),
        ):
            for code in (0, 1, 2):
                with self.subTest(function=function, code=code):
                    with patch.object(checker, function, return_value=code):
                        self.assertEqual(self.invoke(*args)[0], code)


if __name__ == "__main__":
    unittest.main()

# SPDX-License-Identifier: MPL-2.0
# SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell (hyperpolymath)
"""Malformed evidence must be rejected, never crash or acquire a green verdict."""
import copy
import contextlib
import io
import json
import random
from pathlib import Path
import tempfile
import unittest
import check_contract as checker

class AdversarialContractTests(unittest.TestCase):
    def setUp(self):
        self.clean = json.loads((Path(__file__).parent / 'proven-tests/fixtures/report-valid-mixed.json').read_text())

    def status(self, doc, surface='proven-tests'):
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'report.json'
            path.write_text(json.dumps(doc))
            with contextlib.redirect_stdout(io.StringIO()):
                return checker.main(['check_contract.py', 'validate-file', str(path), surface])

    def test_positive_and_boolean_counter_controls(self):
        self.assertEqual(self.status(self.clean), 0)
        for key, value in self.clean['summary'].items():
            if type(value) is int:
                doc = copy.deepcopy(self.clean)
                doc['summary'][key] = bool(value)
                with self.subTest(counter=key):
                    self.assertNotEqual(self.status(doc), 0)

    def test_proof_rung_requires_nonempty_strings(self):
        doc = copy.deepcopy(self.clean)
        doc['entries'][0]['provenance'] = 'ActuallyProven'
        doc['entries'][0]['proof_ladder'] = [
            {'theorem': 'Fixture.identity', 'statement': 'For every x, identity x = x'}]
        doc['summary']['actually_proven'] += 1
        doc['summary']['provisionally_proven'] -= 1
        self.assertEqual(self.status(doc), 0)
        for field in ['theorem', 'statement']:
            for value in [True, 7, None, ['claim'], {'claim': 1}, '', '  ']:
                mutant = copy.deepcopy(doc)
                mutant['entries'][0]['proof_ladder'][0][field] = value
                with self.subTest(field=field, value=value):
                    self.assertNotEqual(self.status(mutant), 0)

    def test_bounded_json_shape_robustness(self):
        # Robustness only: a mutation to optional metadata can remain valid.
        # Rejection correctness is tested separately by the labelled controls.
        paths = []
        def walk(value, path=()):
            paths.append(path)
            if isinstance(value, dict):
                for key, child in value.items():
                    walk(child, path + (key,))
            elif isinstance(value, list):
                for key, child in enumerate(value):
                    walk(child, path + (key,))
        walk(self.clean)
        values = [None, True, False, 0, -1, 1.5, '', '  ', [], {}, ['x'], {'x': True}]
        rng = random.Random(1371)
        for case in range(2000):
            path, value = rng.choice(paths), rng.choice(values)
            doc = copy.deepcopy(self.clean)
            if not path:
                doc = value
            else:
                parent = doc
                for key in path[:-1]:
                    parent = parent[key]
                parent[path[-1]] = value
            with self.subTest(case=case, path=path, value=value):
                try:
                    violations, covered = checker.validate_proven_report(doc)
                    self.assertIsInstance(violations, list)
                    self.assertGreaterEqual(covered, 0)
                except checker.ContractError:
                    pass  # Explicit malformed-input outcome, not a crash.

    def test_malformed_nested_types(self):
        for field in ['evidence', 'proof_ladder', 'category', 'aspect']:
            for value in [True, 12, ['unexpected'], {'unexpected': 1}]:
                if (field == 'evidence' and isinstance(value, dict)) or (field == 'proof_ladder' and isinstance(value, list)):
                    continue
                doc = copy.deepcopy(self.clean)
                doc['entries'][0][field] = value
                with self.subTest(field=field, value=value):
                    self.assertEqual(self.status(doc), 2)

    def test_malformed_contexts(self):
        for value in [True, 12, ['nested'], {'nested': 1}, '', None]:
            for field in ['required', 'check']:
                doc = {'required_contexts': ['build'], 'checks': [{'required_context': 'build', 'run': 'passed'}]}
                if field == 'required': doc['required_contexts'] = [value]
                else: doc['checks'][0]['required_context'] = value
                with self.subTest(field=field, value=value):
                    self.assertEqual(self.status(doc, 'cicd-squabbler'), 2)

    def test_invalid_cli_never_dispatches_a_different_surface(self):
        self.assertEqual(self.status({'required_contexts': [], 'checks': []}, 'typo'), 2)
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(checker.main(['check_contract.py']), 2)
            self.assertEqual(checker.main(['check_contract.py', 'proven-tests', 'ignored']), 2)

if __name__ == '__main__':
    unittest.main()

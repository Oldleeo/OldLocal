import importlib.util
from pathlib import Path
import sys
import subprocess
import unittest
from unittest.mock import patch

bundle = Path(__file__).resolve().parents[1] / 'Backend'
sys.path.insert(0, str(bundle))
import repair_location as repair


class RecoveryTests(unittest.TestCase):
    def setUp(self):
        # The executable is produced by build.sh; these tests mock all calls to it.
        self.reader_present = patch.object(repair.Path, 'is_file', return_value=True)
        self.reader_present.start()
        self.addCleanup(self.reader_present.stop)

    def test_missing_precision_executable_stops_before_write(self):
        with patch.object(repair.Path, 'is_file', return_value=False), patch.object(repair, 'execute', return_value=self.result('205\n')) as execute:
            with self.assertRaisesRegex(RuntimeError, '组件缺失'):
                repair.preference(repair.original.DOMAINS[0], 'write', repair.original.KEYS[0], 1.0)
            self.assertEqual(execute.call_count, 1)

    def test_domain_absent_is_not_restore_failure(self):
        self.assertTrue(repair.missing_preference('Domain (com.apple.locationd) not found.\nDefaults have not been changed.'))

    def test_missing_key_is_recognized(self):
        self.assertTrue(repair.missing_preference('The domain/default pair of (domain, key) does not exist'))

    def test_access_error_is_never_treated_as_absence(self):
        self.assertFalse(repair.missing_preference('Operation not permitted. Domain (com.apple.locationd) not found.'))
        self.assertFalse(repair.missing_preference('Permission denied'))

    def test_restore_skips_already_absent_keys(self):
        backup = {d: {k: None for k in repair.original.KEYS} for d in repair.original.DOMAINS}
        with patch.object(repair, 'snapshot', return_value=backup), patch.object(repair, 'preference') as pref:
            self.assertEqual(repair.restore_checked(backup), 0)
            pref.assert_not_called()

    def test_restore_removes_only_changed_key_and_reads_back(self):
        backup = {d: {k: None for k in repair.original.KEYS} for d in repair.original.DOMAINS}
        before = {d: dict(v) for d, v in backup.items()}
        domain, key = repair.original.DOMAINS[0], repair.original.KEYS[0]
        before[domain][key] = 48.8584
        with patch.object(repair, 'snapshot', side_effect=[before, backup]), patch.object(repair, 'preference') as pref:
            self.assertEqual(repair.restore_checked(backup), 1)
            pref.assert_called_once_with(domain, 'delete', key, None)

    def test_failed_readback_never_reports_recovered(self):
        backup = {d: {k: None for k in repair.original.KEYS} for d in repair.original.DOMAINS}
        wrong = {d: dict(v) for d, v in backup.items()}
        wrong[repair.original.DOMAINS[0]][repair.original.KEYS[0]] = 48.8584
        with patch.object(repair, 'snapshot', side_effect=[backup, wrong]):
            with self.assertRaises(RuntimeError):
                repair.restore_checked(backup)

    def result(self, output, code=0, error=''):
        return subprocess.CompletedProcess([], code, output, error)

    def test_precision_read_uses_json_not_defaults_display(self):
        with patch.object(repair, 'execute', side_effect=[self.result('205\n'), self.result('{"value":101.703963}\n')]) as execute:
            value = repair.preference(repair.original.DOMAINS[0], 'read', repair.original.KEYS[1])
            self.assertEqual(value, 101.703963)
            self.assertTrue(any(arg.endswith('/LocationPreferences') for arg in execute.call_args[0][0]))
            self.assertNotIn('/usr/bin/defaults', execute.call_args[0][0])

    def test_explicit_null_is_the_only_missing_value(self):
        with patch.object(repair, 'execute', side_effect=[self.result('205\n'), self.result('{"value":null}\n')]):
            self.assertIsNone(repair.preference(repair.original.DOMAINS[0], 'read', repair.original.KEYS[0]))

    def test_invalid_reader_output_is_not_treated_as_missing(self):
        for output in ['{"value":true}', '{"value":"3.1"}', '{}', 'not JSON']:
            with self.subTest(output=output), patch.object(repair, 'execute', side_effect=[self.result('205\n'), self.result(output)]):
                with self.assertRaises(RuntimeError):
                    repair.preference(repair.original.DOMAINS[0], 'read', repair.original.KEYS[0])

    def test_reader_failure_is_not_treated_as_missing(self):
        with patch.object(repair, 'execute', side_effect=[self.result('205\n'), self.result('', 1, 'Permission denied')]):
            with self.assertRaises(RuntimeError):
                repair.preference(repair.original.DOMAINS[0], 'read', repair.original.KEYS[0])

    def test_error_redacts_decimal_coordinates(self):
        text = repair.redacted('Invalid value 48.8584 and -2.2945')
        self.assertNotIn('48.8584', text)
        self.assertNotIn('2.2945', text)


if __name__ == '__main__':
    unittest.main()

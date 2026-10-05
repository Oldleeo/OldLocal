from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

bundle = Path(__file__).resolve().parents[1] / 'Backend'
sys.path.insert(0, str(bundle))
import no_reboot_location as tool


class RefreshTests(unittest.TestCase):
    def test_rejected_signal_stops_without_cache_flush(self):
        denied = subprocess.CompletedProcess([], 1, '', 'Operation not permitted')
        with patch.object(tool, 'location_pids', return_value={'372'}), patch.object(tool.recovery, 'execute', return_value=denied) as execute:
            with self.assertRaisesRegex(RuntimeError, '系统拒绝'):
                tool.restart_normal(clear_cache=False)
            execute.assert_called_once_with(['/usr/bin/killall', '-TERM', '-u', '_locationd', 'locationd'], '正常刷新定位服务')

    def test_refresh_requires_a_new_service_process(self):
        ok = subprocess.CompletedProcess([], 0, '', '')
        with patch.object(tool, 'location_pids', side_effect=[{'372'}, {'372'}, {'800'}]), patch.object(tool.recovery, 'execute', return_value=ok), patch.object(tool.time, 'sleep'):
            tool.restart_normal(clear_cache=False)

    def test_unchanged_process_does_not_count_as_refresh(self):
        ok = subprocess.CompletedProcess([], 0, '', '')
        with patch.object(tool, 'location_pids', return_value={'372'}), patch.object(tool.recovery, 'execute', return_value=ok), patch.object(tool.time, 'monotonic', side_effect=[0, 16]):
            with self.assertRaisesRegex(RuntimeError, '未确认'):
                tool.restart_normal(clear_cache=False)

    def test_missing_daemon_is_not_a_success(self):
        with patch.object(tool, 'location_pids', return_value=set()), patch.object(tool.recovery, 'execute') as execute:
            with self.assertRaisesRegex(RuntimeError, '未运行'):
                tool.restart_normal(clear_cache=False)
            execute.assert_not_called()


if __name__ == '__main__':
    unittest.main()

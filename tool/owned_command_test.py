import pathlib
import subprocess
import sys
import tempfile
import unittest

RUNNER = pathlib.Path(__file__).with_name('owned_command.py')


class OwnedConsoleCommandTest(unittest.TestCase):
    def test_console_streams_exit_status_and_no_persistent_log(self):
        with tempfile.TemporaryDirectory() as directory:
            result = subprocess.run([sys.executable, str(RUNNER), '--', sys.executable,
                                     '-c', "import sys;print('out');print('err',file=sys.stderr);sys.exit(7)"],
                                    cwd=directory, capture_output=True, timeout=8)
            self.assertEqual(result.returncode, 7, result.stderr)
            self.assertIn(b'out', result.stdout)
            self.assertIn(b'err', result.stderr)
            self.assertEqual(list(pathlib.Path(directory).iterdir()), [])

    def test_console_deadline_is_bounded(self):
        result = subprocess.run([sys.executable, str(RUNNER), '--timeout-seconds', '.2',
                                 '--', sys.executable, '-c', 'import time;time.sleep(30)'],
                                capture_output=True, timeout=8)
        self.assertEqual(result.returncode, 124, result.stderr)
        self.assertIn(b'stopping its tree', result.stderr)

    def test_invalid_deadline_never_starts_command(self):
        with tempfile.TemporaryDirectory() as directory:
            marker = pathlib.Path(directory) / 'launched'
            result = subprocess.run([sys.executable, str(RUNNER), '--timeout-seconds', '0',
                                     '--', sys.executable, '-c', f'from pathlib import Path;Path({str(marker)!r}).touch()'],
                                    capture_output=True, timeout=8)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(marker.exists())


if __name__ == '__main__':
    unittest.main()

import pathlib
import subprocess
import sys
import tempfile
import unittest

RUNNER = pathlib.Path(__file__).with_name('bounded_command_log.py')


class BoundedCommandLogTest(unittest.TestCase):
    def run_owned(self, root, program, *options):
        return subprocess.run([sys.executable, str(RUNNER), '--log', str(root / 'owned.log'),
                               *options, '--', sys.executable, '-c', program],
                              capture_output=True, timeout=15)

    def test_combines_streams_and_preserves_exit_code(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            result = self.run_owned(root, "import sys;print('out');print('err',file=sys.stderr);sys.exit(7)")
            self.assertEqual(result.returncode, 7)
            self.assertIn(b'out', (root / 'owned.log').read_bytes())
            self.assertIn(b'err', (root / 'owned.log').read_bytes())

    def test_log_limit_does_not_limit_compiler_output_files(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            artifact = root / 'compiler-output'
            program = f"from pathlib import Path;Path({str(artifact)!r}).write_bytes(b'x'*1048576);print('done')"
            result = self.run_owned(root, program, '--max-bytes', '128')
            self.assertEqual(result.returncode, 0)
            self.assertEqual(artifact.stat().st_size, 1048576)
            self.assertIn(b'done', (root / 'owned.log').read_bytes())

    def test_existing_evidence_refuses_launch(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            (root / 'owned.log').write_bytes(b'prior evidence')
            program = f"from pathlib import Path;Path({str(root / 'launched')!r}).touch()"
            result = self.run_owned(root, program)
            self.assertEqual(result.returncode, 126)
            self.assertEqual((root / 'owned.log').read_bytes(), b'prior evidence')
            self.assertFalse((root / 'launched').exists())

    def test_overflow_caps_log_and_stops_owned_writer(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            result = self.run_owned(root, "import sys\nwhile True:sys.stdout.write('x'*8192);sys.stdout.flush()",
                                    '--max-bytes', '128')
            self.assertEqual(result.returncode, 125)
            self.assertEqual((root / 'owned.log').stat().st_size, 128)
            self.assertIn(b'stopping writer', result.stderr)

    def test_deadline_stops_silent_owned_writer(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            result = self.run_owned(root, 'import time;time.sleep(30)', '--timeout-seconds', '.2')
            self.assertEqual(result.returncode, 124)
            self.assertEqual((root / 'owned.log').stat().st_size, 0)
            self.assertIn(b'stopping writer', result.stderr)


if __name__ == '__main__':
    unittest.main()

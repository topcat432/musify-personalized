import json
import os
import signal
import time
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

    @unittest.skipUnless(sys.platform.startswith('linux'), 'Linux CI process-group contract')
    def test_term_resistant_writer_timeout_is_124_and_leaves_no_writer(self):
        self.resistant_case(overflow=False, descendant=False)

    @unittest.skipUnless(sys.platform.startswith('linux'), 'Linux CI process-group contract')
    def test_term_resistant_writer_overflow_is_125_and_leaves_no_writer(self):
        self.resistant_case(overflow=True, descendant=False)

    @unittest.skipUnless(sys.platform.startswith('linux'), 'Linux CI process-group contract')
    def test_exited_leader_pipe_holding_descendant_is_stopped(self):
        self.resistant_case(overflow=False, descendant=True)

    def resistant_case(self, *, overflow, descendant):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            identity_file = root / 'identity.json'
            child = (
                'import os,signal,time,json,sys\nfrom pathlib import Path\n'
                'signal.signal(signal.SIGTERM,signal.SIG_IGN)\n'
                "fields=Path('/proc/self/stat').read_text().partition(') ')[2].split()\n"
                f'Path({str(identity_file)!r}).write_text(json.dumps([os.getpid(),os.getpgrp(),fields[19]]))\n'
            )
            child += ("while True:sys.stdout.write('x'*8192);sys.stdout.flush()\n" if overflow
                      else 'time.sleep(30)\n')
            if descendant:
                program = (
                    'import subprocess,sys,time,os\nfrom pathlib import Path\n'
                    f'subprocess.Popen([sys.executable,"-c",{child!r}])\n'
                    f'while not Path({str(identity_file)!r}).exists():time.sleep(.01)\n'
                    'print("leader exited",flush=True)\nos._exit(7)\n'
                )
            else:
                program = child
            identity = None
            try:
                result = self.run_owned(root, program, '--timeout-seconds', '1',
                                        '--max-bytes', '128' if overflow else '1024')
                self.assertTrue(identity_file.exists(), result.stderr)
                identity = json.loads(identity_file.read_text())
                self.assertEqual(result.returncode, 125 if overflow else 124, result.stderr)
                deadline = time.monotonic() + 2
                while self.writer_alive(identity) and time.monotonic() < deadline:
                    time.sleep(.02)
                self.assertFalse(self.writer_alive(identity), 'Logger-owned writer survived cleanup')
                if descendant:
                    self.assertIn(b'leader exited', (root / 'owned.log').read_bytes())
            finally:
                if identity is None and identity_file.exists():
                    identity = json.loads(identity_file.read_text())
                # A failing old-source control must also clean up its own fixture.
                if identity and self.writer_alive(identity):
                    self.assertEqual(os.getpgid(identity[0]), identity[1])
                    os.killpg(identity[1], signal.SIGKILL)
                    deadline = time.monotonic() + 2
                    while self.writer_alive(identity) and time.monotonic() < deadline:
                        time.sleep(.02)
                    self.assertFalse(self.writer_alive(identity), 'Old-source fixture writer survived cleanup')

    @staticmethod
    def writer_alive(identity):
        try:
            fields = pathlib.Path(f'/proc/{identity[0]}/stat').read_text().partition(') ')[2].split()
            return fields[19] == identity[2] and fields[0] != 'Z'
        except FileNotFoundError:
            return False

    def test_timeout_preserves_flushed_partial_output(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            result = self.run_owned(root, "import time;print('flushed prefix',flush=True);time.sleep(30)",
                                    '--timeout-seconds', '1')
            self.assertEqual(result.returncode, 124)
            self.assertIn(b'flushed prefix', (root / 'owned.log').read_bytes())

    def test_deadline_stops_silent_owned_writer(self):
        with tempfile.TemporaryDirectory() as directory:
            root = pathlib.Path(directory)
            result = self.run_owned(root, 'import time;time.sleep(30)', '--timeout-seconds', '.2')
            self.assertEqual(result.returncode, 124)
            self.assertEqual((root / 'owned.log').stat().st_size, 0)
            self.assertIn(b'stopping writer', result.stderr)


if __name__ == '__main__':
    unittest.main()

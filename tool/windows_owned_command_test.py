"""Real Windows descendant/cancellation contracts; never run local workers implicitly."""
import ctypes
import json
import os
import pathlib
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

TOOL = pathlib.Path(__file__).parent
RUNNER = pathlib.Path(os.environ.get('MUSIFY_LOGGER_UNDER_TEST', TOOL / 'bounded_command_log.py'))
IDENTITY_CODE = r"""
import ctypes,json,os
from pathlib import Path
api=ctypes.WinDLL('kernel32',use_last_error=True)
api.GetCurrentProcess.restype=ctypes.c_void_p
api.GetProcessTimes.argtypes=[ctypes.c_void_p]+[ctypes.POINTER(ctypes.c_uint64)]*4
api.GetProcessTimes.restype=ctypes.c_int

def identity(handle):
    values=[ctypes.c_uint64() for _ in range(4)]
    if not api.GetProcessTimes(int(handle),*(ctypes.byref(v) for v in values)):
        raise ctypes.WinError(ctypes.get_last_error())
    return values[0].value
"""


@unittest.skipUnless(os.name == 'nt', 'Native Windows Job contract')
class WindowsOwnedCommandTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.api = ctypes.WinDLL('kernel32', use_last_error=True)
        signatures = {
            'OpenProcess': (ctypes.c_void_p, [ctypes.c_uint32, ctypes.c_int, ctypes.c_uint32]),
            'GetProcessTimes': (ctypes.c_int, [ctypes.c_void_p] + [ctypes.POINTER(ctypes.c_uint64)] * 4),
            'WaitForSingleObject': (ctypes.c_uint32, [ctypes.c_void_p, ctypes.c_uint32]),
            'TerminateProcess': (ctypes.c_int, [ctypes.c_void_p, ctypes.c_uint]),
            'CloseHandle': (ctypes.c_int, [ctypes.c_void_p]),
        }
        for name, (result, arguments) in signatures.items():
            function = getattr(cls.api, name)
            function.restype = result
            function.argtypes = arguments

    def wait_identity(self, path):
        deadline = time.monotonic() + 6
        while time.monotonic() < deadline:
            try:
                return json.loads(path.read_text())
            except (FileNotFoundError, json.JSONDecodeError):
                time.sleep(.01)
        self.fail('Fixture did not publish an identity')

    def open_fixture(self, identity):
        handle = self.api.OpenProcess(0x00100000 | 0x1000 | 1, False, identity[0])
        if not handle:
            if ctypes.get_last_error() == 87:
                return None  # The exact fixture has already exited.
            raise ctypes.WinError(ctypes.get_last_error())
        values = [ctypes.c_uint64() for _ in range(4)]
        if not self.api.GetProcessTimes(handle, *(ctypes.byref(value) for value in values)):
            self.api.CloseHandle(handle)
            raise ctypes.WinError(ctypes.get_last_error())
        if values[0].value != identity[1]:
            self.api.CloseHandle(handle)
            return None  # Recycled PID: do not signal the replacement.
        return handle

    def alive(self, handle):
        return handle is not None and self.api.WaitForSingleObject(handle, 0) == 258

    def clean_fixture(self, handle):
        if handle is not None:
            try:
                if self.alive(handle):
                    self.assertTrue(self.api.TerminateProcess(handle, 99))
                    self.assertEqual(self.api.WaitForSingleObject(handle, 3000), 0)
            finally:
                self.api.CloseHandle(handle)

    def case(self, mode, *, batch=False, console=False):
        with tempfile.TemporaryDirectory(prefix='owned command ') as directory:
            root = pathlib.Path(directory)
            identity_file = root / 'child.json'
            runner_identity_file = root / 'runner.json'
            child = IDENTITY_CODE + f'Path({str(identity_file)!r}).write_text(json.dumps([os.getpid(),identity(api.GetCurrentProcess())]))\n'
            child += ("import sys\nwhile True:sys.stdout.write('x'*8192);sys.stdout.flush()\n"
                      if mode == 'overflow' else 'import time;time.sleep(60)\n')
            redirected = mode == 'normal'
            leader = (
                'import subprocess,sys,time,os\nfrom pathlib import Path\n'
                f'subprocess.Popen([sys.executable,"-c",{child!r}],'
                + ('stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL' if redirected else 'stdout=None,stderr=None')
                + ')\n'
                f'while not Path({str(identity_file)!r}).exists():time.sleep(.01)\n'
                'print("leader exited",flush=True)\nos._exit(7)\n'
            )
            if batch:
                leader_path = root / 'leader.py'
                leader_path.write_text(leader)
                batch_path = root / 'launch.cmd'
                batch_path.write_text(f'@"{sys.executable}" "{leader_path}"\n')
                command = [os.environ.get('COMSPEC', 'cmd.exe'), '/d', '/c', str(batch_path)]
            else:
                command = [sys.executable, '-c', leader]
            deadline = '30' if mode in ('kill-runner', 'kill-owner') else '3'
            runner = ([sys.executable, str(TOOL / 'owned_command.py'), '--timeout-seconds', deadline]
                      if console else [sys.executable, str(RUNNER), '--log', str(root / 'owned.log'),
                                       '--timeout-seconds', deadline, '--max-bytes', '128' if mode == 'overflow' else '1024'])
            runner += ['--', *command]
            if mode == 'kill-owner':
                owner = (IDENTITY_CODE + 'import subprocess,time\n'
                         f'runner=subprocess.Popen({runner!r})\n'
                         f'Path({str(runner_identity_file)!r}).write_text(json.dumps([runner.pid,identity(runner._handle)]))\n'
                         'time.sleep(60)\n')
                runner = [sys.executable, '-c', owner]
            sentinel = subprocess.Popen([sys.executable, '-c', 'import time;time.sleep(60)'],
                                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            top = subprocess.Popen(runner, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            child_handle = None
            logger_handle = None
            hung = False
            stopped = False
            try:
                child_handle = self.open_fixture(self.wait_identity(identity_file))
                if mode in ('kill-runner', 'kill-owner'):
                    self.assertTrue(self.alive(child_handle), 'Cancellation fixture must be alive first')
                    if mode == 'kill-owner':
                        logger_handle = self.open_fixture(self.wait_identity(runner_identity_file))
                        self.assertTrue(self.alive(logger_handle))
                    top.kill()  # Popen retains this exact fixture's handle.
                try:
                    output, errors = top.communicate(timeout=8)
                except subprocess.TimeoutExpired:
                    hung = True
                    output, errors = b'', b''
                stopped = not self.alive(child_handle) and not self.alive(logger_handle)
                sentinel_alive = sentinel.poll() is None
                if not hung and mode not in ('kill-runner', 'kill-owner'):
                    self.assertEqual(top.returncode, 125 if mode == 'overflow' else 7 if mode == 'normal' else 124,
                                     errors.decode(errors='replace'))
                if not console and mode == 'overflow':
                    self.assertEqual((root / 'owned.log').stat().st_size, 128)
            finally:
                # Old-source controls clean only identity-checked fixture handles.
                try:
                    self.clean_fixture(child_handle)
                finally:
                    try:
                        self.clean_fixture(logger_handle)
                    finally:
                        try:
                            if top.poll() is None:
                                top.kill()
                            top.communicate(timeout=5)
                        finally:
                            foreign_alive_before_own_cleanup = sentinel.poll() is None
                            sentinel.terminate()
                            sentinel.wait(timeout=5)
            self.assertTrue(sentinel_alive and foreign_alive_before_own_cleanup,
                            'Separate sentinel was affected by owned cleanup')
            self.assertFalse(hung, 'OWNED_WINDOWS_DESCENDANT_SURVIVED: inherited pipe blocked cleanup')
            self.assertTrue(stopped, 'OWNED_WINDOWS_DESCENDANT_SURVIVED: command left a fixture alive')

    def test_exited_leader_pipe_holding_descendant(self):
        self.case('timeout')

    def test_exited_leader_redirected_descendant(self):
        self.case('normal')

    def test_overflow_stops_descendant(self):
        self.case('overflow')

    def test_killed_logger_closes_descendants(self):
        self.case('kill-runner')

    def test_killed_outer_harness_closes_descendants(self):
        self.case('kill-owner')

    def test_batch_launcher_descendant(self):
        self.case('timeout', batch=True)

    def test_console_command_normal_exit_cleans_descendant(self):
        self.case('normal', console=True)

    def test_failed_job_assignment_never_runs_child_code(self):
        import windows_owned_job as owned
        with tempfile.TemporaryDirectory() as directory:
            marker = pathlib.Path(directory) / 'launched'
            created = []
            factory = subprocess.Popen
            def create(*arguments, **options):
                process = factory(*arguments, **options)
                created.append(process)
                return process
            with mock.patch.object(owned.WindowsOwnedJob, 'assign', side_effect=OSError('synthetic assignment refusal')):
                with mock.patch.object(owned.subprocess, 'Popen', side_effect=create):
                    with self.assertRaises(OSError):
                        owned.start_owned_process([sys.executable, '-c', f'from pathlib import Path;Path({str(marker)!r}).touch()'])
            self.assertEqual(len(created), 1)
            self.assertIsNotNone(created[0].poll())
            self.assertFalse(marker.exists())


if __name__ == '__main__':
    unittest.main()

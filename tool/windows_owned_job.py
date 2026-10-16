"""Windows lifetime containment for a command created by this runner only.

An unnamed, non-inheritable kill-on-close Job is assigned while the initial
thread is suspended. No process-name/PID-tree adoption or breakaway is allowed.
The caller's exact process handle is watched, so cancelling an outer harness
also closes the Job even if this Python runner was left alive.
"""
import ctypes
import os
import subprocess
import threading

DWORD = ctypes.c_uint32
HANDLE = ctypes.c_void_p
BOOL = ctypes.c_int32
SIZE_T = ctypes.c_size_t


class BasicLimits(ctypes.Structure):
    _fields_ = [('process_time', ctypes.c_int64), ('job_time', ctypes.c_int64),
                ('flags', DWORD), ('min_working_set', SIZE_T),
                ('max_working_set', SIZE_T), ('active_processes', DWORD),
                ('affinity', SIZE_T), ('priority', DWORD), ('scheduling', DWORD)]


class IoCounters(ctypes.Structure):
    _fields_ = [(name, ctypes.c_uint64) for name in
                ('reads', 'writes', 'other', 'read_bytes', 'write_bytes', 'other_bytes')]


class ExtendedLimits(ctypes.Structure):
    _fields_ = [('basic', BasicLimits), ('io', IoCounters),
                ('process_memory', SIZE_T), ('job_memory', SIZE_T),
                ('peak_process_memory', SIZE_T), ('peak_job_memory', SIZE_T)]


class ThreadEntry(ctypes.Structure):
    _fields_ = [('size', DWORD), ('usage', DWORD), ('thread_id', DWORD),
                ('owner_pid', DWORD), ('base_priority', ctypes.c_int32),
                ('delta_priority', ctypes.c_int32), ('flags', DWORD)]


class FileTime(ctypes.Structure):
    _fields_ = [('low', DWORD), ('high', DWORD)]


def _kernel():
    api = ctypes.WinDLL('kernel32', use_last_error=True)
    signatures = {
        'CreateJobObjectW': (HANDLE, [ctypes.c_void_p, ctypes.c_wchar_p]),
        'SetInformationJobObject': (BOOL, [HANDLE, ctypes.c_int, ctypes.c_void_p, DWORD]),
        'AssignProcessToJobObject': (BOOL, [HANDLE, HANDLE]),
        'TerminateJobObject': (BOOL, [HANDLE, ctypes.c_uint]),
        'CloseHandle': (BOOL, [HANDLE]),
        'OpenProcess': (HANDLE, [DWORD, BOOL, DWORD]),
        'GetCurrentProcess': (HANDLE, []),
        'GetProcessTimes': (BOOL, [HANDLE] + [ctypes.POINTER(FileTime)] * 4),
        'WaitForSingleObject': (DWORD, [HANDLE, DWORD]),
        'CreateToolhelp32Snapshot': (HANDLE, [DWORD, DWORD]),
        'Thread32First': (BOOL, [HANDLE, ctypes.POINTER(ThreadEntry)]),
        'Thread32Next': (BOOL, [HANDLE, ctypes.POINTER(ThreadEntry)]),
        'OpenThread': (HANDLE, [DWORD, BOOL, DWORD]),
        'GetProcessIdOfThread': (DWORD, [HANDLE]),
        'ResumeThread': (DWORD, [HANDLE]),
    }
    for name, (result, arguments) in signatures.items():
        function = getattr(api, name)
        function.restype = result
        function.argtypes = arguments
    return api


class WindowsOwnedJob:
    def __init__(self):
        self.api = _kernel()
        self.job = None
        self.owner = None
        self.monitor = None
        self.done = threading.Event()
        self.lock = threading.Lock()
        try:
            self.owner = self.api.OpenProcess(0x00100000 | 0x1000, False, os.getppid())
            if not self.owner:
                raise ctypes.WinError(ctypes.get_last_error())
            # Reject a recycled parent PID; never signal or change the parent.
            if (self._created(self.owner) > self._created(self.api.GetCurrentProcess())
                    or self.api.WaitForSingleObject(self.owner, 0) != 258):
                raise RuntimeError('Owned-command caller has already exited')
            self.job = self.api.CreateJobObjectW(None, None)
            if not self.job:
                raise ctypes.WinError(ctypes.get_last_error())
            limits = ExtendedLimits()
            limits.basic.flags = 0x2000  # JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE.
            if not self.api.SetInformationJobObject(self.job, 9, ctypes.byref(limits), ctypes.sizeof(limits)):
                raise ctypes.WinError(ctypes.get_last_error())
        except BaseException:
            self.close()
            raise

    def _created(self, handle):
        values = [FileTime() for _ in range(4)]
        if not self.api.GetProcessTimes(handle, *(ctypes.byref(value) for value in values)):
            raise ctypes.WinError(ctypes.get_last_error())
        return (values[0].high << 32) | values[0].low

    def assign(self, process):
        # Popen's retained handle identifies the exact child, even after exit.
        if not self.api.AssignProcessToJobObject(self.job, int(process._handle)):
            raise ctypes.WinError(ctypes.get_last_error())

    def resume(self, process):
        # CREATE_SUSPENDED prevents user code/descendants before Job assignment.
        snapshot = self.api.CreateToolhelp32Snapshot(4, 0)  # TH32CS_SNAPTHREAD.
        if snapshot == ctypes.c_void_p(-1).value:
            raise ctypes.WinError(ctypes.get_last_error())
        matches = []
        try:
            entry = ThreadEntry()
            entry.size = ctypes.sizeof(entry)
            present = self.api.Thread32First(snapshot, ctypes.byref(entry))
            while present:
                if entry.owner_pid == process.pid:
                    matches.append(entry.thread_id)
                entry.size = ctypes.sizeof(entry)
                present = self.api.Thread32Next(snapshot, ctypes.byref(entry))
            if ctypes.get_last_error() != 18:  # ERROR_NO_MORE_FILES.
                raise ctypes.WinError(ctypes.get_last_error())
        finally:
            self.api.CloseHandle(snapshot)
        if len(matches) != 1:
            raise RuntimeError('Suspended owned child has no unique initial thread')
        thread = self.api.OpenThread(0x0002 | 0x0800, False, matches[0])
        if not thread:
            raise ctypes.WinError(ctypes.get_last_error())
        try:
            if self.api.GetProcessIdOfThread(thread) != process.pid:
                raise RuntimeError('Owned initial thread identity changed')
            if self.api.ResumeThread(thread) != 1:
                raise RuntimeError('Owned initial thread did not have one suspension')
        finally:
            self.api.CloseHandle(thread)

    def watch_owner(self):
        def watch():
            try:
                while not self.done.wait(.05):
                    status = self.api.WaitForSingleObject(self.owner, 0)
                    if status != 258:
                        # Owner exit/error fails closed over this Job only.
                        self.close()
                        break
            finally:
                self._close_owner()
        monitor = threading.Thread(target=watch, daemon=True)
        monitor.start()
        self.monitor = monitor

    def _close_owner(self):
        with self.lock:
            if self.owner:
                self.api.CloseHandle(self.owner)
                self.owner = None

    def close(self):
        self.done.set()
        with self.lock:
            if self.job:
                try:
                    if not self.api.TerminateJobObject(self.job, 124):
                        raise ctypes.WinError(ctypes.get_last_error())
                finally:
                    self.api.CloseHandle(self.job)
                    self.job = None
        if self.monitor is None:
            self._close_owner()
        elif self.monitor is not threading.current_thread():
            self.monitor.join(timeout=1)


def start_owned_process(command, **options):
    if os.name != 'nt':
        raise RuntimeError('Windows Job launcher used on another platform')
    job = WindowsOwnedJob()
    process = None
    try:
        flags = options.pop('creationflags', 0) | 0x00000004  # CREATE_SUSPENDED.
        process = subprocess.Popen(command, creationflags=flags, **options)
        job.assign(process)
        process._owned_job = job
        job.watch_owner()
        job.resume(process)
        return process
    except BaseException:
        try:
            job.close()
        finally:
            if process is not None:
                # Assignment may have failed; this still-suspended child is ours.
                if process.poll() is None:
                    process.kill()
                process.wait(timeout=5)
                if process.stdout is not None:
                    process.stdout.close()
        raise

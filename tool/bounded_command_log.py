"""Run one owned command with a bounded, never-overwritten output log."""
import argparse
import os
from pathlib import Path
import queue
import signal
import subprocess
import sys
import threading
import time

MAX_BYTES = 10 * 1024 * 1024


def launch_owned(command, **options):
    if os.name == 'nt':
        from windows_owned_job import start_owned_process
        return start_owned_process(command, **options)
    return subprocess.Popen(command, start_new_session=True, **options)


def stop_owned(process):
    # Popen created a private session/group; never signal the caller's group.
    if os.name == 'posix':
        def send(sig):
            try:
                os.killpg(process.pid, sig)
                return True
            except ProcessLookupError:
                return False

        if send(signal.SIGTERM):
            deadline = time.monotonic() + .5
            while time.monotonic() < deadline:
                process.poll()  # Reap the leader without assuming descendants exited.
                if not send(0):
                    break
                time.sleep(.02)
            # A pipe-holding descendant may remain after its leader has exited.
            send(signal.SIGKILL)
    else:
        job = getattr(process, '_owned_job', None)
        if job is None:
            raise RuntimeError('Refusing cleanup of an unowned Windows process')
        # Close even after the leader exits: descendants can hold pipes/state.
        job.close()
    process.wait(timeout=5)


def run(command, log_path, maximum, timeout):
    # Exclusive creation retains earlier evidence; one generation per invocation.
    with Path(log_path).open('xb') as log:
        process = launch_owned(command, stdout=subprocess.PIPE,
                               stderr=subprocess.STDOUT)
        chunks = queue.Queue(maxsize=4)

        def read():
            try:
                while True:
                    chunk = process.stdout.read1(8192)
                    chunks.put(chunk)
                    if not chunk:
                        break
            except Exception as error:
                chunks.put(error)

        reader = threading.Thread(target=read, daemon=True)
        reader.start()
        deadline = time.monotonic() + timeout
        written = 0
        try:
            while True:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise queue.Empty
                chunk = chunks.get(timeout=remaining)
                if isinstance(chunk, Exception):
                    raise chunk
                if not chunk:
                    return process.wait(timeout=max(.01, deadline - time.monotonic()))
                if written + len(chunk) > maximum:
                    log.write(chunk[:maximum - written])
                    log.flush()
                    print('Owned command log reached its byte limit; stopping writer.', file=sys.stderr)
                    return 125
                log.write(chunk)
                written += len(chunk)
        except (queue.Empty, subprocess.TimeoutExpired):
            print('Owned command reached its deadline; stopping writer.', file=sys.stderr)
            return 124
        finally:
            stop_owned(process)
            process.stdout.close()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--log', required=True)
    parser.add_argument('--max-bytes', type=int, default=MAX_BYTES)
    parser.add_argument('--timeout-seconds', type=float, default=240)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command or not 0 < args.max_bytes <= MAX_BYTES or not 0 < args.timeout_seconds <= 600:
        parser.error('A command, at most10MiB, and a deadline of at most600seconds are required.')
    try:
        return run(command, args.log, args.max_bytes, args.timeout_seconds)
    except FileExistsError:
        print('Existing command log retained; no writer launched.', file=sys.stderr)
        return 126


if __name__ == '__main__':
    sys.exit(main())

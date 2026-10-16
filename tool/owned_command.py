"""Console-only owned command; the outer storage session still admits resources."""
import argparse
import subprocess
import sys

from bounded_command_log import launch_owned, stop_owned


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--timeout-seconds', type=float, default=600)
    parser.add_argument('command', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    command = args.command[1:] if args.command[:1] == ['--'] else args.command
    if not command or not 0 < args.timeout_seconds <= 3600:
        parser.error('A command and a deadline of at most3600seconds are required.')
    process = launch_owned(command)
    try:
        return process.wait(timeout=args.timeout_seconds)
    except subprocess.TimeoutExpired:
        print('Owned console command reached its deadline; stopping its tree.', file=sys.stderr)
        return 124
    except KeyboardInterrupt:
        return 130
    finally:
        stop_owned(process)


if __name__ == '__main__':
    sys.exit(main())

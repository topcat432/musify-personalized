import 'package:flutter/material.dart';

class SharedSongFailure {
  SharedSongFailure(this.message, this.isCurrent);
  final String message;
  final bool Function() isCurrent;
}

/// Defers initial-share failures until a Scaffold exists, and checks ownership
/// again at display time. Consuming a failure never changes playback or data.
class SharedSongFailureNotice extends StatefulWidget {
  const SharedSongFailureNotice({
    required this.failures,
    required this.child,
    this.bottomInset,
    super.key,
  });
  final ValueNotifier<SharedSongFailure?> failures;
  final Widget child;
  final double Function()? bottomInset;

  @override
  State<SharedSongFailureNotice> createState() =>
      _SharedSongFailureNoticeState();
}

class _SharedSongFailureNoticeState extends State<SharedSongFailureNotice> {
  @override
  void initState() {
    super.initState();
    widget.failures.addListener(_changed);
    _changed();
  }

  @override
  void didUpdateWidget(SharedSongFailureNotice oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.failures != widget.failures) {
      oldWidget.failures.removeListener(_changed);
      widget.failures.addListener(_changed);
      _changed();
    }
  }

  void _changed() {
    final failure = widget.failures.value;
    if (failure == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(widget.failures.value, failure)) return;
      widget.failures.value = null;
      if (!failure.isCurrent()) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            12 + (widget.bottomInset?.call() ?? 0),
          ),
          content: Text(failure.message),
        ),
      );
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  void dispose() {
    widget.failures.removeListener(_changed);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

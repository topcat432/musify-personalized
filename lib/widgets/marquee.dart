/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 *
 *     Musify is distributed in the hope that it will be useful,
 *     but WITHOUT ANY WARRANTY; without even the implied warranty of
 *     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *     GNU General Public License for more details.
 *
 *     You should have received a copy of the GNU General Public License
 *     along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *
 *     For more information about Musify, including how to contribute,
 *     please visit: https://github.com/gokadzev/Musify
 */

import 'package:flutter/material.dart';

class MarqueeWidget extends StatefulWidget {
  const MarqueeWidget({
    super.key,
    required this.child,
    this.direction = Axis.horizontal,
    this.animationDuration = const Duration(milliseconds: 6000),
    this.backDuration = const Duration(milliseconds: 800),
    this.pauseDuration = const Duration(milliseconds: 800),
    this.manualScrollEnabled = true,
  });

  final Widget child;
  final Axis direction;
  final Duration animationDuration, backDuration, pauseDuration;
  final bool manualScrollEnabled;

  @override
  State<MarqueeWidget> createState() => _MarqueeWidgetState();
}

class _MarqueeWidgetState extends State<MarqueeWidget>
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late ScrollController _scrollController;
  bool _isAnimating = false;
  bool _isDisposed = false;
  bool _overflowCheckScheduled = false;

  /// The last `MediaQuery.of(context).disableAnimations` value seen in
  /// [didChangeDependencies], used to detect a false-to-true or true-to-false
  /// transition rather than reacting to every dependency change.
  bool? _lastDisableAnimations;

  /// Bumped whenever genuine content or direction change invalidates an
  /// in-flight [_startAnimation] loop (see [didUpdateWidget]).
  ///
  /// [_startAnimation] captures the current generation when it starts and
  /// checks it after every await and immediately before every `animateTo`.
  /// A loop whose captured generation no longer matches exits without
  /// touching [_isAnimating], since that flag belongs to whichever loop is
  /// running for the current generation. Without this, a loop paused inside
  /// `Future.delayed` when content changes would otherwise wake up later and
  /// still call `animateTo`, competing with the new loop that
  /// `_maybeStartAnimation` starts for the new content on the same
  /// [_scrollController].
  int _generation = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scheduleOverflowCheck();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    // `_lastDisableAnimations` is null only on the very first call (right
    // after `initState`); treat that as "no transition" rather than a
    // false-to-true edge; the initial `_scheduleOverflowCheck` from
    // `initState` already covers the mount case.
    final wasDisabled = _lastDisableAnimations ?? disableAnimations;
    if (!wasDisabled && disableAnimations) {
      // Reduced motion just turned on. An in-flight `_startAnimation` loop
      // only re-checks `disableAnimations` after its current await, so a
      // long `animateTo` (the mini player uses 8 seconds) could otherwise
      // keep visibly scrolling for a while after the user asked for reduced
      // motion. Bump the generation so that loop's post-await checks exit
      // without touching `_isAnimating`, cancel the active scroll animation
      // by jumping (which disposes the driving activity and completes the
      // loop's pending `animateTo` future immediately), and reset
      // `_isAnimating` directly here since no newer-generation loop is
      // running to own that flag.
      _generation++;
      _isAnimating = false;
      if (_scrollController.hasClients && _scrollController.offset != 0) {
        _scrollController.jumpTo(0);
      }
    } else if (wasDisabled && !disableAnimations) {
      // Reduced motion just turned back off: re-check overflow and let one
      // normal marquee loop resume for the current generation.
      _scheduleOverflowCheck();
    }
    _lastDisableAnimations = disableAnimations;
  }

  @override
  void didUpdateWidget(MarqueeWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.direction != widget.direction ||
        _contentChanged(oldWidget.child, widget.child)) {
      _generation++;
      if (_scrollController.hasClients && _scrollController.offset > 0) {
        _scrollController.jumpTo(0);
      }
      _isAnimating = false;
    }
    _scheduleOverflowCheck();
  }

  /// Whether [newChild] represents different logical content than
  /// [oldChild], e.g. a track change on the Now Playing screen.
  ///
  /// Deliberately does not compare arbitrary widget object identity: parents
  /// (e.g. the mini player) routinely rebuild an equivalent [Text] as a new
  /// widget instance on every playback-state tick, and identity comparison
  /// would reset an in-progress scroll on every such rebuild. Every current
  /// [MarqueeWidget] consumer passes a [Text] child, so comparing the actual
  /// string content distinguishes a real content change from an equivalent
  /// rebuild.
  bool _contentChanged(Widget oldChild, Widget newChild) {
    if (oldChild is Text && newChild is Text) {
      return oldChild.data != newChild.data;
    }
    // No current consumer passes a non-Text child. Without a reliable,
    // generic way to detect "content changed" for an arbitrary widget,
    // assume unchanged rather than resetting on every rebuild.
    return false;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleOverflowCheck() {
    if (_overflowCheckScheduled) return;
    _overflowCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _overflowCheckScheduled = false;
      _maybeStartAnimation();
    });
  }

  void _maybeStartAnimation() {
    if (_isDisposed || !mounted) return;
    if (!_scrollController.hasClients) return;

    if (_scrollController.position.maxScrollExtent <= 0) {
      // Content no longer overflows (e.g. a long-to-short rebuild).
      // Normalize position; the animation loop itself detects this on its
      // next iteration and stops on its own, so `_isAnimating` is left
      // alone here to avoid racing an in-flight loop.
      if (_scrollController.offset > 0) {
        _scrollController.jumpTo(0);
      }
      return;
    }

    if (_isAnimating) return;
    if (MediaQuery.of(context).disableAnimations) return;
    _startAnimation();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    _scheduleOverflowCheck();
    return RepaintBoundary(
      child: SingleChildScrollView(
        scrollDirection: widget.direction,
        controller: _scrollController,
        physics: widget.manualScrollEnabled
            ? const AlwaysScrollableScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        child: widget.child,
      ),
    );
  }

  Future<void> _startAnimation() async {
    if (_isDisposed || _isAnimating) return;
    if (!mounted || MediaQuery.of(context).disableAnimations) return;

    final generation = _generation;
    _isAnimating = true;

    while (_scrollController.hasClients && !_isDisposed) {
      if (!mounted || MediaQuery.of(context).disableAnimations) break;
      try {
        // Check if content actually needs scrolling
        if (_scrollController.position.maxScrollExtent <= 0) {
          break;
        }

        await Future.delayed(widget.pauseDuration);
        if (generation != _generation) return;
        if (_isDisposed || !_scrollController.hasClients) break;
        if (!mounted || MediaQuery.of(context).disableAnimations) break;

        if (generation != _generation) return;
        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: widget.animationDuration,
          curve: Curves.linear,
        );
        if (generation != _generation) return;

        await Future.delayed(widget.pauseDuration);
        if (generation != _generation) return;
        if (_isDisposed || !_scrollController.hasClients) break;
        if (!mounted || MediaQuery.of(context).disableAnimations) break;

        if (generation != _generation) return;
        await _scrollController.animateTo(
          0,
          duration: widget.backDuration,
          curve: Curves.easeOut,
        );
        if (generation != _generation) return;
      } catch (e) {
        // Handle animation interruptions gracefully
        break;
      }
    }

    // A stale generation must never clear `_isAnimating` for a newer loop
    // that `_maybeStartAnimation` may have already started for the current
    // generation.
    if (generation == _generation) {
      _isAnimating = false;
    }
  }
}

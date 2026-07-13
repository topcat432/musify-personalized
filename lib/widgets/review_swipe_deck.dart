/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum ReviewSwipeAction { reject, postpone, accept }

class ReviewSwipeDeckController {
  _ReviewSwipeDeckState? _state;

  bool get isAttached => _state != null;

  Future<void> perform(ReviewSwipeAction action) async {
    await _state?._commit(action);
  }

  void _attach(_ReviewSwipeDeckState state) => _state = state;

  void _detach(_ReviewSwipeDeckState state) {
    if (identical(_state, state)) _state = null;
  }
}

class ReviewSwipeDeck extends StatefulWidget {
  const ReviewSwipeDeck({
    super.key,
    required this.controller,
    required this.currentCard,
    required this.onAction,
    this.nextCard,
    this.enabled = true,
    this.canAccept = true,
  });

  final ReviewSwipeDeckController controller;
  final Widget currentCard;
  final Widget? nextCard;
  final bool enabled;
  final bool canAccept;
  final Future<bool> Function(ReviewSwipeAction action) onAction;

  @override
  State<ReviewSwipeDeck> createState() => _ReviewSwipeDeckState();
}

class _ReviewSwipeDeckState extends State<ReviewSwipeDeck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  Offset _offset = Offset.zero;
  double _angle = 0;
  Size _deckSize = Size.zero;
  bool _animating = false;
  bool _thresholdHapticSent = false;

  @override
  void initState() {
    super.initState();
    widget.controller._attach(this);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
  }

  @override
  void didUpdateWidget(covariant ReviewSwipeDeck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller._detach(this);
      widget.controller._attach(this);
    }
  }

  @override
  void dispose() {
    widget.controller._detach(this);
    _animationController.dispose();
    super.dispose();
  }

  ReviewSwipeAction? get _suggestedAction {
    if (_offset.dy < 0 && _offset.dy.abs() > _offset.dx.abs() * 0.85) {
      return ReviewSwipeAction.postpone;
    }
    if (_offset.dx > 0) return ReviewSwipeAction.accept;
    if (_offset.dx < 0) return ReviewSwipeAction.reject;
    return null;
  }

  double get _actionProgress {
    if (_deckSize.isEmpty) return 0;
    final action = _suggestedAction;
    if (action == ReviewSwipeAction.postpone) {
      return (-_offset.dy / (_deckSize.height * 0.20)).clamp(0, 1);
    }
    return (_offset.dx.abs() / (_deckSize.width * 0.28)).clamp(0, 1);
  }

  bool get _pastThreshold => _actionProgress >= 1;

  void _onPanStart(DragStartDetails details) {
    if (!widget.enabled || _animating) return;
    _animationController.stop();
    _thresholdHapticSent = false;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!widget.enabled || _animating) return;
    setState(() {
      _offset += details.delta;
      _angle = (_offset.dx / math.max(_deckSize.width, 1)) * 0.10;
    });
    if (_pastThreshold && !_thresholdHapticSent) {
      _thresholdHapticSent = true;
      unawaited(HapticFeedback.selectionClick());
    } else if (!_pastThreshold) {
      _thresholdHapticSent = false;
    }
  }

  void _onPanEnd(DragEndDetails details) {
    if (!widget.enabled || _animating) return;
    final velocity = details.velocity.pixelsPerSecond;
    final action = _suggestedAction;
    final fastHorizontal = velocity.dx.abs() > 900 &&
        velocity.dx.abs() > velocity.dy.abs() * 0.8;
    final fastUpward = velocity.dy < -900 &&
        velocity.dy.abs() > velocity.dx.abs() * 0.8;
    final velocityAction = fastUpward
        ? ReviewSwipeAction.postpone
        : fastHorizontal
        ? velocity.dx > 0
              ? ReviewSwipeAction.accept
              : ReviewSwipeAction.reject
        : null;
    final resolvedAction = _pastThreshold ? action : velocityAction;
    if (resolvedAction == null ||
        (resolvedAction == ReviewSwipeAction.accept && !widget.canAccept)) {
      unawaited(_animateBack());
      return;
    }
    unawaited(_commit(resolvedAction));
  }

  void _onPanCancel() {
    if (!_animating) unawaited(_animateBack());
  }

  Future<void> _commit(ReviewSwipeAction action) async {
    if (!widget.enabled || _animating) return;
    if (action == ReviewSwipeAction.accept && !widget.canAccept) {
      await _animateBack();
      return;
    }
    _animating = true;
    await HapticFeedback.mediumImpact();
    if (!mounted) return;
    final width = math.max(_deckSize.width, 360);
    final height = math.max(_deckSize.height, 560);
    final target = switch (action) {
      ReviewSwipeAction.accept => Offset(width * 1.35, _offset.dy * 0.25),
      ReviewSwipeAction.reject => Offset(-width * 1.35, _offset.dy * 0.25),
      ReviewSwipeAction.postpone => Offset(_offset.dx * 0.2, -height * 1.15),
    };
    final targetAngle = switch (action) {
      ReviewSwipeAction.accept => 0.18,
      ReviewSwipeAction.reject => -0.18,
      ReviewSwipeAction.postpone => 0,
    };
    await _animateTo(target, targetAngle, const Duration(milliseconds: 220));
    if (!mounted) return;
    try {
      await widget.onAction(action);
    } catch (_) {
      // The owner keeps the card in place and presents the persistence error.
    }
    if (!mounted) return;
    _offset = Offset.zero;
    _angle = 0;
    _animating = false;
    _thresholdHapticSent = false;
    setState(() {});
  }

  Future<void> _animateBack() async {
    if (_animating && _offset == Offset.zero) return;
    _animating = true;
    await _animateTo(
      Offset.zero,
      0,
      const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
    );
    if (!mounted) return;
    _animating = false;
    _thresholdHapticSent = false;
    setState(() {});
  }

  Future<void> _animateTo(
    Offset target,
    double targetAngle,
    Duration duration, {
    Curve curve = Curves.easeOutCubic,
  }) async {
    final beginOffset = _offset;
    final beginAngle = _angle;
    _animationController
      ..stop()
      ..duration = duration
      ..reset();
    final animation = CurvedAnimation(
      parent: _animationController,
      curve: curve,
    );
    void update() {
      if (!mounted) return;
      setState(() {
        _offset = Offset.lerp(beginOffset, target, animation.value)!;
        _angle = beginAngle + (targetAngle - beginAngle) * animation.value;
      });
    }

    animation.addListener(update);
    try {
      await _animationController.forward().orCancel;
    } on TickerCanceled {
      // A new gesture or disposal superseded this animation.
    } finally {
      animation.removeListener(update);
      animation.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _deckSize = Size(constraints.maxWidth, constraints.maxHeight);
        final progress = _actionProgress;
        final action = _suggestedAction;
        final nextScale = 0.955 + progress * 0.045;
        final nextOffset = 12.0 * (1 - progress);

        return Stack(
          clipBehavior: Clip.none,
          fit: StackFit.expand,
          children: [
            if (widget.nextCard != null)
              Transform.translate(
                key: const ValueKey('review-deck-next'),
                offset: Offset(0, nextOffset),
                child: Transform.scale(
                  scale: nextScale,
                  child: IgnorePointer(child: widget.nextCard),
                ),
              ),
            Transform.translate(
              offset: _offset,
              child: Transform.rotate(
                angle: _angle,
                child: GestureDetector(
                  key: const ValueKey('review-deck-current'),
                  behavior: HitTestBehavior.opaque,
                  onPanStart: _onPanStart,
                  onPanUpdate: _onPanUpdate,
                  onPanEnd: _onPanEnd,
                  onPanCancel: _onPanCancel,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      widget.currentCard,
                      _SwipeOverlay(
                        action: ReviewSwipeAction.accept,
                        visibleAction: action,
                        progress: progress,
                        enabled: widget.canAccept,
                      ),
                      _SwipeOverlay(
                        action: ReviewSwipeAction.reject,
                        visibleAction: action,
                        progress: progress,
                      ),
                      _SwipeOverlay(
                        action: ReviewSwipeAction.postpone,
                        visibleAction: action,
                        progress: progress,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SwipeOverlay extends StatelessWidget {
  const _SwipeOverlay({
    required this.action,
    required this.visibleAction,
    required this.progress,
    this.enabled = true,
  });

  final ReviewSwipeAction action;
  final ReviewSwipeAction? visibleAction;
  final double progress;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (visibleAction != action || progress <= 0) {
      return const SizedBox.shrink();
    }
    final (label, icon, color, alignment, padding) = switch (action) {
      ReviewSwipeAction.accept => (
          enabled ? 'KEEP' : 'NO MATCH',
          enabled ? Icons.favorite : Icons.block,
          enabled ? Colors.green : Colors.grey,
          Alignment.topLeft,
          const EdgeInsets.only(left: 22, top: 24),
        ),
      ReviewSwipeAction.reject => (
          'NOPE',
          Icons.close,
          Colors.red,
          Alignment.topRight,
          const EdgeInsets.only(right: 22, top: 24),
        ),
      ReviewSwipeAction.postpone => (
          'LATER',
          Icons.schedule,
          Colors.amber.shade800,
          Alignment.bottomCenter,
          const EdgeInsets.only(bottom: 30),
        ),
    };

    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: padding,
          child: Opacity(
            opacity: progress,
            child: Transform.rotate(
              angle: action == ReviewSwipeAction.accept
                  ? -0.16
                  : action == ReviewSwipeAction.reject
                  ? 0.16
                  : 0,
              child: DecoratedBox(
                key: ValueKey('review-swipe-${action.name}'),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.90),
                  border: Border.all(color: color, width: 4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: color),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

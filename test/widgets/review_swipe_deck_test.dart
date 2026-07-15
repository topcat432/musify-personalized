import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musify/widgets/review_swipe_deck.dart';

void main() {
  Widget harness({
    required ReviewSwipeDeckController controller,
    required Future<bool> Function(ReviewSwipeAction) onAction,
    bool canAccept = true,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 360,
            height: 560,
            child: ReviewSwipeDeck(
              controller: controller,
              currentCard: const ColoredBox(
                key: ValueKey('card-content'),
                color: Colors.blue,
              ),
              nextCard: const ColoredBox(color: Colors.green),
              canAccept: canAccept,
              onAction: onAction,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('card follows the finger and snaps back below threshold', (
    tester,
  ) async {
    final actions = <ReviewSwipeAction>[];
    final controller = ReviewSwipeDeckController();
    await tester.pumpWidget(
      harness(
        controller: controller,
        onAction: (action) async {
          actions.add(action);
          return true;
        },
      ),
    );

    final deck = find.byKey(const ValueKey('review-deck-current'));
    final start = tester.getCenter(deck);
    final gesture = await tester.startGesture(start);
    await gesture.moveBy(const Offset(45, 12));
    await tester.pump();
    expect(tester.getCenter(deck).dx, greaterThan(start.dx + 35));
    await tester.pump(const Duration(seconds: 1));
    await gesture.moveBy(Offset.zero);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(actions, isEmpty);
    expect(tester.getCenter(deck).dx, closeTo(start.dx, 1));
  });

  testWidgets('right, left, and up swipes commit their expected actions', (
    tester,
  ) async {
    final actions = <ReviewSwipeAction>[];
    final controller = ReviewSwipeDeckController();
    await tester.pumpWidget(
      harness(
        controller: controller,
        onAction: (action) async {
          actions.add(action);
          return true;
        },
      ),
    );

    final deck = find.byKey(const ValueKey('review-deck-current'));
    await tester.drag(deck, const Offset(150, 0));
    await tester.pumpAndSettle();
    await tester.drag(deck, const Offset(-150, 0));
    await tester.pumpAndSettle();
    await tester.drag(deck, const Offset(0, -150));
    await tester.pumpAndSettle();

    expect(actions, <ReviewSwipeAction>[
      ReviewSwipeAction.accept,
      ReviewSwipeAction.reject,
      ReviewSwipeAction.postpone,
    ]);
  });

  testWidgets('controller actions use the same animated commit path', (
    tester,
  ) async {
    final actions = <ReviewSwipeAction>[];
    final controller = ReviewSwipeDeckController();
    await tester.pumpWidget(
      harness(
        controller: controller,
        onAction: (action) async {
          actions.add(action);
          return true;
        },
      ),
    );

    unawaited(controller.perform(ReviewSwipeAction.reject));
    await tester.pump();
    await tester.pumpAndSettle();

    expect(actions, <ReviewSwipeAction>[ReviewSwipeAction.reject]);
  });

  testWidgets('accept swipe snaps back when no candidate can be accepted', (
    tester,
  ) async {
    final actions = <ReviewSwipeAction>[];
    final controller = ReviewSwipeDeckController();
    await tester.pumpWidget(
      harness(
        controller: controller,
        canAccept: false,
        onAction: (action) async {
          actions.add(action);
          return true;
        },
      ),
    );

    await tester.drag(
      find.byKey(const ValueKey('review-deck-current')),
      const Offset(170, 0),
    );
    await tester.pumpAndSettle();

    expect(actions, isEmpty);
  });
}

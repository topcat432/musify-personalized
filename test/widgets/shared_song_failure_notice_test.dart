import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musify/widgets/shared_song_failure_notice.dart';

void main() {
  testWidgets('initial failure appears once after the scaffold mounts', (
    tester,
  ) async {
    final errors = ValueNotifier<SharedSongFailure?>(
      SharedSongFailure('Synthetic visible error', () => true),
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            SharedSongFailureNotice(failures: errors, child: child!),
        home: const Scaffold(body: Text('Existing library')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Synthetic visible error'), findsOneWidget);
    expect(find.text('Existing library'), findsOneWidget);
    expect(errors.value, isNull);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Synthetic visible error'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    errors.dispose();
  });

  testWidgets('new controls before display suppress a stale failure', (
    tester,
  ) async {
    var current = true;
    final errors = ValueNotifier<SharedSongFailure?>(null);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) =>
            SharedSongFailureNotice(failures: errors, child: child!),
        home: const Scaffold(body: Text('Existing library')),
      ),
    );
    errors.value = SharedSongFailure('Stale error', () => current);
    current = false;
    await tester.pumpAndSettle();
    expect(find.text('Stale error'), findsNothing);
    expect(errors.value, isNull);
    await tester.pumpWidget(const SizedBox());
    errors.dispose();
  });
}

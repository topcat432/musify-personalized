import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musify/services/musify_backup_service.dart';
import 'package:musify/widgets/validated_backup_summary.dart';

void main() {
  testWidgets('validated backup renders inside its restore dialog', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  scrollable: true,
                  title: const Text('Validated backup'),
                  content: const ValidatedBackupSummary(
                    sourceDescription: 'synthetic.musifybackup',
                    summary: BackupSummary(
                      importedTracks: 5,
                      matchResults: 5,
                      strongMatches: 2,
                      reviewItems: 1,
                      unmatchedItems: 1,
                      errorItems: 0,
                      excludedItems: 1,
                      favorites: 2,
                      playlists: 1,
                      userKeys: 6,
                      settingsKeys: 4,
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Restore verified data'),
                    ),
                  ],
                ),
              ),
              child: const Text('Inspect backup'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Inspect backup'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('synthetic.musifybackup'), findsOneWidget);
    expect(find.text('Restore verified data'), findsOneWidget);
    await tester.tap(find.text('Restore verified data'));
    await tester.pumpAndSettle();
    expect(find.text('Validated backup'), findsNothing);
  });
}

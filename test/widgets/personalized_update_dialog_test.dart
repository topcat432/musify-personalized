import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musify/services/personalized_update_service.dart';
import 'package:musify/widgets/personalized_update_dialog.dart';

void main() {
  testWidgets('a stalled update download can be cancelled', (tester) async {
    final service = _StallingUpdateService();
    addTearDown(service.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => PersonalizedUpdateDialog(
                  check: _updateCheck,
                  service: service,
                ),
              ),
              child: const Text('Open updater'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open updater'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Download'));
    await tester.pump();
    await service.started.future;

    expect(find.text('Cancel'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(service.cancellation?.isCancelled, isTrue);
    expect(find.byType(PersonalizedUpdateDialog), findsNothing);
  });

  testWidgets('disposing the dialog cancels a stalled update download', (
    tester,
  ) async {
    final service = _StallingUpdateService();
    addTearDown(service.close);

    await tester.pumpWidget(
      MaterialApp(
        home: PersonalizedUpdateDialog(
          check: _updateCheck,
          service: service,
        ),
      ),
    );

    await tester.tap(find.text('Download'));
    await tester.pump();
    await service.started.future;

    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();

    expect(service.cancellation?.isCancelled, isTrue);
  });
}

class _StallingUpdateService extends PersonalizedUpdateService {
  final Completer<void> started = Completer<void>();
  PersonalizedUpdateCancellation? cancellation;

  @override
  Future<VerifiedPersonalizedUpdate> downloadAndVerify(
    PersonalizedUpdateManifest manifest, {
    void Function(double? progress)? onProgress,
    Directory? targetRoot,
    PersonalizedUpdateCancellation? cancellation,
  }) async {
    this.cancellation = cancellation;
    if (!started.isCompleted) started.complete();
    await cancellation!.abortTrigger;
    throw StateError('cancelled');
  }
}

final _updateCheck = PersonalizedUpdateCheck(
  availability: PersonalizedUpdateAvailability.available,
  installed: const InstalledAppIdentity(
    packageName: personalizedProductionPackage,
    versionCode: 100000100,
    signerSha256:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  ),
  manifest: PersonalizedUpdateManifest(
    versionCode: 100000200,
    versionName: '0.1.100000200',
    packageName: personalizedProductionPackage,
    signerSha256:
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    apkSha256:
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
    apkUrl: Uri.parse(
      'https://github.com/topcat432/musify-personalized/releases/download/'
      'personalized-v0.1.100000200/musify-personalized-production.apk',
    ),
    sourceCommit: 'cccccccccccccccccccccccccccccccccccccccc',
    releaseNotes: 'Verified test update.',
  ),
);

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musify/widgets/section_header.dart';

void main() {
  testWidgets('large text section title wraps beside both usable actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: SizedBox(
              width: 320,
              child: SectionHeader(
                title: 'Custom playlists',
                icon: Icons.library_music,
                actionButton: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(Icons.create_new_folder),
                    ),
                    IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester.getSize(find.text('Custom playlists')).height,
      greaterThan(40),
    );
    for (final button in find.byType(IconButton).evaluate()) {
      final size = tester.getSize(
        find.byElementPredicate((e) => identical(e, button)),
      );
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:musify/services/sponsor_skip_target.dart';

void main() {
  final segments = <Map<String, dynamic>>[
    {'start': 10, 'end': 20},
    {'start': 18, 'end': 30},
    {'start': 40, 'end': 50},
  ];
  test('streamed SponsorBlock seeks across overlapping intervals', () {
    expect(
      sponsorSkipTarget(const Duration(seconds: 12), segments),
      const Duration(seconds: 30),
    );
    expect(
      sponsorSkipTarget(const Duration(seconds: 20), segments),
      const Duration(seconds: 30),
    );
  });
  test('unaffected audio and exact end boundaries are preserved', () {
    for (final second in [0, 9, 30, 35, 50, 60]) {
      expect(sponsorSkipTarget(Duration(seconds: second), segments), isNull);
    }
  });
  test('last interval cannot seek beyond decoded duration', () {
    expect(
      sponsorSkipTarget(
        const Duration(seconds: 42),
        segments,
        duration: const Duration(seconds: 45),
      ),
      const Duration(seconds: 45),
    );
  });
  test('invalid intervals are ignored and subsecond boundaries honored', () {
    expect(
      sponsorSkipTarget(const Duration(milliseconds: 1500), [
        {'start': -1, 'end': 5},
        {'start': 8, 'end': 2},
        {'start': '0', 'end': 9},
        {'start': 0, 'end': double.infinity},
        {'start': 1.2, 'end': 2.5},
      ]),
      const Duration(milliseconds: 2500),
    );
  });
}

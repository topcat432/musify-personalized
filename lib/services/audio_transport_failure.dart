import 'dart:convert';

/// An allowlisted byte-range summary. Never retains arbitrary header text.
class AudioContentRange {
  AudioContentRange._(this.start, this.last, this.total, this.unsatisfied);
  final int? start;
  final int? last;
  final int? total;
  final bool unsatisfied;

  static AudioContentRange? parse(String? value) {
    if (value == null || value.length > 128) return null;
    final match = RegExp(
      r'^bytes (?:(\d+)-(\d+)|\*)/(\d+|\*)$',
      caseSensitive: false,
    ).firstMatch(value.trim());
    if (match == null) return null;
    final start = int.tryParse(match[1] ?? '');
    final last = int.tryParse(match[2] ?? '');
    final total = int.tryParse(match[3]!);
    if ((match[1] != null && (start == null || last == null)) ||
        (match[3] != '*' && total == null))
      return null;
    return AudioContentRange._(start, last, total, match[1] == null);
  }

  Map<String, Object?> get diagnostic => {
    'start': start,
    'lastInclusive': last,
    'total': total,
    'unsatisfied': unsatisfied,
  };
}

/// Keeps the original cause and stack in memory; serialization is allowlisted.
/// ClientException messages/URIs, response bodies, tags and headers are excluded.
class AudioTransportFailure extends StateError {
  AudioTransportFailure({
    required this.kind,
    required this.phase,
    required this.requestId,
    required this.nativeStart,
    required this.nativeEndExclusive,
    required this.rangeStart,
    required this.rangeLastInclusive,
    required this.sourceLength,
    required this.receivedBytes,
    required this.deliveredBytes,
    this.httpStatus,
    this.contentRange,
    this.contentRangePresent = false,
    this.responseLength,
    this.cause,
    required this.originStack,
  }) : super('Audio transport failed.');

  final String kind;
  final String phase;
  final int requestId;
  final int nativeStart;
  final int nativeEndExclusive;
  final int rangeStart;
  final int rangeLastInclusive;
  final int sourceLength;
  final int receivedBytes;
  final int deliveredBytes;
  final int? httpStatus;
  final AudioContentRange? contentRange;
  final bool contentRangePresent;
  final int? responseLength;
  final Object? cause;
  final StackTrace originStack;

  Map<String, Object?> get diagnostic => {
    'kind': kind,
    'phase': phase,
    'requestId': requestId,
    'nativeStart': nativeStart,
    'nativeEndExclusive': nativeEndExclusive,
    'rangeStart': rangeStart,
    'rangeLastInclusive': rangeLastInclusive,
    'sourceLength': sourceLength,
    'expectedBytes': rangeLastInclusive - rangeStart + 1,
    'receivedBytes': receivedBytes,
    'deliveredBytes': deliveredBytes,
    'httpStatus': httpStatus,
    'contentRange': contentRange?.diagnostic,
    'contentRangeState': !contentRangePresent
        ? 'absent'
        : contentRange == null
        ? 'invalid'
        : 'parsed',
    'responseLength': responseLength,
    'causeTypes': [
      'AudioTransportFailure',
      if (cause != null) cause.runtimeType.toString(),
    ],
  };

  @override
  String toString() => 'AudioTransportFailure ${jsonEncode(diagnostic)}';
}

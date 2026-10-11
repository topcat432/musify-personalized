/// Absolute seek target for a streamed source whose bytes cannot be clipped.
Duration? sponsorSkipTarget(
  Duration position,
  List<Map<String, dynamic>> segments, {
  Duration? duration,
}) {
  final intervals = <({Duration start, Duration end})>[];
  for (final segment in segments) {
    final start = segment['start'];
    final end = segment['end'];
    if (start is! num ||
        end is! num ||
        !start.isFinite ||
        !end.isFinite ||
        start < 0 ||
        end <= start)
      continue;
    final from = Duration(microseconds: (start * 1000000).round());
    var to = Duration(microseconds: (end * 1000000).round());
    if (duration != null && to > duration) to = duration;
    if (to > from) intervals.add((start: from, end: to));
  }
  intervals.sort((a, b) => a.start.compareTo(b.start));
  var target = position;
  for (final interval in intervals) {
    if (target >= interval.start && target < interval.end)
      target = interval.end;
  }
  return target > position ? target : null;
}

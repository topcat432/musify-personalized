/*
 *     Copyright (C) 2026 Valeri Gokadze
 *
 *     Musify is free software: you can redistribute it and/or modify
 *     it under the terms of the GNU General Public License as published by
 *     the Free Software Foundation, either version 3 of the License, or
 *     (at your option) any later version.
 */

class SpotifyMatchInput {
  const SpotifyMatchInput({
    required this.title,
    required this.artist,
    this.durationMs,
  });

  final String title;
  final String artist;
  final int? durationMs;
}

class SpotifyMatchScore {
  const SpotifyMatchScore({
    required this.score,
    required this.disqualified,
    required this.titleScore,
    required this.artistScore,
    required this.durationScore,
    required this.sourceScore,
    required this.reasons,
  });

  final double score;
  final bool disqualified;
  final double titleScore;
  final double artistScore;
  final double durationScore;
  final double sourceScore;
  final List<String> reasons;

  Map<String, dynamic> toJson() => {
    'score': score,
    'disqualified': disqualified,
    'titleScore': titleScore,
    'artistScore': artistScore,
    'durationScore': durationScore,
    'sourceScore': sourceScore,
    'reasons': reasons,
  };
}

class SpotifyMatchScorer {
  const SpotifyMatchScorer._();

  static const _longFormTerms = <String>[
    'full album',
    'best of',
    'greatest hits',
    'complete album',
    'complete collection',
    'all songs',
    'music playlist',
    'compilation',
    'documentary',
    'interview',
    'reaction',
    'podcast',
    'one hour',
    '1 hour',
    '60 minute',
    '60-minute',
  ];

  static const _alternateVersionTerms = <String>[
    'live',
    'concert',
    'karaoke',
    'cover',
    'nightcore',
    'sped up',
    'slowed',
    'reverb',
    'instrumental',
    'acoustic',
    'radio edit',
    'clean version',
  ];

  static const _noiseTokens = <String>{
    'official',
    'audio',
    'video',
    'music',
    'lyrics',
    'lyric',
    'visualizer',
    'visualiser',
    'hd',
    'hq',
    '4k',
  };

  static SpotifyMatchScore score(
    SpotifyMatchInput input,
    Map<String, dynamic> candidate,
  ) {
    final candidateTitle = candidate['title']?.toString() ?? '';
    final candidateArtist = candidate['artist']?.toString() ?? '';
    final videoAuthor = candidate['videoAuthor']?.toString() ?? '';
    final durationSeconds = _asInt(candidate['duration']);

    final normalizedSourceTitle = _normalize(input.title);
    final normalizedCandidateTitle = _normalize(candidateTitle);
    final normalizedSourceArtist = _normalize(input.artist);
    final normalizedCandidateArtist = _normalize(
      '$candidateArtist $videoAuthor',
    );

    final titleScore = _textSimilarity(
      normalizedSourceTitle,
      normalizedCandidateTitle,
    );
    final artistScore = _textSimilarity(
      normalizedSourceArtist,
      normalizedCandidateArtist,
    );
    final durationScore = _durationScore(input.durationMs, durationSeconds);
    final sourceScore = _sourceScore(videoAuthor);

    final combinedText = _normalize('$candidateTitle $videoAuthor');
    final reasons = <String>[];
    var disqualified = false;
    var penalty = 0.0;

    if (titleScore >= 0.98) {
      reasons.add('Exact title match');
    } else if (titleScore >= 0.80) {
      reasons.add('Strong title match');
    }

    if (artistScore >= 0.90) {
      reasons.add('Strong artist match');
    }

    if (durationScore >= 0.90 && input.durationMs != null) {
      reasons.add('Duration closely matches');
    }

    if (sourceScore >= 0.90) {
      reasons.add('Official or Topic source');
    }

    final hasLongFormTerm = _longFormTerms.any(combinedText.contains);
    final expectedSeconds = input.durationMs == null
        ? null
        : input.durationMs! / 1000;
    final durationLooksLong = durationSeconds != null &&
        (durationSeconds > 900 ||
            (expectedSeconds != null &&
                durationSeconds > expectedSeconds * 1.75 &&
                durationSeconds - expectedSeconds > 90));

    if (hasLongFormTerm && durationLooksLong) {
      disqualified = true;
      reasons.add('Rejected as long-form or compilation content');
    } else if (durationLooksLong) {
      disqualified = true;
      reasons.add('Rejected because duration is far too long');
    } else if (hasLongFormTerm) {
      penalty += 0.18;
      reasons.add('Title suggests compilation content');
    }

    final sourceMentionsAlternate = _alternateVersionTerms.any(
      normalizedSourceTitle.contains,
    );
    final candidateMentionsAlternate = _alternateVersionTerms.any(
      combinedText.contains,
    );
    if (candidateMentionsAlternate && !sourceMentionsAlternate) {
      penalty += 0.12;
      reasons.add('Alternate version not requested');
    }

    if (titleScore < 0.45 || artistScore < 0.30) {
      disqualified = true;
      reasons.add('Title or artist identity is too weak');
    }

    final weighted = titleScore * 0.48 +
        artistScore * 0.32 +
        durationScore * 0.15 +
        sourceScore * 0.05 -
        penalty;
    final finalScore = disqualified ? 0.0 : weighted.clamp(0.0, 1.0);

    if (reasons.isEmpty) reasons.add('Loose metadata match');

    return SpotifyMatchScore(
      score: finalScore,
      disqualified: disqualified,
      titleScore: titleScore,
      artistScore: artistScore,
      durationScore: durationScore,
      sourceScore: sourceScore,
      reasons: List.unmodifiable(reasons),
    );
  }

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }

  static double _durationScore(int? expectedMs, int? candidateSeconds) {
    if (expectedMs == null || candidateSeconds == null) return 0.5;

    final expectedSeconds = expectedMs / 1000;
    final difference = (expectedSeconds - candidateSeconds).abs();
    if (difference <= 4) return 1.0;
    if (difference <= 8) return 0.92;
    if (difference <= 15) return 0.80;
    if (difference <= 30) return 0.55;
    if (difference <= 60) return 0.25;
    return 0.0;
  }

  static double _sourceScore(String author) {
    final normalized = _normalize(author);
    if (normalized.contains('topic')) return 1.0;
    if (normalized.contains('vevo')) return 0.95;
    if (normalized.contains('official')) return 0.88;
    return 0.5;
  }

  static double _textSimilarity(String left, String right) {
    if (left.isEmpty || right.isEmpty) return 0.0;
    if (left == right) return 1.0;

    final leftTokens = _tokens(left);
    final rightTokens = _tokens(right);
    if (leftTokens.isEmpty || rightTokens.isEmpty) return 0.0;

    final intersection = leftTokens.intersection(rightTokens).length;
    final union = leftTokens.union(rightTokens).length;
    final jaccard = union == 0 ? 0.0 : intersection / union;

    final shorter = left.length <= right.length ? left : right;
    final longer = left.length > right.length ? left : right;
    final containment = longer.contains(shorter) &&
            shorter.length >= (longer.length * 0.60)
        ? 0.94
        : 0.0;

    final coverage = intersection / leftTokens.length;
    return [jaccard * 0.65 + coverage * 0.35, containment]
        .reduce((a, b) => a > b ? a : b)
        .clamp(0.0, 1.0);
  }

  static Set<String> _tokens(String value) {
    return value
        .split(' ')
        .where((token) => token.length > 1 && !_noiseTokens.contains(token))
        .toSet();
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('&', ' and ')
        .replaceAll(RegExp(r"['’]"), '')
        .replaceAll(RegExp(r'[^a-z0-9\u00c0-\u024f]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

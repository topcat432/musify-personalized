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
    this.album = '',
    this.isrc = '',
    this.durationMs,
  });

  final String title;
  final String artist;
  final String album;
  final String isrc;
  final int? durationMs;
}

class SpotifyMatchScore {
  const SpotifyMatchScore({
    required this.score,
    required this.disqualified,
    required this.automaticEligible,
    required this.titleScore,
    required this.artistScore,
    required this.primaryArtistScore,
    required this.albumScore,
    required this.durationScore,
    required this.sourceScore,
    required this.reasons,
  });

  final double score;
  final bool disqualified;
  final bool automaticEligible;
  final double titleScore;
  final double artistScore;
  final double primaryArtistScore;
  final double albumScore;
  final double durationScore;
  final double sourceScore;
  final List<String> reasons;

  Map<String, dynamic> toJson() => {
    'score': score,
    'disqualified': disqualified,
    'automaticEligible': automaticEligible,
    'titleScore': titleScore,
    'artistScore': artistScore,
    'primaryArtistScore': primaryArtistScore,
    'albumScore': albumScore,
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

  static const _masteringVariantTerms = <String>[
    'remaster',
    'remastered',
    'anniversary edition',
    'mono mix',
    'stereo mix',
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
    'explicit',
  };

  static SpotifyMatchScore score(
    SpotifyMatchInput input,
    Map<String, dynamic> candidate,
  ) {
    final candidateTitle = candidate['title']?.toString() ?? '';
    final candidateRawTitle = candidate['rawTitle']?.toString() ?? '';
    final candidateAlbum = candidate['album']?.toString() ?? '';
    final videoAuthor = candidate['videoAuthor']?.toString() ?? '';
    final durationSeconds = _asInt(candidate['duration']);
    final candidateArtists = _candidateArtists(candidate);

    final normalizedSourceTitle = _normalizeTitle(input.title);
    final normalizedCandidateTitle = _normalizeTitle(candidateTitle);
    final titleScore = _textSimilarity(
      normalizedSourceTitle,
      normalizedCandidateTitle,
    );

    final artistMatch = _artistSimilarity(input.artist, candidateArtists);
    final artistScore = artistMatch.$1;
    final primaryArtistScore = artistMatch.$2;
    final albumScore = _optionalTextScore(input.album, candidateAlbum);
    final durationScore = _durationScore(input.durationMs, durationSeconds);
    final sourceScore = _sourceScore(candidate, videoAuthor);

    final combinedText = _normalize('$candidateTitle $candidateRawTitle');
    final reasons = <String>[];
    var disqualified = false;
    var penalty = 0.0;

    if (titleScore >= 0.98) {
      reasons.add('Exact title match');
    } else if (titleScore >= 0.80) {
      reasons.add('Strong title match');
    }

    if (primaryArtistScore >= 0.90) {
      reasons.add('Primary artist matches');
    }
    if (artistScore >= 0.88 && _splitArtists(input.artist).length > 1) {
      reasons.add('Collaborating artists match');
    }

    if (albumScore >= 0.90 &&
        input.album.trim().isNotEmpty &&
        candidateAlbum.trim().isNotEmpty) {
      reasons.add('Album matches');
    }

    if (durationScore >= 0.90 && input.durationMs != null) {
      reasons.add('Duration closely matches');
    }

    if (sourceScore >= 0.95) {
      reasons.add(
        candidate['sourceType'] == 'youtube_music_song'
            ? 'YouTube Music song result'
            : 'Official or Topic source',
      );
    }

    final sourceIsrc = _normalizeIsrc(input.isrc);
    final candidateIsrc = _normalizeIsrc(candidate['isrc']?.toString() ?? '');
    var isrcBonus = 0.0;
    if (sourceIsrc.isNotEmpty && candidateIsrc == sourceIsrc) {
      isrcBonus = 0.08;
      reasons.add('ISRC exactly matches');
    }

    final hasLongFormTerm = _longFormTerms.any(
      (term) => _containsWholeTerm(combinedText, term),
    );
    final hasStrongLongFormTerm = _longFormTerms
        .where((term) => term != 'best of')
        .any((term) => _containsWholeTerm(combinedText, term));
    final expectedSeconds = input.durationMs == null
        ? null
        : input.durationMs! / 1000;
    final durationLooksLong = durationSeconds != null &&
        (expectedSeconds == null
            ? durationSeconds > 900
            : durationSeconds > expectedSeconds * 1.75 &&
                durationSeconds - expectedSeconds > 90);

    if (hasLongFormTerm && durationLooksLong) {
      disqualified = true;
      reasons.add('Rejected as long-form or compilation content');
    } else if (durationLooksLong) {
      disqualified = true;
      reasons.add('Rejected because duration is far too long');
    } else if (hasStrongLongFormTerm) {
      penalty += 0.18;
      reasons.add('Title suggests compilation content');
    }

    final sourceMentionsAlternate = _alternateVersionTerms.any(
      (term) => _sourceRequestsVersion(input, term),
    );
    final candidateMentionsAlternate = _alternateVersionTerms.any(
      (term) => _candidateMarksVersion(
        input,
        candidateTitle,
        candidateRawTitle,
        candidateAlbum,
        term,
      ),
    );
    final hasUnrequestedAlternate =
        candidateMentionsAlternate && !sourceMentionsAlternate;
    if (hasUnrequestedAlternate) {
      penalty += 0.14;
      reasons.add('Alternate version not requested');
    }

    final sourceMentionsMasteringVariant = _masteringVariantTerms.any(
      (term) => _sourceRequestsVersion(input, term),
    );
    final candidateMentionsMasteringVariant = _masteringVariantTerms.any(
      (term) => _candidateMarksVersion(
        input,
        candidateTitle,
        candidateRawTitle,
        candidateAlbum,
        term,
      ),
    );
    final hasUnrequestedMasteringVariant =
        candidateMentionsMasteringVariant && !sourceMentionsMasteringVariant;
    if (hasUnrequestedMasteringVariant) {
      penalty += 0.05;
      reasons.add('Different mastering or mix version');
    }

    if (titleScore < 0.38) {
      disqualified = true;
      reasons.add('Song title identity is too weak');
    }
    if (primaryArtistScore < 0.35 && artistScore < 0.42) {
      disqualified = true;
      reasons.add('Primary artist identity is too weak');
    }

    final weighted = titleScore * 0.40 +
        artistScore * 0.28 +
        albumScore * 0.10 +
        durationScore * 0.12 +
        sourceScore * 0.10 +
        isrcBonus -
        penalty;
    final finalScore = disqualified ? 0.0 : weighted.clamp(0.0, 1.0);
    final reliableSource = isReliableSource(candidate);
    if (!reliableSource) {
      reasons.add('Fallback source needs review');
    }
    final automaticEligible = !disqualified &&
        reliableSource &&
        !hasUnrequestedAlternate &&
        !hasUnrequestedMasteringVariant &&
        titleScore >= 0.82 &&
        primaryArtistScore >= 0.72 &&
        finalScore >= 0.86;

    if (reasons.isEmpty) reasons.add('Loose metadata match');

    return SpotifyMatchScore(
      score: finalScore,
      disqualified: disqualified,
      automaticEligible: automaticEligible,
      titleScore: titleScore,
      artistScore: artistScore,
      primaryArtistScore: primaryArtistScore,
      albumScore: albumScore,
      durationScore: durationScore,
      sourceScore: sourceScore,
      reasons: List.unmodifiable(reasons),
    );
  }

  static List<String> _candidateArtists(Map<String, dynamic> candidate) {
    final result = <String>[];
    final seen = <String>{};

    void add(String? raw) {
      if (raw == null) return;
      for (final artist in _splitArtists(_cleanChannelArtist(raw))) {
        final normalized = _normalize(artist);
        if (normalized.isNotEmpty && seen.add(normalized)) result.add(artist);
      }
    }

    final structured = candidate['artists'];
    if (structured is List) {
      for (final artist in structured) {
        add(artist?.toString());
      }
    }
    add(candidate['artist']?.toString());
    add(candidate['videoAuthor']?.toString());
    return result;
  }

  static (double, double) _artistSimilarity(
    String source,
    List<String> candidates,
  ) {
    final expected = _splitArtists(source);
    if (expected.isEmpty || candidates.isEmpty) return (0.0, 0.0);

    double bestAgainst(String artist) {
      var best = 0.0;
      for (final candidate in candidates) {
        final similarity = _textSimilarity(
          _normalize(artist),
          _normalize(candidate),
        );
        if (similarity > best) best = similarity;
      }
      return best;
    }

    final primary = bestAgainst(expected.first);
    final coverage = expected.map(bestAgainst).reduce((a, b) => a + b) /
        expected.length;
    return ((primary * 0.65 + coverage * 0.35).clamp(0.0, 1.0), primary);
  }

  static List<String> _splitArtists(String value) {
    final separated = value
        .replaceAll(
          RegExp(r'\s+(?:feat(?:uring)?|ft)\.?\s+', caseSensitive: false),
          ',',
        )
        .replaceAll(RegExp(r'\s+[xX]\s+'), ',');
    return separated
        .split(RegExp(r'\s*[,;]\s*'))
        .map((artist) => artist.trim())
        .where((artist) => artist.isNotEmpty)
        .toList(growable: false);
  }

  static String _cleanChannelArtist(String value) {
    return value
        .replaceAll(RegExp(r'\s*-\s*topic\s*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+vevo\s*$', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+official\s*$', caseSensitive: false), '')
        .trim();
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
    if (difference <= 4) return 1;
    if (difference <= 8) return 0.92;
    if (difference <= 15) return 0.80;
    if (difference <= 30) return 0.55;
    if (difference <= 60) return 0.25;
    return 0;
  }

  static double _optionalTextScore(String source, String candidate) {
    if (source.trim().isEmpty || candidate.trim().isEmpty) return 0.5;
    return _textSimilarity(_normalize(source), _normalize(candidate));
  }

  static double _sourceScore(
    Map<String, dynamic> candidate,
    String author,
  ) {
    if (candidate['sourceType'] == 'youtube_music_song') return 1;
    if (_isTopicChannel(author)) return 0.96;
    if (_isVevoChannel(author)) return 0.92;
    if (_isOfficialChannel(author)) return 0.85;
    return 0.55;
  }

  static bool isReliableSource(Map<String, dynamic> candidate) {
    if (candidate['sourceType'] == 'youtube_music_song') return true;
    final author = candidate['videoAuthor']?.toString() ?? '';
    return _isTopicChannel(author) ||
        _isVevoChannel(author) ||
        _isOfficialChannel(author);
  }

  static bool _isTopicChannel(String author) => RegExp(
    r'\s-\s*topic\s*$',
    caseSensitive: false,
  ).hasMatch(author.trim());

  static bool _isVevoChannel(String author) {
    final normalized = _normalize(author);
    return !_containsWholeTerm(normalized, 'unofficial') &&
        RegExp(r'vevo$').hasMatch(normalized.replaceAll(' ', ''));
  }

  static bool _isOfficialChannel(String author) {
    final normalized = _normalize(author);
    return !_containsWholeTerm(normalized, 'unofficial') &&
        _containsWholeTerm(normalized, 'official');
  }

  static double _textSimilarity(String left, String right) {
    if (left.isEmpty || right.isEmpty) return 0;
    if (left == right) return 1;

    final leftTokens = _tokens(left);
    final rightTokens = _tokens(right);
    if (leftTokens.isEmpty || rightTokens.isEmpty) return 0;

    final intersection = leftTokens.intersection(rightTokens).length;
    final union = leftTokens.union(rightTokens).length;
    final jaccard = union == 0 ? 0.0 : intersection / union;
    final leftCoverage = intersection / leftTokens.length;
    final rightCoverage = intersection / rightTokens.length;
    final balancedCoverage = (leftCoverage + rightCoverage) / 2;

    final shorter = left.length <= right.length ? left : right;
    final longer = left.length > right.length ? left : right;
    final containment = longer.contains(shorter) &&
            shorter.length >= (longer.length * 0.55)
        ? 0.94
        : 0.0;

    return [jaccard * 0.55 + balancedCoverage * 0.45, containment]
        .reduce((a, b) => a > b ? a : b)
        .clamp(0.0, 1.0);
  }

  static Set<String> _tokens(String value) {
    return value
        .split(' ')
        .where((token) => token.length > 1 && !_noiseTokens.contains(token))
        .toSet();
  }

  static bool _containsWholeTerm(String normalizedText, String term) {
    final normalizedTerm = _normalize(term);
    return ' $normalizedText '.contains(' $normalizedTerm ');
  }

  static bool _sourceRequestsVersion(SpotifyMatchInput input, String term) =>
      _containsContextualTerm(input.title, term, allowBareSuffix: false) ||
      _containsContextualTerm(input.album, term, allowBareSuffix: false);

  static bool _candidateMarksVersion(
    SpotifyMatchInput input,
    String title,
    String rawTitle,
    String album,
    String term,
  ) =>
      _containsContextualTerm(title, term, allowBareSuffix: false) ||
      _containsContextualTerm(rawTitle, term, allowBareSuffix: false) ||
      _containsContextualTerm(album, term, allowBareSuffix: false) ||
      _hasExtraVersionSuffix(input.title, title, term) ||
      _hasExtraVersionSuffix(input.title, rawTitle, term) ||
      _hasExtraVersionSuffix(input.album, album, term);

  static bool _hasExtraVersionSuffix(
    String source,
    String candidate,
    String term,
  ) {
    final normalizedSource = _normalize(source);
    final normalizedCandidate = _normalize(candidate);
    final normalizedTerm = _normalize(term);
    if (normalizedSource.isEmpty ||
        normalizedCandidate == normalizedSource ||
        !normalizedCandidate.startsWith('$normalizedSource ')) {
      return false;
    }
    final extra = normalizedCandidate.substring(normalizedSource.length).trim();
    return _containsWholeTerm(extra, normalizedTerm);
  }

  static bool _containsContextualTerm(
    String value,
    String term, {
    required bool allowBareSuffix,
  }) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return false;

    for (final match in RegExp(r'[\(\[][\s\S]*?[\)\]]').allMatches(trimmed)) {
      if (_containsWholeTerm(_normalize(match.group(0) ?? ''), term)) {
        return true;
      }
    }

    final markedSegments = trimmed.split(RegExp(r'\s[-–—:]\s'));
    if (markedSegments.length > 1 &&
        _containsWholeTerm(_normalize(markedSegments.last), term)) {
      return true;
    }

    final normalized = _normalize(trimmed);
    final normalizedTerm = _normalize(term);
    return allowBareSuffix &&
        normalized != normalizedTerm &&
        normalized.endsWith(' $normalizedTerm');
  }

  static String _normalizeTitle(String value) {
    return _normalize(
      value
          .replaceAll(
            RegExp(
              r'[\(\[]\s*(?:feat(?:uring)?|ft)\.?[^\)\]]*[\)\]]',
              caseSensitive: false,
            ),
            ' ',
          )
          .replaceAll(
            RegExp(
              r'\s+(?:feat(?:uring)?|ft)\.?\s+.+$',
              caseSensitive: false,
            ),
            ' ',
          ),
    );
  }

  static String _normalizeIsrc(String value) {
    return value.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('&', ' and ')
        .replaceAll(RegExp("['’]"), '')
        .replaceAll(RegExp(r'[^a-z0-9\u00c0-\u024f]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

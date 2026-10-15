import 'dart:convert';

/// Outcome for a single word during gameplay.
enum WordResult { correct, passed }

/// Stores the result of one word shown during a round.
class WordAttempt {
  final String word;
  final WordResult result;

  const WordAttempt({required this.word, required this.result});

  Map<String, dynamic> toMap() {
    return {
      'word': word,
      'result': result.name,
    };
  }

  factory WordAttempt.fromMap(Map<String, dynamic> map) {
    return WordAttempt(
      word: map['word'] as String? ?? '',
      result: (map['result'] as String?) == 'correct'
          ? WordResult.correct
          : WordResult.passed,
    );
  }
}

/// Stores the full results of a completed game round.
class GameRound {
  final String id;
  final String deckId;
  final String deckName;
  final int timerDuration;
  final List<WordAttempt> attempts;
  final DateTime playedAt;

  GameRound({
    String? id,
    String? deckId,
    required this.deckName,
    required this.timerDuration,
    required this.attempts,
    DateTime? playedAt,
  })  : id = id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        deckId = deckId ?? deckName,
        playedAt = playedAt ?? DateTime.now();

  int get correctCount =>
      attempts.where((a) => a.result == WordResult.correct).length;

  int get passedCount =>
      attempts.where((a) => a.result == WordResult.passed).length;

  int get totalAttempts => attempts.length;

  int get accuracyPercentage =>
      totalAttempts == 0 ? 0 : ((correctCount / totalAttempts) * 100).round();

  List<WordAttempt> get correctWords =>
      attempts.where((a) => a.result == WordResult.correct).toList();

  List<WordAttempt> get passedWords =>
      attempts.where((a) => a.result == WordResult.passed).toList();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'deckId': deckId,
      'deckName': deckName,
      'timerDuration': timerDuration,
      'attempts': attempts.map((a) => a.toMap()).toList(),
      'playedAt': playedAt.toIso8601String(),
    };
  }

  factory GameRound.fromMap(Map<String, dynamic> map) {
    final name = map['deckName'] as String? ?? '';
    return GameRound(
      id: map['id'] as String?,
      deckId: map['deckId'] as String? ?? name,
      deckName: name,
      timerDuration: (map['timerDuration'] as num?)?.toInt() ?? 60,
      attempts: (map['attempts'] as List<dynamic>?)
              ?.map((a) => WordAttempt.fromMap(a as Map<String, dynamic>))
              .toList() ??
          [],
      playedAt: map['playedAt'] != null
          ? DateTime.tryParse(map['playedAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory GameRound.fromJson(String source) =>
      GameRound.fromMap(json.decode(source) as Map<String, dynamic>);
}

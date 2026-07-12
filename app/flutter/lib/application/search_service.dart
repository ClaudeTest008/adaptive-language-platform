/// Search platform V2 (ADR-0013): provider abstraction. The interface is
/// the seam — [ClientSearchService] formalizes today's in-memory search;
/// an external engine (Algolia/Typesense/semantic embeddings) implements
/// the same contract when scale demands it (trigger in
/// docs/architecture/05).
library;

import '../domain/models.dart';
import 'quality_engine.dart';

enum SearchEntity { question, topic, tag, learningObjective, importJob }

class SearchHit {
  const SearchHit({
    required this.entity,
    required this.id,
    required this.title,
    required this.score,
  });

  final SearchEntity entity;
  final String id;
  final String title;

  /// Relevance 0..1, provider-defined.
  final double score;
}

abstract class SearchService {
  Future<List<SearchHit>> search(String query, {int limit = 20});

  /// Similarity search — duplicate detection and "related questions".
  Future<List<SearchHit>> findSimilar(Question question, {int limit = 5});
}

/// In-memory implementation over the current content set. Token-overlap
/// relevance; adequate below ~5k questions per exam.
class ClientSearchService implements SearchService {
  ClientSearchService({
    required this.questions,
    required this.topics,
    this.importJobs = const [],
  });

  final List<Question> questions;
  final List<Topic> topics;
  final List<ImportJob> importJobs;

  @override
  Future<List<SearchHit>> search(String query, {int limit = 20}) async {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final hits = <SearchHit>[];

    for (final question in questions) {
      var score = 0.0;
      if (question.text.toLowerCase().contains(q)) score = 1.0;
      if (question.explanation.toLowerCase().contains(q)) {
        score = score < 0.7 ? 0.7 : score;
      }
      if (question.tags.any((t) => t.toLowerCase().contains(q))) {
        score = score < 0.6 ? 0.6 : score;
      }
      if (question.learningObjective?.toLowerCase().contains(q) ?? false) {
        hits.add(
          SearchHit(
            entity: SearchEntity.learningObjective,
            id: question.id,
            title: question.learningObjective!,
            score: 0.8,
          ),
        );
      }
      if (score > 0) {
        hits.add(
          SearchHit(
            entity: SearchEntity.question,
            id: question.id,
            title: question.text,
            score: score,
          ),
        );
      }
    }
    for (final t in topics) {
      if (t.name.toLowerCase().contains(q)) {
        hits.add(
          SearchHit(
            entity: SearchEntity.topic,
            id: t.id,
            title: t.name,
            score: 0.9,
          ),
        );
      }
    }
    for (final j in importJobs) {
      if (j.format.toLowerCase().contains(q) ||
          (j.author?.toLowerCase().contains(q) ?? false)) {
        hits.add(
          SearchHit(
            entity: SearchEntity.importJob,
            id: j.id,
            title: '${j.format} import · ${j.imported} questions',
            score: 0.5,
          ),
        );
      }
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    return hits.take(limit).toList();
  }

  @override
  Future<List<SearchHit>> findSimilar(
    Question question, {
    int limit = 5,
  }) async {
    final scored = [
      for (final other in questions)
        if (other.id != question.id)
          (other, textSimilarity(question.text, other.text)),
    ]..sort((a, b) => b.$2.compareTo(a.$2));
    return [
      for (final (other, sim) in scored.take(limit))
        if (sim > 0.2)
          SearchHit(
            entity: SearchEntity.question,
            id: other.id,
            title: other.text,
            score: sim,
          ),
    ];
  }
}

/// In-memory content-review store (ADR-0025 / ADR-0006 demo mode).
library;

import '../language/ingestion.dart';

class InMemoryContentReviewRepository implements ContentReviewRepository {
  ContentReviewLog _log = const ContentReviewLog();

  @override
  Future<ContentReviewLog> load() async => _log;

  @override
  Future<void> save(ContentReviewLog log) async => _log = log;
}

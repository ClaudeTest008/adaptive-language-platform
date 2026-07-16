/// In-memory demo implementations of the language persistence seams
/// (ADR-0006 demo mode; Firestore shapes in docs/database/05).
library;

import '../language/misconceptions.dart';
import '../language/signals.dart';

class InMemoryMisconceptionRepository implements MisconceptionRepository {
  MisconceptionLog _log = const MisconceptionLog();

  @override
  Future<MisconceptionLog> load() async => _log;

  @override
  Future<void> save(MisconceptionLog log) async => _log = log;
}

class InMemoryLanguageSignalsRepository implements LanguageSignalsRepository {
  LanguageSignalsStore _store = const LanguageSignalsStore();

  @override
  Future<LanguageSignalsStore> load() async => _store;

  @override
  Future<void> save(LanguageSignalsStore store) async => _store = store;
}

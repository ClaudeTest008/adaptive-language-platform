/// Learner model persistence seam (ADR-0008). Demo: in-memory. Production:
/// Firestore `learnerModels/{uid}` with concept subcollection —
/// serialization lands with the Firestore implementation
/// (docs/database/04-adaptive-schema.md).
library;

import 'model.dart';

abstract class LearnerModelRepository {
  Future<LearnerModel> load();
  Future<void> save(LearnerModel model);
}

class InMemoryLearnerModelRepository implements LearnerModelRepository {
  LearnerModel _model = const LearnerModel();

  @override
  Future<LearnerModel> load() async => _model;

  @override
  Future<void> save(LearnerModel model) async => _model = model;
}

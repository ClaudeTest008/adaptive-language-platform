/// Large-import engine (ADR-0011): chunked, resumable, non-blocking
/// processing for 10k+ row imports. Runs in-app today (yields to the
/// event loop between chunks so the UI never freezes); the same stage
/// contract moves to Cloud Functions workers for 100k+ scale.
///
/// Output is [QuestionCandidate]s with quality reports — large imports
/// land in the review queue, never directly in the content library.
library;

import '../domain/models.dart';
import '../domain/repositories.dart';
import 'import_pipeline.dart';
import 'quality_engine.dart';

class LargeImportProgress {
  const LargeImportProgress({
    required this.processed,
    required this.total,
    required this.saved,
    required this.rejected,
    required this.duplicates,
    required this.done,
    this.failed = false,
    this.checkpoint,
  });

  final int processed;
  final int total;
  final int saved;
  final int rejected;
  final int duplicates;
  final bool done;
  final bool failed;

  /// Present on failure — pass back to [runLargeImport] to resume.
  final LargeImportCheckpoint? checkpoint;

  double get fraction => total == 0 ? 1 : processed / total;
}

/// Resume + rollback state: which chunk to continue from and which
/// candidates this run already saved (partial success is preserved).
class LargeImportCheckpoint {
  const LargeImportCheckpoint({
    required this.nextIndex,
    required this.savedCandidateIds,
  });

  final int nextIndex;
  final List<String> savedCandidateIds;
}

/// Removes candidates saved by a (possibly partial) import run.
Future<void> rollbackLargeImport(
  AdminRepository repo,
  LargeImportCheckpoint checkpoint,
) => repo.removeCandidates(checkpoint.savedCandidateIds);

Stream<LargeImportProgress> runLargeImport({
  required String content,
  required ImportFormat format,
  required String examId,
  required List<Topic> topics,
  required List<Question> existing,
  required AdminRepository repo,
  String? author,
  int chunkSize = 250,
  LargeImportCheckpoint? resumeFrom,

  /// Test seam: fails the run once when saving the chunk containing this
  /// index, proving resume-after-failure. Never set in production code.
  int? failAtIndex,
}) async* {
  // Stage 1: parse + validate + dedupe (single pass — linear and fast
  // even at 10k rows; the expensive part is persistence, which chunks).
  final report = runImportPipeline(
    content: content,
    format: format,
    examId: examId,
    topics: topics,
    existing: existing,
    author: author,
  );
  final rejectedRows = {
    for (final issue in report.errors)
      if (issue.row > 0) issue.row,
  }.length;

  final candidates = [
    for (final q in report.questions)
      QuestionCandidate(
        id: 'cand-${q.id}',
        question: q,
        source: CandidateSource.import,
        quality: assessQuality(q, existing: existing),
        createdAt: DateTime.now(),
      ),
  ];

  final total = candidates.length;
  var index = resumeFrom?.nextIndex ?? 0;
  final savedIds = List<String>.of(resumeFrom?.savedCandidateIds ?? const []);
  var failedOnce = false;

  while (index < total) {
    final end = (index + chunkSize) > total ? total : index + chunkSize;
    final chunk = candidates.sublist(index, end);
    if (failAtIndex != null &&
        !failedOnce &&
        failAtIndex >= index &&
        failAtIndex < end) {
      failedOnce = true;
      yield LargeImportProgress(
        processed: index,
        total: total,
        saved: savedIds.length,
        rejected: rejectedRows,
        duplicates: report.duplicateCount,
        done: false,
        failed: true,
        checkpoint: LargeImportCheckpoint(
          nextIndex: index,
          savedCandidateIds: savedIds,
        ),
      );
      return;
    }
    await repo.saveCandidates(chunk);
    savedIds.addAll([for (final c in chunk) c.id]);
    index = end;
    yield LargeImportProgress(
      processed: index,
      total: total,
      saved: savedIds.length,
      rejected: rejectedRows,
      duplicates: report.duplicateCount,
      done: false,
    );
    // Yield to the event loop — UI stays responsive during huge imports.
    await Future<void>.delayed(Duration.zero);
  }

  await repo.recordImportJob(
    ImportJob(
      id: 'large-${DateTime.now().microsecondsSinceEpoch}',
      startedAt: DateTime.now(),
      format: '${format.name}-large',
      rowsTotal: total + rejectedRows,
      imported: savedIds.length,
      rejected: rejectedRows,
      duplicates: report.duplicateCount,
      durationMs: 0,
      author: author,
    ),
  );
  yield LargeImportProgress(
    processed: total,
    total: total,
    saved: savedIds.length,
    rejected: rejectedRows,
    duplicates: report.duplicateCount,
    done: true,
    checkpoint: LargeImportCheckpoint(
      nextIndex: total,
      savedCandidateIds: savedIds,
    ),
  );
}

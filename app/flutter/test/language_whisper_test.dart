import 'package:adaptive_exam_platform/language/entities.dart';
import 'package:adaptive_exam_platform/language/reasoning_engine.dart';
import 'package:adaptive_exam_platform/language/relationships.dart';
import 'package:adaptive_exam_platform/language/speaking_session.dart';
import 'package:adaptive_exam_platform/language/teacher_brain.dart';
import 'package:adaptive_exam_platform/language/whisper/whisper_model_manager.dart';
import 'package:adaptive_exam_platform/language/whisper/whisper_pipeline.dart';
import 'package:adaptive_exam_platform/language/whisper/whisper_repository.dart';
import 'package:adaptive_exam_platform/language/whisper/whisper_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// A downloader whose behaviour the tests control.
class FakeDownloader implements ModelDownloader {
  FakeDownloader({this.ok = true, this.throwOn = false});
  bool ok;
  bool throwOn;
  final List<double> progress = [];
  bool deleted = false;

  @override
  Future<String> download(String url,
      {required void Function(double) onProgress}) async {
    if (throwOn) throw Exception('network down');
    onProgress(0.5);
    onProgress(1.0);
    progress
      ..add(0.5)
      ..add(1.0);
    return '/models/whisper';
  }

  @override
  Future<bool> verify(String path, {required int expectedBytes}) async => ok;

  @override
  Future<void> delete(String path) async => deleted = true;
}

void main() {
  group('WhisperModelManager', () {
    test('absent → download → verify → ready, progress reported', () async {
      final repo = InMemoryWhisperModelRepository();
      final dl = FakeDownloader();
      final mgr = WhisperModelManager(repository: repo, downloader: dl);

      expect((await mgr.status()).status, WhisperModelStatus.absent);
      final states = <WhisperModelStatus>[];
      final result = await mgr.ensureDownloaded(
        onState: (s) => states.add(s.status),
      );
      expect(result.isReady, isTrue);
      expect(dl.progress, isNotEmpty);
      expect(states, contains(WhisperModelStatus.downloading));
      expect(states, contains(WhisperModelStatus.verifying));
      // Persisted: a second manager sees it ready without redownloading.
      final mgr2 = WhisperModelManager(
        repository: repo,
        downloader: FakeDownloader(throwOn: true),
      );
      expect((await mgr2.status()).isReady, isTrue);
    });

    test('failed verification surfaces an error, not a ready model', () async {
      final mgr = WhisperModelManager(
        repository: InMemoryWhisperModelRepository(),
        downloader: FakeDownloader(ok: false),
      );
      final r = await mgr.ensureDownloaded();
      expect(r.status, WhisperModelStatus.error);
    });

    test('download exception is caught and reported', () async {
      final mgr = WhisperModelManager(
        repository: InMemoryWhisperModelRepository(),
        downloader: FakeDownloader(throwOn: true),
      );
      final r = await mgr.ensureDownloaded();
      expect(r.status, WhisperModelStatus.error);
      expect(r.error, contains('network'));
    });

    test('a stale model version reads as absent (never reused)', () async {
      final repo = InMemoryWhisperModelRepository();
      await repo.save(const WhisperModelInfo(
        version: 'old-version',
        sizeBytes: 100,
        path: '/x',
      ));
      final mgr = WhisperModelManager(
        repository: repo,
        downloader: FakeDownloader(),
      );
      expect((await mgr.status()).status, WhisperModelStatus.absent);
    });

    test('delete removes files and forgets the model', () async {
      final repo = InMemoryWhisperModelRepository();
      final dl = FakeDownloader();
      final mgr = WhisperModelManager(repository: repo, downloader: dl);
      await mgr.ensureDownloaded();
      await mgr.delete();
      expect(dl.deleted, isTrue);
      expect(await repo.load(), isNull);
    });
  });

  group('speaking analytics', () {
    test('measures pronunciation, fluency, hesitation, confidence', () {
      final s = analyzeSpeaking(
        'tengo hambre',
        'eh tengo tengo hambre',
        durationMs: 2000,
        retries: 1,
      );
      expect(s.completed, isTrue);
      expect(s.fillerCount, 1); // "eh"
      expect(s.hesitationCount, greaterThanOrEqualTo(2)); // filler + repeat
      expect(s.fluency, isNotNull);
      expect(s.confidence, isNotNull);
      expect(s.repairAttempts, 1);
    });

    test('no utterance → not completed, confidence null (nothing invented)',
        () {
      final s = analyzeSpeaking('hola', '');
      expect(s.completed, isFalse);
      expect(s.confidence, isNull);
      expect(s.fluency, isNull);
    });

    test('fluency null without duration', () {
      final s = analyzeSpeaking('hola', 'hola');
      expect(s.fluency, isNull);
    });

    test('speaking outcome derives from the session', () {
      final s = analyzeSpeaking('tengo hambre', 'tengo hambre',
          durationMs: 1000);
      final o = speakingOutcome(s, '2026-07-18');
      expect(o.objective, contains('tengo hambre'));
      expect(o.score, s.pronunciation);
    });
  });

  group('connection-based feedback', () {
    TeacherBrainHarness harness() => TeacherBrainHarness();

    test('names the family when the utterance belongs to one', () {
      final brain = harness().brain;
      final session = analyzeSpeaking(
        'tengo hambre',
        'tengo hambre',
        conceptId: 'es:a1:grammar:tener:hambre',
      );
      final fb = connectionFeedback(session, brain);
      expect(fb, isNotNull);
      expect(fb, contains('same pattern'));
    });

    test('no connection, no fabricated link', () {
      final brain = harness().brain;
      final session = analyzeSpeaking('hola', 'hola', conceptId: 'es:x:y');
      expect(connectionFeedback(session, brain), isNull);
    });
  });

  group('WhisperPipeline + fallback service', () {
    test('captures a scripted utterance into a session', () async {
      final pipeline = WhisperPipeline(
        NoopWhisperService(scripted: 'tengo hambre'),
      );
      final session = await pipeline.capture(
        target: 'tengo hambre',
        langCode: 'es-ES',
        conceptId: 'es:a1:grammar:tener:hambre',
      );
      expect(session, isNotNull);
      expect(session!.completed, isTrue);
    });

    test('null when nothing recognized', () async {
      final pipeline = WhisperPipeline(NoopWhisperService(scripted: null));
      expect(
        await pipeline.capture(target: 'x', langCode: 'es-ES'),
        isNull,
      );
    });

    test('feedbackFor prefers a connection, else honest fallback', () {
      final brain = TeacherBrainHarness().brain;
      final good = analyzeSpeaking(
        'tengo hambre',
        'tengo hambre',
        conceptId: 'es:a1:grammar:tener:hambre',
      );
      expect(feedbackFor(good, brain), contains('same pattern'));
      final empty = analyzeSpeaking('hola', '');
      expect(feedbackFor(empty, brain), contains("didn't catch"));
    });
  });
}

/// Builds a brain with a tener family cluster for feedback tests.
class TeacherBrainHarness {
  TeacherBrainHarness()
      : brain = const OfflineReasoningEngine().assemble(
          BrainInputs(
            today: _fixedDay,
            nativeLanguage: 'en',
            targetLanguage: 'es',
            targetLanguageName: 'Spanish',
            baseLevel: 'A1',
            longTermGoal: 'Reach A2 Spanish',
            skillMastery: {LanguageSkill.grammar: 0.6},
            conceptMastery: {
              'es:a1:grammar:tener:hambre': 0.9,
              'es:a1:grammar:tener:sueno': 0.8,
              'es:a1:grammar:tener:miedo': 0.7,
            },
            conceptNames: {
              'es:a1:grammar:tener:hambre': 'tener hambre',
              'es:a1:grammar:tener:sueno': 'tener sueño',
              'es:a1:grammar:tener:miedo': 'tener miedo',
            },
            misconceptions: [],
            accuracy: 0.6,
            totalAnswered: 30,
            learningDna: [],
            historyDays: [],
            vocabularyPoolSize: 100,
            relations: [
              LanguageRelation(
                from: 'es:a1:grammar:tener:hambre',
                to: 'es:a1:grammar:tener:sueno',
                type: LanguageRelationType.relatedTo,
              ),
            ],
          ),
        );

  static final _fixedDay = DateTime(2026, 7, 18);
  final TeacherBrain brain;
}

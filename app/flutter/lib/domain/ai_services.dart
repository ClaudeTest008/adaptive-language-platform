/// AI platform foundations (ADR-0008): provider-independent interfaces
/// only — NO implementations in this milestone. Future providers
/// (Anthropic, OpenAI, Gemini, local models) implement these behind DI;
/// application code depends solely on the interfaces. All AI-generated
/// content requires human review before publication (Content Studio
/// approval workflow).
library;

import 'models.dart';

/// Marker for every AI capability; `isAvailable` lets UI degrade
/// gracefully while no provider is configured.
abstract class AiService {
  bool get isAvailable;
}

abstract class AiTutor implements AiService {
  /// Conversational help grounded in a specific question and the
  /// learner's answer.
  Future<String> explainMistake({
    required Question question,
    required int selectedIndex,
  });
}

abstract class AiStudyCoach implements AiService {
  /// Natural-language coaching from learner analytics (input is a
  /// pre-serialized summary so the interface stays model-agnostic).
  Future<String> coach({required String learnerSummary});
}

abstract class AiExplanationGenerator implements AiService {
  Future<String> generateExplanation(Question question);
}

abstract class AiQuestionGenerator implements AiService {
  /// Draft questions for a topic; output enters the import pipeline as
  /// drafts and passes the same validation + human approval as any import.
  Future<List<Question>> generateQuestions({
    required Topic topic,
    required int count,
    required Difficulty difficulty,
  });
}

abstract class AiDocumentExtractor implements AiService {
  /// Extracts candidate questions from raw document text (PDF/Word
  /// pipelines feed text in; extraction output enters the import pipeline).
  Future<List<Map<String, String>>> extractQuestions(String documentText);
}

abstract class AiTranslator implements AiService {
  Future<Question> translate(Question question, String targetLanguage);
}

abstract class AiDifficultyEstimator implements AiService {
  Future<Difficulty> estimate(Question question);
}

abstract class AiDuplicateDetector implements AiService {
  /// Semantic duplicate detection beyond the pipeline's text
  /// normalization; returns ids of likely duplicates within [candidates].
  Future<List<String>> findDuplicates(
    Question question,
    List<Question> candidates,
  );
}

abstract class AiOcr implements AiService {
  /// Extracts text from image bytes (scanned PDFs, photographed handbooks);
  /// output feeds [AiDocumentExtractor] and then the import pipeline.
  Future<String> recognizeText(List<int> imageBytes);
}

/// Structured review of one question's quality.
class AiContentReview {
  const AiContentReview({
    required this.qualityScore,
    required this.issues,
    required this.suggestions,
  });

  /// 0..1 — admin analytics surface this next to accuracy metrics.
  final double qualityScore;
  final List<String> issues;
  final List<String> suggestions;
}

abstract class AiContentReviewer implements AiService {
  Future<AiContentReview> review(Question question);
}

/// Suggested metadata for a question; every field optional — admins
/// accept or discard per field in Content Studio before anything persists.
class AiSuggestedMetadata {
  const AiSuggestedMetadata({
    this.topicId,
    this.subtopic,
    this.learningObjective,
    this.difficulty,
    this.tags = const [],
  });

  final String? topicId;
  final String? subtopic;
  final String? learningObjective;
  final Difficulty? difficulty;
  final List<String> tags;
}

abstract class AiMetadataGenerator implements AiService {
  /// Topic classification, learning-objective detection, difficulty
  /// estimation and tagging in one pass over the question content.
  Future<AiSuggestedMetadata> suggestMetadata(
    Question question,
    List<Topic> topics,
  );
}

class Flashcard {
  const Flashcard({required this.front, required this.back});

  final String front;
  final String back;
}

abstract class AiFlashcardGenerator implements AiService {
  /// Flashcards grounded in existing approved content (question +
  /// explanation pairs) — output enters the review queue like all AI
  /// content.
  Future<List<Flashcard>> generateFlashcards(
    List<Question> sourceQuestions, {
    int count = 10,
  });
}

abstract class AiSummarizer implements AiService {
  /// Concept or document summaries for study guides.
  Future<String> summarize(String text, {int maxSentences = 5});
}

abstract class AiStudyMaterialGenerator implements AiService {
  /// Lesson text for a topic, grounded in its questions/explanations.
  Future<String> generateLesson(Topic topic, List<Question> grounding);

  /// Exam blueprint: topic weighting + difficulty distribution proposal.
  Future<String> generateExamBlueprint(
    List<Topic> topics,
    Map<String, int> questionCounts,
  );
}

abstract class AiQuestionImprover implements AiService {
  /// Concrete rewrite suggestions for a question given its quality
  /// issues; applying a suggestion is a normal versioned edit (human act).
  Future<List<String>> suggestImprovements(
    Question question,
    List<String> qualityIssues,
  );
}

abstract class AiKnowledgeGraphBuilder implements AiService {
  /// Proposes prerequisite/related edges between concept ids. Proposals
  /// are review-gated before entering the authored graph overrides
  /// (`conceptGraph` document, docs/database/04).
  Future<Map<String, List<String>>> proposeRelations(
    List<String> conceptIds,
    String contextText,
  );
}

/// Registry resolved via DI; every capability is optional.
class AiServices {
  const AiServices({
    this.tutor,
    this.coach,
    this.explanationGenerator,
    this.questionGenerator,
    this.documentExtractor,
    this.translator,
    this.difficultyEstimator,
    this.duplicateDetector,
    this.ocr,
    this.contentReviewer,
    this.metadataGenerator,
    this.flashcardGenerator,
    this.summarizer,
    this.studyMaterialGenerator,
    this.questionImprover,
    this.knowledgeGraphBuilder,
  });

  /// No providers configured — the V1 state.
  static const none = AiServices();

  final AiTutor? tutor;
  final AiStudyCoach? coach;
  final AiExplanationGenerator? explanationGenerator;
  final AiQuestionGenerator? questionGenerator;
  final AiDocumentExtractor? documentExtractor;
  final AiTranslator? translator;
  final AiDifficultyEstimator? difficultyEstimator;
  final AiDuplicateDetector? duplicateDetector;
  final AiOcr? ocr;
  final AiContentReviewer? contentReviewer;
  final AiMetadataGenerator? metadataGenerator;
  final AiFlashcardGenerator? flashcardGenerator;
  final AiSummarizer? summarizer;
  final AiStudyMaterialGenerator? studyMaterialGenerator;
  final AiQuestionImprover? questionImprover;
  final AiKnowledgeGraphBuilder? knowledgeGraphBuilder;
}

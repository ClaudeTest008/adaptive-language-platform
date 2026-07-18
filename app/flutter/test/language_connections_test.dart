import 'package:adaptive_exam_platform/language/connections.dart';
import 'package:adaptive_exam_platform/language/entities.dart';
import 'package:adaptive_exam_platform/language/notebook.dart';
import 'package:adaptive_exam_platform/language/reasoning_engine.dart';
import 'package:adaptive_exam_platform/language/relationships.dart';
import 'package:adaptive_exam_platform/language/teacher_brain.dart';
import 'package:adaptive_exam_platform/language/teaching_planner.dart';
import 'package:adaptive_exam_platform/language/tutor.dart';
import 'package:flutter_test/flutter_test.dart';

// A tiny hand-built graph: the learner knows "tener hambre" well; three sibling
// tener expressions and a related concept are connected but not yet met.
const _known = 'es:a1:grammar:tener:hambre';
const _sueno = 'es:a1:grammar:tener:sueno';
const _miedo = 'es:a1:grammar:tener:miedo';

final _relations = <LanguageRelation>[
  const LanguageRelation(
    from: _known,
    to: _sueno,
    type: LanguageRelationType.relatedTo,
  ),
  const LanguageRelation(
    from: _known,
    to: _miedo,
    type: LanguageRelationType.buildsOn,
  ),
];

const _names = {
  _known: 'tener hambre',
  _sueno: 'tener sueño',
  _miedo: 'tener miedo',
};

void main() {
  group('buildConnectionGraph', () {
    test('nodes include known concept and its unmet neighbours', () {
      final g = buildConnectionGraph(
        relations: _relations,
        conceptNames: _names,
        conceptMastery: const {_known: 0.9},
      );
      expect(g.nodes.containsKey(_known), isTrue);
      expect(g.nodes[_known]!.known, isTrue);
      // Neighbours pulled in even though mastery is 0.
      expect(g.nodes.containsKey(_sueno), isTrue);
      expect(g.nodes[_sueno]!.known, isFalse);
    });

    test('classifies hidden connections from known to unmet concepts', () {
      final g = buildConnectionGraph(
        relations: _relations,
        conceptNames: _names,
        conceptMastery: const {_known: 0.9},
      );
      expect(g.hiddenConnections, isNotEmpty);
      expect(g.strongConnections, isEmpty);
    });

    test('suggestion teaches outward from the known anchor', () {
      final g = buildConnectionGraph(
        relations: _relations,
        conceptNames: _names,
        conceptMastery: const {_known: 0.9},
      );
      expect(g.suggestions, isNotEmpty);
      final s = g.suggestions.first;
      expect(s.anchorName, 'tener hambre');
      expect(s.relatedNames, containsAll(['tener sueño', 'tener miedo']));
    });

    test('strong connection when both ends are known', () {
      final g = buildConnectionGraph(
        relations: _relations,
        conceptNames: _names,
        conceptMastery: const {_known: 0.9, _sueno: 0.8, _miedo: 0.7},
      );
      expect(g.strongConnections, isNotEmpty);
      expect(g.hiddenConnections, isEmpty);
    });

    test('does not fabricate: no mastery, no graph', () {
      final g = buildConnectionGraph(
        relations: _relations,
        conceptNames: _names,
        conceptMastery: const {},
      );
      expect(g.nodes, isEmpty);
      expect(g.suggestions, isEmpty);
    });

    test('explainByConnection uses a known neighbour, not a definition', () {
      final g = buildConnectionGraph(
        relations: _relations,
        conceptNames: _names,
        conceptMastery: const {_known: 0.9},
      );
      final explain = explainByConnection(_sueno, g);
      expect(explain, isNotNull);
      expect(explain, contains('tener hambre'));
    });
  });

  group('chooseTeachingStrategy', () {
    TeacherBrain brainWith({
      String? currentConceptId,
      Map<LanguageSkill, double> skills = const {
        LanguageSkill.grammar: 0.6,
        LanguageSkill.speaking: 0.6,
        LanguageSkill.conversation: 0.6,
      },
      Map<String, double> conceptMastery = const {_known: 0.9},
    }) {
      return const OfflineReasoningEngine().assemble(
        BrainInputs(
          today: DateTime(2026, 7, 18),
          nativeLanguage: 'en',
          targetLanguage: 'es',
          targetLanguageName: 'Spanish',
          baseLevel: 'A1',
          longTermGoal: 'Reach A2 Spanish',
          skillMastery: skills,
          conceptMastery: conceptMastery,
          conceptNames: _names,
          misconceptions: const [],
          accuracy: 0.6,
          totalAnswered: 30,
          learningDna: const [],
          historyDays: const [],
          vocabularyPoolSize: 100,
          relations: _relations,
          currentConceptId: currentConceptId,
        ),
      );
    }

    test('repairs the current concept, teaching through its connections', () {
      final choice = chooseTeachingStrategy(brainWith(currentConceptId: _known));
      expect(choice.mode, TutorMode.teacher);
      expect(choice.focusConceptId, _known);
      expect(choice.connection, isNotNull);
    });

    test('gets a lagging speaker talking when no misconception is active', () {
      final choice = chooseTeachingStrategy(
        brainWith(
          skills: const {
            LanguageSkill.grammar: 0.7,
            LanguageSkill.speaking: 0.2,
            LanguageSkill.conversation: 0.2,
          },
        ),
      );
      expect(choice.mode, TutorMode.conversation);
    });

    test('builds outward from a strong anchor when skills are balanced', () {
      final choice = chooseTeachingStrategy(brainWith());
      expect(choice.mode, TutorMode.teacher);
      expect(choice.focusConceptId, _known);
    });
  });

  test('the brain carries a connection observation in the notebook', () {
    final brain = const OfflineReasoningEngine().assemble(
      BrainInputs(
        today: DateTime(2026, 7, 18),
        nativeLanguage: 'en',
        targetLanguage: 'es',
        targetLanguageName: 'Spanish',
        baseLevel: 'A1',
        longTermGoal: 'Reach A2 Spanish',
        skillMastery: const {LanguageSkill.grammar: 0.6},
        conceptMastery: const {_known: 0.9},
        conceptNames: _names,
        misconceptions: [],
        accuracy: 0.6,
        totalAnswered: 30,
        learningDna: [],
        historyDays: [],
        vocabularyPoolSize: 100,
        relations: _relations,
      ),
    );
    final connection = brain.notebook.observations.firstWhere(
      (o) => o.category == ObservationCategory.connection,
    );
    expect(connection.text, contains('tener hambre'));
    expect(connection.conceptIds, contains(_known));
  });
}

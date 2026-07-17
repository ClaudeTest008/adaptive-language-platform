/// Language content ingestion (ADR-0025). Pure Dart.
///
/// Adapts the inherited document-ingestion idea (ADR-0011) for language
/// learning: pasted target-language text is extracted into review
/// CANDIDATES — vocabulary, phrases, example sentences, idioms, cultural
/// notes — tagged with difficulty and topics and mapped to existing
/// curriculum concept ids where possible. Nothing enters the curriculum
/// directly; a human approves candidates first (same review-queue
/// discipline as ADR-0011's QuestionCandidate).
library;

import 'entities.dart';
import 'relationships.dart';

enum ContentKind { vocabulary, phrase, sentence, idiom, culturalNote }

class ContentCandidate {
  const ContentCandidate({
    required this.id,
    required this.kind,
    required this.text,
    this.translation,
    this.conceptId,
    this.note,
  });

  /// Stable within a result: `kind:text`.
  final String id;
  final ContentKind kind;

  /// Target-language surface form.
  final String text;
  final String? translation;

  /// Existing curriculum concept this maps to, if recognized.
  final String? conceptId;

  /// Why it was flagged (idiom source, cultural keyword, …).
  final String? note;

  bool get mapped => conceptId != null;
}

class IngestionResult {
  const IngestionResult({
    required this.languageCode,
    required this.difficulty,
    required this.topics,
    required this.candidates,
  });

  final String languageCode;
  final CefrLevel difficulty;
  final List<String> topics;
  final List<ContentCandidate> candidates;

  List<ContentCandidate> ofKind(ContentKind k) =>
      [for (final c in candidates) if (c.kind == k) c];
}

/// Function words to ignore when counting content vocabulary.
const _stop = {
  'es': {
    'el', 'la', 'los', 'las', 'un', 'una', 'unos', 'unas', 'de', 'del',
    'a', 'al', 'y', 'o', 'que', 'en', 'con', 'por', 'para', 'su', 'sus',
    'es', 'son', 'muy', 'no', 'se', 'lo', 'le', 'me', 'te', 'mi', 'tu',
    'yo', 'tú', 'él', 'ella', 'pero', 'como', 'más', 'ya', 'está', 'este',
    'esta', 'eso', 'esa', 'hay', 'ha', 'he',
  },
  'en': {
    'the', 'a', 'an', 'of', 'to', 'and', 'or', 'that', 'in', 'with', 'for',
    'his', 'her', 'is', 'are', 'very', 'no', 'it', 'he', 'she', 'i', 'you',
    'my', 'your', 'but', 'as', 'more', 'this', 'there', 'has',
    'have', 'was', 'were', 'at', 'on', 'so',
  },
};

/// Seed idioms per language (surface → gloss). A real pipeline grows this
/// from the curriculum's phrase family; the seed makes ingestion useful
/// on day one.
const _idioms = {
  'es': {
    'tener hambre': 'to be hungry',
    'tener sueño': 'to be sleepy',
    'tener frío': 'to be cold',
    'tener calor': 'to be hot',
    'tener miedo': 'to be afraid',
    'tener prisa': 'to be in a hurry',
    'hace frío': "it's cold",
    'hace calor': "it's hot",
    'por favor': 'please',
    'de nada': "you're welcome",
  },
  'en': {
    'how are you': 'greeting',
    'nice to meet you': 'greeting',
  },
};

const _culturalKeywords = {
  'es': {
    'españa': 'Spain', 'sevilla': 'Seville', 'madrid': 'Madrid',
    'siesta': 'afternoon rest', 'tapas': 'small dishes', 'fiesta': 'party',
    'flamenco': 'dance', 'paella': 'rice dish',
  },
  'en': {'london': 'UK', 'meetup': 'social event'},
};

/// Extracts review candidates from [text] in [languageCode], mapping to
/// existing curriculum concepts via [graph]. Deterministic.
IngestionResult ingestLanguageText(
  String text, {
  required LanguageKnowledgeGraph graph,
  required String languageCode,
}) {
  final lang = languageCode.split('-').first.toLowerCase();
  final stop = _stop[lang] ?? const <String>{};
  final sentences = _sentences(text);

  // Known curriculum vocabulary + phrases, folded for matching.
  final vocabByLemma = <String, LanguageNode>{};
  final phraseByText = <String, LanguageNode>{};
  for (final n in graph.nodes.values) {
    if (n is VocabularyConceptNode) vocabByLemma[_fold(n.lemma)] = n;
    if (n is PhraseNode) phraseByText[_fold(n.text)] = n;
  }

  final candidates = <ContentCandidate>[];
  final seen = <String>{};
  void add(ContentCandidate c) {
    if (seen.add(c.id)) candidates.add(c);
  }

  // ── Vocabulary: content words by frequency ──
  final freq = <String, int>{};
  for (final s in sentences) {
    for (final w in _words(s)) {
      if (w.length < 3 || stop.contains(w)) continue;
      freq[w] = (freq[w] ?? 0) + 1;
    }
  }
  final ranked = freq.keys.toList()
    ..sort((a, b) {
      final byFreq = freq[b]!.compareTo(freq[a]!);
      return byFreq != 0 ? byFreq : a.compareTo(b);
    });
  for (final w in ranked.take(12)) {
    final match = vocabByLemma[_fold(w)];
    add(ContentCandidate(
      id: 'vocabulary:$w',
      kind: ContentKind.vocabulary,
      text: w,
      conceptId: match?.conceptId,
      translation:
          match is VocabularyConceptNode ? match.translations.values.firstOrNull : null,
      note: match == null ? 'new word' : 'in curriculum',
    ));
  }

  // ── Idioms: seed phrases present in the text. Match the exact phrase
  // OR its key noun (last word), since idioms appear conjugated/split
  // ("tiene mucha hambre" carries "tener hambre").
  final foldedWords = _words(_fold(text)).toSet();
  (_idioms[lang] ?? const {}).forEach((phrase, gloss) {
    final f = _fold(phrase);
    final keyWord = f.split(' ').last;
    if (_fold(text).contains(f) || foldedWords.contains(keyWord)) {
      final match = phraseByText[f];
      add(ContentCandidate(
        id: 'idiom:$phrase',
        kind: ContentKind.idiom,
        text: phrase,
        translation: gloss,
        conceptId: match?.conceptId,
        note: 'idiom',
      ));
    }
  });

  // ── Phrases: content-word bigrams (excluding idioms already caught) ──
  for (final s in sentences) {
    final ws = _words(s).where((w) => w.length >= 3 && !stop.contains(w)).toList();
    for (var i = 0; i + 1 < ws.length; i++) {
      final bigram = '${ws[i]} ${ws[i + 1]}';
      if ((_idioms[lang] ?? const {}).containsKey(bigram)) continue;
      add(ContentCandidate(
        id: 'phrase:$bigram',
        kind: ContentKind.phrase,
        text: bigram,
        conceptId: phraseByText[_fold(bigram)]?.conceptId,
      ));
      if (candidates.where((c) => c.kind == ContentKind.phrase).length >= 8) {
        break;
      }
    }
  }

  // ── Example sentences: learnable-length sentences ──
  for (final s in sentences) {
    final n = s.split(RegExp(r'\s+')).length;
    if (n >= 3 && n <= 14) {
      add(ContentCandidate(
        id: 'sentence:$s',
        kind: ContentKind.sentence,
        text: s,
      ));
    }
    if (candidates.where((c) => c.kind == ContentKind.sentence).length >= 8) {
      break;
    }
  }

  // ── Cultural notes: sentences mentioning cultural keywords ──
  final keywords = _culturalKeywords[lang] ?? const {};
  for (final s in sentences) {
    final low = _fold(s);
    for (final entry in keywords.entries) {
      if (low.contains(entry.key)) {
        add(ContentCandidate(
          id: 'culturalNote:${entry.key}:$s',
          kind: ContentKind.culturalNote,
          text: s,
          note: entry.value,
        ));
        break;
      }
    }
  }

  return IngestionResult(
    languageCode: lang,
    difficulty: _difficulty(sentences),
    topics: ranked.take(4).toList(),
    candidates: candidates,
  );
}

/// CEFR estimate from average sentence + word length.
CefrLevel _difficulty(List<String> sentences) {
  if (sentences.isEmpty) return CefrLevel.a1;
  final wordsPer = sentences
          .map((s) => s.split(RegExp(r'\s+')).length)
          .fold(0, (a, b) => a + b) /
      sentences.length;
  final allWords = sentences.expand((s) => _words(s)).toList();
  final avgLen = allWords.isEmpty
      ? 0
      : allWords.map((w) => w.length).fold(0, (a, b) => a + b) / allWords.length;
  if (wordsPer <= 8 && avgLen <= 5.2) return CefrLevel.a1;
  if (wordsPer <= 13 && avgLen <= 6.2) return CefrLevel.a2;
  return CefrLevel.b1;
}

List<String> _sentences(String text) => text
    .replaceAll('\n', ' ')
    .split(RegExp(r'(?<=[.!?])\s+'))
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toList();

List<String> _words(String s) => s
    .toLowerCase()
    .split(RegExp(r'[^a-záéíóúüñ]+'))
    .where((w) => w.isNotEmpty)
    .toList();

String _fold(String s) {
  const map = {
    'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u', 'ñ': 'n',
  };
  final buf = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    buf.write(map[ch] ?? ch);
  }
  return buf.toString();
}

/// Review queue: approved/rejected candidate ids. Immutable.
class ContentReviewLog {
  const ContentReviewLog({this.approved = const {}, this.rejected = const {}});

  final Set<String> approved;
  final Set<String> rejected;

  bool isPending(String id) => !approved.contains(id) && !rejected.contains(id);

  ContentReviewLog approve(String id) => ContentReviewLog(
    approved: {...approved, id},
    rejected: rejected.difference({id}),
  );
  ContentReviewLog reject(String id) => ContentReviewLog(
    approved: approved.difference({id}),
    rejected: {...rejected, id},
  );
}

/// Persistence seam (ADR-0006 demo mode; Firestore shapes Phase 8).
abstract class ContentReviewRepository {
  Future<ContentReviewLog> load();
  Future<void> save(ContentReviewLog log);
}

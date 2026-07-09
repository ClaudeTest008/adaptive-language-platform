/// Document ingestion (ADR-0011): text extraction + structure detection
/// for TXT and HTML — deterministic, no AI required. Chapter/topic
/// detection feeds knowledge-graph candidates; flagged sentences become
/// question opportunities for AI generation (which requires a bound
/// provider and always lands in the review queue).
///
/// PDF/DOCX/scans: same [extractText] entry point; their parsers are
/// binary-format adapters that land with the Storage upload pipeline
/// (deferred — ADR-0011).
library;

enum DocumentFormat { txt, html }

class DocumentChapter {
  const DocumentChapter({
    required this.title,
    required this.body,
    required this.questionOpportunities,
  });

  final String title;
  final String body;

  /// Fact-dense sentences — candidate inputs for question generation.
  final List<String> questionOpportunities;
}

class IngestedDocument {
  const IngestedDocument({required this.chapters});

  final List<DocumentChapter> chapters;

  /// Topic candidates for the knowledge graph: one per chapter.
  List<String> get topicCandidates => [for (final c in chapters) c.title];

  int get opportunityCount =>
      chapters.fold(0, (sum, c) => sum + c.questionOpportunities.length);
}

/// Strips HTML to plain text, marking headings so chapter detection works
/// on both formats. ponytail: regex-based, sufficient for study-guide
/// HTML; swap for an HTML parser package if malformed markup surfaces.
String extractText(String raw, DocumentFormat format) {
  if (format == DocumentFormat.txt) return raw;
  var text = raw
      .replaceAll(RegExp(r'<script[\s\S]*?</script>', caseSensitive: false), '')
      .replaceAll(RegExp(r'<style[\s\S]*?</style>', caseSensitive: false), '');
  // Headings become markdown-style markers.
  text = text.replaceAllMapped(
    RegExp(r'<h[1-3][^>]*>([\s\S]*?)</h[1-3]>', caseSensitive: false),
    (m) => '\n# ${m[1]!.replaceAll(RegExp(r'<[^>]+>'), '').trim()}\n',
  );
  text = text
      .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>');
  return text;
}

/// Chapter detection heuristics: markdown-style `#` markers (from HTML
/// headings), `Chapter N` lines, ALL-CAPS short lines, or numbered
/// section titles. Content before the first heading becomes
/// "Introduction".
IngestedDocument ingestDocument(String raw, DocumentFormat format) {
  final text = extractText(raw, format);
  final lines = text.split('\n');

  bool isHeading(String line) {
    final t = line.trim();
    if (t.isEmpty || t.length > 80) return false;
    if (t.startsWith('# ')) return true;
    if (RegExp(
      r'^(chapter|section|unit|part)\s+\d+',
      caseSensitive: false,
    ).hasMatch(t)) {
      return true;
    }
    if (RegExp(r'^\d+(\.\d+)*\.?\s+\S').hasMatch(t) && t.length < 60) {
      return true;
    }
    // ALL CAPS short line with at least two words.
    if (t == t.toUpperCase() &&
        RegExp(r'[A-Z]').hasMatch(t) &&
        t.split(RegExp(r'\s+')).length >= 2 &&
        !t.endsWith('.')) {
      return true;
    }
    return false;
  }

  String cleanTitle(String line) => line
      .trim()
      .replaceFirst(RegExp(r'^#\s*'), '')
      .replaceFirst(
        RegExp(
          r'^(chapter|section|unit|part)\s+\d+\s*[:.\-]?\s*',
          caseSensitive: false,
        ),
        '',
      )
      .replaceFirst(RegExp(r'^\d+(\.\d+)*\.?\s*'), '')
      .trim();

  final chapters = <DocumentChapter>[];
  var title = 'Introduction';
  var body = StringBuffer();

  void flush() {
    final content = body.toString().trim();
    if (content.isNotEmpty) {
      chapters.add(
        DocumentChapter(
          title: title,
          body: content,
          questionOpportunities: _findOpportunities(content),
        ),
      );
    }
    body = StringBuffer();
  }

  for (final line in lines) {
    if (isHeading(line)) {
      flush();
      title = cleanTitle(line);
    } else {
      body.writeln(line);
    }
  }
  flush();
  return IngestedDocument(chapters: chapters);
}

/// Fact-dense sentences: contain a definition/rule signal or a number,
/// and are long enough to carry a testable fact.
List<String> _findOpportunities(String body) {
  final sentences = body
      .replaceAll('\n', ' ')
      .split(RegExp(r'(?<=[.!?])\s+'))
      .map((s) => s.trim())
      .where((s) => s.split(RegExp(r'\s+')).length >= 5)
      .toList();
  final signal = RegExp(
    r'\b(must|means|is defined as|requires?|prohibited|allowed|'
    r'always|never|within|at least|maximum|minimum)\b|\d',
    caseSensitive: false,
  );
  return sentences.where(signal.hasMatch).toList();
}

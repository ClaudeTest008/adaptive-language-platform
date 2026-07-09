/// Bulk import pipeline (ADR-0007): parse → schema validation → question
/// validation → duplicate detection → topic mapping → preview report.
/// Pure Dart, unit-tested. Nothing is imported while blocking issues remain.
library;

import 'dart:convert';

import '../domain/models.dart';

enum ImportFormat { csv, json }

class ImportIssue {
  const ImportIssue({
    required this.row,
    required this.message,
    this.blocking = true,
  });

  /// 1-based data row (0 = file-level issue).
  final int row;
  final String message;
  final bool blocking;

  @override
  String toString() => '${blocking ? "ERROR" : "WARN "} row $row: $message';
}

class ImportReport {
  const ImportReport({required this.questions, required this.issues});

  /// Questions that passed validation (importable once no blocking issues).
  final List<Question> questions;
  final List<ImportIssue> issues;

  List<ImportIssue> get errors => issues.where((i) => i.blocking).toList();
  List<ImportIssue> get warnings => issues.where((i) => !i.blocking).toList();
  bool get canImport => errors.isEmpty && questions.isNotEmpty;
}

/// CSV columns (header row required, case-insensitive):
/// question,answerA,answerB,answerC,answerD,correct,explanation,topic
/// [,difficulty,tags,subtopic,learningObjective,references]
const csvTemplate =
    'question,answerA,answerB,answerC,answerD,correct,explanation,topic,'
    'difficulty,tags\n'
    '"What does a red octagon mean?","Yield","Stop","Merge","Slow down",B,'
    '"Octagon is reserved for STOP signs.","Road Signs",easy,"signs,basics"';

ImportReport runImportPipeline({
  required String content,
  required ImportFormat format,
  required String examId,
  required List<Topic> topics,
  required List<Question> existing,
  String? author,
}) {
  final issues = <ImportIssue>[];

  // Stage 1-2: parse + schema validation.
  final List<Map<String, String>> rows;
  try {
    rows = format == ImportFormat.csv
        ? _parseCsvRows(content, issues)
        : _parseJsonRows(content, issues);
  } on FormatException catch (e) {
    return ImportReport(
      questions: const [],
      issues: [ImportIssue(row: 0, message: 'File invalid: ${e.message}')],
    );
  }
  if (rows.isEmpty && issues.isEmpty) {
    issues.add(const ImportIssue(row: 0, message: 'No data rows found.'));
  }

  // Topic mapping: name or id, case-insensitive.
  final topicByKey = {
    for (final t in topics) t.id.toLowerCase(): t,
    for (final t in topics) t.name.toLowerCase(): t,
  };

  // Duplicate detection: normalized question text, within batch and
  // against existing (non-archived) content.
  String norm(String s) =>
      s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  final existingTexts = {
    for (final q in existing)
      if (q.status != ContentStatus.archived) norm(q.text),
  };
  final seenInBatch = <String>{};

  final questions = <Question>[];
  var rowNum = 0;
  for (final row in rows) {
    rowNum++;
    final rowIssues = <ImportIssue>[];
    void err(String m) => rowIssues.add(ImportIssue(row: rowNum, message: m));
    void warn(String m) =>
        rowIssues.add(ImportIssue(row: rowNum, message: m, blocking: false));

    // Stage 3: question validation.
    final text = (row['question'] ?? '').trim();
    if (text.isEmpty) err('Missing question text.');

    final answers = [
      for (final k in ['answera', 'answerb', 'answerc', 'answerd'])
        (row[k] ?? '').trim(),
    ].where((a) => a.isNotEmpty).toList();
    if (answers.length < 2) err('Fewer than 2 answers.');

    final correctRaw = (row['correct'] ?? '').trim().toUpperCase();
    var correctIndex = -1;
    if (correctRaw.isEmpty) {
      err('Missing correct answer.');
    } else {
      correctIndex = correctRaw.length == 1 && correctRaw.codeUnitAt(0) >= 65
          ? correctRaw.codeUnitAt(0) -
                65 // A-D
          : (int.tryParse(correctRaw) ?? 0) - 1; // 1-based number
      if (correctIndex < 0 || correctIndex >= answers.length) {
        err(
          'Correct answer "$correctRaw" out of range for '
          '${answers.length} answers.',
        );
      }
    }

    final explanation = (row['explanation'] ?? '').trim();
    if (explanation.isEmpty) err('Missing explanation.');

    // Stage 5: topic mapping.
    final topicRaw = (row['topic'] ?? '').trim();
    final topic = topicByKey[topicRaw.toLowerCase()];
    if (topicRaw.isEmpty) {
      err('Missing topic.');
    } else if (topic == null) {
      err(
        'Unknown topic "$topicRaw". Known: '
        '${topics.map((t) => t.name).join(", ")}.',
      );
    }

    final difficultyRaw = (row['difficulty'] ?? '').trim().toLowerCase();
    var difficulty = Difficulty.medium;
    if (difficultyRaw.isNotEmpty) {
      final d = Difficulty.values.asNameMap()[difficultyRaw];
      if (d == null) {
        err('Invalid difficulty "$difficultyRaw" (easy|medium|hard).');
      } else {
        difficulty = d;
      }
    }

    // Stage 4: duplicate detection.
    if (text.isNotEmpty) {
      final n = norm(text);
      if (existingTexts.contains(n)) {
        err('Duplicate of an existing question.');
      } else if (!seenInBatch.add(n)) {
        err('Duplicate within this import.');
      }
    }

    if ((row['image'] ?? '').trim().isNotEmpty) {
      warn(
        'Image reference ignored — image import lands with Firebase '
        'Storage (deferred).',
      );
    }

    issues.addAll(rowIssues);
    if (rowIssues.any((i) => i.blocking)) continue;

    final tags = (row['tags'] ?? '')
        .split(',')
        .map((t) => t.trim())
        .where((t) => t.isNotEmpty)
        .toList();
    final references = (row['references'] ?? '')
        .split(',')
        .map((r) => r.trim())
        .where((r) => r.isNotEmpty)
        .toList();

    questions.add(
      Question(
        id: 'imp-${norm(text).hashCode.toRadixString(16)}',
        examId: examId,
        topicId: topic!.id,
        text: text,
        answers: answers,
        correctIndex: correctIndex,
        explanation: explanation,
        difficulty: difficulty,
        status: ContentStatus.draft, // published only after approval step
        tags: tags,
        subtopic: _emptyToNull(row['subtopic']),
        learningObjective: _emptyToNull(row['learningobjective']),
        references: references,
        author: author,
      ),
    );
  }

  return ImportReport(questions: questions, issues: issues);
}

String? _emptyToNull(String? s) {
  final t = s?.trim() ?? '';
  return t.isEmpty ? null : t;
}

List<Map<String, String>> _parseJsonRows(
  String content,
  List<ImportIssue> issues,
) {
  final root = jsonDecode(content);
  if (root is! List) {
    throw const FormatException('JSON must be an array of question objects.');
  }
  return [
    for (final item in root)
      if (item is Map)
        {
          for (final e in item.entries)
            e.key.toString().toLowerCase(): _jsonField(e.value),
        },
  ];
}

String _jsonField(dynamic v) => v is List ? v.join(',') : (v?.toString() ?? '');

/// Minimal RFC 4180 CSV parser (quotes, escaped quotes, newlines in quotes).
/// ponytail: sufficient for admin imports; swap for package:csv if edge
/// cases surface.
List<Map<String, String>> _parseCsvRows(
  String content,
  List<ImportIssue> issues,
) {
  final records = _csvRecords(content);
  if (records.isEmpty) return const [];
  final headers = [for (final h in records.first) h.trim().toLowerCase()];
  const required = [
    'question',
    'answera',
    'answerb',
    'correct',
    'explanation',
    'topic',
  ];
  final missing = required.where((h) => !headers.contains(h)).toList();
  if (missing.isNotEmpty) {
    throw FormatException(
      'CSV missing required columns: '
      '${missing.join(", ")}. Header row expected.',
    );
  }
  return [
    for (final record in records.skip(1))
      if (record.any((c) => c.trim().isNotEmpty))
        {
          for (var i = 0; i < headers.length && i < record.length; i++)
            headers[i]: record[i],
        },
  ];
}

List<List<String>> _csvRecords(String content) {
  final records = <List<String>>[];
  var field = StringBuffer();
  var record = <String>[];
  var inQuotes = false;
  for (var i = 0; i < content.length; i++) {
    final c = content[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < content.length && content[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(c);
      }
    } else if (c == '"') {
      inQuotes = true;
    } else if (c == ',') {
      record.add(field.toString());
      field = StringBuffer();
    } else if (c == '\n' || c == '\r') {
      if (c == '\r' && i + 1 < content.length && content[i + 1] == '\n') i++;
      record.add(field.toString());
      field = StringBuffer();
      records.add(record);
      record = <String>[];
    } else {
      field.write(c);
    }
  }
  if (field.isNotEmpty || record.isNotEmpty) {
    record.add(field.toString());
    records.add(record);
  }
  return records;
}

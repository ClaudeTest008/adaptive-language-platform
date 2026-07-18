import 'dart:convert';

import 'package:archive/archive.dart';

import '../language/book_ingestion.dart';

/// Real import backend behind the book-import seam (Phase 27). Turns raw bytes
/// into an [IngestedBook] for TXT and EPUB — fully offline, deterministic, no
/// OCR. PDF text extraction is a declared seam (a pure-Dart PDF text backend is
/// a larger, separate effort); PDFs and scanned documents are reported politely
/// and never crash.
enum BookFormat { txt, epub, pdf, unknown }

/// The outcome of importing a document.
class ImportOutcome {
  const ImportOutcome._({
    required this.ok,
    required this.format,
    this.book,
    this.message,
  });

  factory ImportOutcome.success(BookFormat format, IngestedBook book) =>
      ImportOutcome._(ok: true, format: format, book: book);

  factory ImportOutcome.failure(BookFormat format, String message) =>
      ImportOutcome._(ok: false, format: format, message: message);

  final bool ok;
  final BookFormat format;
  final IngestedBook? book;

  /// A learner-facing explanation when [ok] is false.
  final String? message;
}

/// Detects the format from magic bytes — never trusts the filename.
BookFormat detectFormat(List<int> bytes) {
  if (bytes.length >= 4) {
    // %PDF
    if (bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 &&
        bytes[3] == 0x46) {
      return BookFormat.pdf;
    }
    // PK.. (ZIP → EPUB is a zip; verified below by mimetype)
    if (bytes[0] == 0x50 && bytes[1] == 0x4B) return BookFormat.epub;
  }
  return BookFormat.txt; // default: treat as plain text
}

final _tag = RegExp(r'<[^>]+>');
final _entity = <String, String>{
  '&nbsp;': ' ', '&amp;': '&', '&lt;': '<', '&gt;': '>', '&quot;': '"',
  '&#39;': "'", '&aacute;': 'á', '&eacute;': 'é', '&iacute;': 'í',
  '&oacute;': 'ó', '&uacute;': 'ú', '&ntilde;': 'ñ',
};

String _stripHtml(String html) {
  var s = html
      .replaceAll(RegExp(r'<\s*(br|/p|/div|/h[1-6])\s*/?>', caseSensitive: false),
          '\n\n')
      .replaceAll(_tag, ' ');
  _entity.forEach((k, v) => s = s.replaceAll(k, v));
  return s.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
}

class DocumentImporter {
  const DocumentImporter();

  ImportOutcome import({required String title, required List<int> bytes}) {
    final format = detectFormat(bytes);
    switch (format) {
      case BookFormat.pdf:
        return ImportOutcome.failure(
          BookFormat.pdf,
          'PDF import needs the text-extraction backend (coming soon). '
          'EPUB and TXT work today; scanned PDFs are not supported.',
        );
      case BookFormat.epub:
        return _epub(title, bytes);
      case BookFormat.txt:
      case BookFormat.unknown:
        return _txt(title, bytes);
    }
  }

  ImportOutcome _txt(String title, List<int> bytes) {
    final text = _decode(bytes);
    if (text.trim().isEmpty) {
      return ImportOutcome.failure(
        BookFormat.txt,
        'This file has no readable text.',
      );
    }
    return ImportOutcome.success(
      BookFormat.txt,
      ingestBook(title: title, author: '', text: text),
    );
  }

  ImportOutcome _epub(String title, List<int> bytes) {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      // A real EPUB declares this mimetype; if absent it is just a zip.
      final files = {
        for (final f in archive.files)
          if (f.isFile) f.name: f,
      };
      final order = _spineOrder(files) ??
          (files.keys
              .where((n) => n.toLowerCase().endsWith('.xhtml') ||
                  n.toLowerCase().endsWith('.html') ||
                  n.toLowerCase().endsWith('.htm'))
              .toList()
            ..sort());
      if (order.isEmpty) {
        return ImportOutcome.failure(
          BookFormat.epub,
          "This EPUB has no readable chapters.",
        );
      }
      final buffer = StringBuffer();
      final meta = _opfMetadata(files);
      for (final name in order) {
        final f = files[name];
        if (f == null) continue;
        final text = _stripHtml(_decode(f.content as List<int>));
        if (text.isNotEmpty) buffer.writeln('$text\n');
      }
      final full = buffer.toString();
      if (full.trim().isEmpty) {
        return ImportOutcome.failure(
          BookFormat.epub,
          'This EPUB contains no extractable text (it may be image-only).',
        );
      }
      return ImportOutcome.success(
        BookFormat.epub,
        ingestBook(
          title: meta.title ?? title,
          author: meta.author ?? '',
          text: full,
        ),
      );
    } catch (e) {
      return ImportOutcome.failure(
        BookFormat.epub,
        "This book could not be read as EPUB.",
      );
    }
  }

  /// Reads the OPF spine → ordered content hrefs; null when unavailable.
  List<String>? _spineOrder(Map<String, ArchiveFile> files) {
    final opfName = files.keys.firstWhere(
      (n) => n.toLowerCase().endsWith('.opf'),
      orElse: () => '',
    );
    if (opfName.isEmpty) return null;
    final opf = _decode(files[opfName]!.content as List<int>);
    final dir = opfName.contains('/')
        ? opfName.substring(0, opfName.lastIndexOf('/') + 1)
        : '';
    // id → href from <manifest>.
    final manifest = <String, String>{};
    for (final m in RegExp(
      r'<item\b[^>]*\bid="([^"]+)"[^>]*\bhref="([^"]+)"',
      caseSensitive: false,
    ).allMatches(opf)) {
      manifest[m.group(1)!] = m.group(2)!;
    }
    // Also handle href-before-id ordering.
    for (final m in RegExp(
      r'<item\b[^>]*\bhref="([^"]+)"[^>]*\bid="([^"]+)"',
      caseSensitive: false,
    ).allMatches(opf)) {
      manifest[m.group(2)!] = m.group(1)!;
    }
    final order = <String>[];
    for (final m in RegExp(
      r'<itemref\b[^>]*\bidref="([^"]+)"',
      caseSensitive: false,
    ).allMatches(opf)) {
      final href = manifest[m.group(1)!];
      if (href == null) continue;
      final full = '$dir$href';
      if (files.containsKey(full)) {
        order.add(full);
      } else if (files.containsKey(href)) {
        order.add(href);
      }
    }
    return order.isEmpty ? null : order;
  }

  ({String? title, String? author}) _opfMetadata(
    Map<String, ArchiveFile> files,
  ) {
    final opfName = files.keys.firstWhere(
      (n) => n.toLowerCase().endsWith('.opf'),
      orElse: () => '',
    );
    if (opfName.isEmpty) return (title: null, author: null);
    final opf = _decode(files[opfName]!.content as List<int>);
    String? tag(String t) =>
        RegExp('<dc:$t[^>]*>([^<]+)</dc:$t>', caseSensitive: false)
            .firstMatch(opf)
            ?.group(1)
            ?.trim();
    return (title: tag('title'), author: tag('creator'));
  }

  String _decode(List<int> bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: true);
    } catch (_) {
      return latin1.decode(bytes);
    }
  }
}

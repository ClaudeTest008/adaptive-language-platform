/// Multi-tenancy + content libraries (ADR-0012). Pure domain models and
/// the library-inheritance resolver. Enforcement lives in Firestore rules
/// (`/orgs/{orgId}/**`, emulator-tested); these types are the client-side
/// contract for the Firestore implementation.
library;

import 'models.dart';

/// Tenant kinds share one model — the differences are content and
/// branding, not schema (school, training center, university, agency,
/// corporate).
class Organization {
  const Organization({
    required this.id,
    required this.name,
    this.brandColorHex,
    this.logoPath,
  });

  final String id;
  final String name;

  /// White-label branding (applied to theme seed when set).
  final String? brandColorHex;
  final String? logoPath;
}

/// Role ladder inside one organization. Mirrors the Firestore rules:
/// owner/admin manage members; editor writes content; member consumes.
enum OrgRole { owner, admin, editor, member }

class OrgMember {
  const OrgMember({required this.uid, required this.role});

  final String uid;
  final OrgRole role;

  bool get canEditContent =>
      role == OrgRole.owner || role == OrgRole.admin || role == OrgRole.editor;
  bool get canManageMembers => role == OrgRole.owner || role == OrgRole.admin;
}

/// Library scopes, most-shared to most-private. A library optionally
/// inherits from a parent library; resolution layers children over
/// parents WITHOUT copying content (inheritance, not duplication).
enum LibraryScope { global, official, marketplace, organization, private }

class ContentLibrary {
  const ContentLibrary({
    required this.id,
    required this.name,
    required this.scope,
    this.parentId,
    this.questionsById = const {},
  });

  final String id;
  final String name;
  final LibraryScope scope;

  /// Inheritance edge — e.g. an org library layering over the global
  /// country pack. Chains may be arbitrarily deep.
  final String? parentId;

  /// This library's OWN content only (overrides + additions).
  final Map<String, Question> questionsById;
}

/// Resolves the effective content of [libraryId]: walks the parent chain
/// root-first and layers each library's own questions over its ancestors.
/// A child overriding a question id replaces the parent's version; a
/// child archiving a question hides the inherited one. No duplication —
/// each question exists in exactly one library document.
List<Question> resolveLibrary(
  String libraryId,
  Map<String, ContentLibrary> libraries, {
  bool publishedOnly = false,
}) {
  // Build the chain, guarding against cycles.
  final chain = <ContentLibrary>[];
  final seen = <String>{};
  String? cursor = libraryId;
  while (cursor != null) {
    final lib = libraries[cursor];
    if (lib == null) break;
    if (!seen.add(lib.id)) {
      throw StateError('Library inheritance cycle at ${lib.id}.');
    }
    chain.add(lib);
    cursor = lib.parentId;
  }

  // Layer root-first so nearer libraries win.
  final effective = <String, Question>{};
  for (final lib in chain.reversed) {
    effective.addAll(lib.questionsById);
  }
  final result = effective.values
      .where((q) => q.status != ContentStatus.archived)
      .where((q) => !publishedOnly || q.status == ContentStatus.published)
      .toList();
  return result;
}

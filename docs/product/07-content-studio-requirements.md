# Content Studio — Content Management & Import System

Primary tool for administrators, educators, institutions, and future content partners to build and maintain exam content without developer assistance. Must scale to tens of thousands of questions across countries, languages, and categories.

## Full Requirements (target state)

### Managed entities
Categories, countries, regions, exam types, exams, topics, subtopics, learning objectives, questions, answers, explanations, images, references, tags, difficulty levels, question versions, drafts, published content, archived content.

### New Exam Wizard
Guided creation: category, country, region, name, description, passing score, time limit, question count, difficulty distribution, topics, languages, instructions.

### Question Editor
Visual, non-technical: rich text, images, multiple choice, true/false, scenario questions (multiple-correct in future), explanation editor, tags, references, difficulty, learning objective, related concepts, common mistakes, preview mode.

### Bulk Import
Formats: CSV, Excel (.xlsx), JSON. Future: PDF, Word, Google Sheets, AI-generated. Thousands of questions per operation.

### Import Pipeline (mandatory order)
Upload → file validation → schema validation → question validation → duplicate detection → topic mapping → image processing → reference validation → preview → administrator approval → Firestore import → search index update → publish. Nothing enters production unvalidated.

### Import Validation (blocking until resolved)
Duplicate questions/explanations, missing answers, missing correct answer, invalid difficulty, missing topic/subtopic, broken references, missing images, unsupported file types, invalid formatting. Detailed validation report required.

### Question Template (import fields)
Question, optional image, answers A–D, correct answer, explanation, topic, subtopic, difficulty, learning objective, exam weight, estimated answer time, tags, references, related concepts, common mistakes, version, status, author, created/updated dates.

### Image Import
Folder import alongside spreadsheet; auto-upload, question association, missing-image detection, resize, thumbnails, format validation.

### Versioning
Questions never overwritten: version history, rollback, draft/published/archived, scheduled publishing, historical exam integrity (students see the version they answered).

### Topic Library, Search & Filtering, Content Packs, Import Analytics
Reusable topic libraries with metadata inheritance; admin search across all fields; portable exam packs (questions + images + topics + metadata) for institutional licensing and marketplace; import analytics (volumes, rejects, duplicate rate, durations, growth).

### AI Integration (future, human-review gated)
Question/explanation generation, PDF/textbook extraction, difficulty estimation, duplicate detection, topic classification, learning-objective detection, image descriptions, translation, quality review, version comparison.

## V1 Slice (implemented — see ADR-0007)

- Content Studio at `/admin` inside the existing Flutter app (ADR-0003): overview + exam settings, question list with search/status filter, visual question editor (text, answers, correct, explanation, topic, difficulty, tags, status), CSV + JSON bulk import through the pipeline stages that apply without Storage/Firestore (parse → schema → question validation → duplicate detection → topic mapping → preview report → approve → import), content-pack JSON export/import.
- Question metadata added to the domain model: difficulty, tags, subtopic, learning objective, references, status (draft/published/archived), version, author, timestamps.
- Learners see published questions only. Archive instead of delete. Edit bumps `version`.

## Deferred (tracked; requires Firebase deploy and/or later epics)

- Excel (.xlsx) parsing, file upload dialogs (V1: paste content), image folder import + thumbnails, reference URL validation, full version history with rollback and scheduled publishing, per-version attempt integrity, regions/exam types/multi-language content editing UI, new-exam wizard (V1: single exam settings form), search index service, import analytics dashboards, content marketplace, all AI assists.

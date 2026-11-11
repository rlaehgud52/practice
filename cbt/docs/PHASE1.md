# MEDI-OS foundation and legacy import

The current CBT remains a Node.js 18+, vanilla JavaScript application. Its HTML/CSS/JS, server, JSON files, images, localStorage key, and Vercel static deployment are preserved. The app has no Supabase runtime dependency in this change.

## Database structure

Migration `supabase/migrations/202611120001_foundation.sql` creates:

- `profiles`: one profile per Supabase Auth user.
- `subjects` and `lectures`: user-owned catalogs with private/shared/public visibility metadata.
- `lecture_files`: metadata and a Storage object path only; PDF bytes are stored in the private `lecture-files` bucket.
- `pdf_pages` and `extracted_blocks`: page text and extracted content, owned by the file owner.
- `questions` and `question_choices`: question text and ordered choices, with legacy identifiers and metadata.
- `question_keys`: separate answer and explanation storage so shared question reads do not reveal answers.
- `question_sources`: links from questions to extracted PDF blocks/pages.
- `attempts` and `attempt_answers`: user-owned practice sessions and responses.
- `question_memos`, `flashcards`, and `review_logs`: private user learning data.

All tables have primary keys. Foreign keys enforce ownership links and cascade/restrict behavior. Indexes cover common owner, subject, lecture, question, and review lookups.

## Ownership and RLS

- RLS is enabled on every application table. A user can manage their own profile and private content; attempts, answers, memos, flashcards, and review logs are isolated by `auth.uid()`.
- Authenticated users can read rows marked `shared` or `public` in the catalog/question tables and related lecture content. Anonymous access is not granted.
- Client policies permit creating and editing only private subjects, lectures, and questions. No client policy promotes content to shared/public; a future moderation or deliberate publishing migration must add that operation.
- Answer keys remain owner-only. A future learner grading flow must use a server-side or otherwise answer-safe design.
- PDF objects are in a private Storage bucket. Storage object paths must begin with the authenticated owner's UUID; database metadata contains only bucket/path and file details.
- Existing KAMC content is imported as private and must remain personal-use only unless redistribution rights are confirmed.

## Legacy mapping

`scripts/migrate-legacy-questions.js` reads `data/questions.json`; it does not modify it, `public/questions.json`, browser storage, or images.

| Legacy JSON | Destination |
| --- | --- |
| `title` | Private `subjects.title` |
| `questions[].id` | `questions.legacy_id` |
| array order / `number` | `questions.legacy_number` |
| `stem` | `questions.stem` |
| `choices[]` | ordered `question_choices` rows; position remains 1-based |
| `answer` | private `question_keys.answer`; `null` remains `null` |
| `explanation` | private `question_keys.explanation` |
| `images[]` | `questions.legacy_metadata.images` (original `/images/...` paths retained) |

The importer authenticates using a user access token and writes content owned by that user with `visibility='private'`. It is safe to re-run for the same owner and legacy IDs. A failed import may have completed some upserts; re-running completes the remaining rows. It does not upload image files or any PDFs.

## Run and verify

From `cbt/`:

```powershell
node --check server.js
node --check public/app.js
node --test test/*.test.js
node scripts/migrate-legacy-questions.js
node -e "const fs=require('fs'); const a=fs.readFileSync('data/questions.json','utf8'); const b=fs.readFileSync('public/questions.json','utf8'); if(a!==b) throw new Error('legacy JSON copies differ'); const d=JSON.parse(a); if(d.questions.length!==35) throw new Error('expected 35 questions'); console.log('35 questions; JSON copies match');"
node server.js
```

The importer dry run needs no credentials. `--apply` requires a migrated Supabase project plus `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and `SUPABASE_USER_ACCESS_TOKEN` in the local process environment. Never put a service-role key in client code or commit real access tokens. The current Vercel static app does not load `.env.example`.

Before applying to any hosted database, review and test the SQL against a disposable local Supabase instance. No hosted project or database has been created or modified as part of this work.

When the Supabase CLI and Docker are available, run the database suite from `cbt/`:

```powershell
supabase start
supabase test db
supabase stop
```

`supabase/tests/database/schema_rls_test.sql` checks that the requested tables exist, RLS is enabled on every application table, and the PDF bucket is private. These tests still need execution against a disposable local Supabase instance before considering the migration validated.

## Rollback and backups

- Before migration, back up the Supabase database and the complete `cbt/` folder, especially both question JSON files, `public/images/`, and the browser's existing localStorage profile.
- The importer is additive and does not change legacy JSON or localStorage. To undo a completed import, delete only the subject created for the importing user and its owned dependent rows after verifying the subject title/owner; never truncate shared tables.
- Once the SQL migration has been applied to a database, do not delete migration history or drop tables without a reviewed down migration and a fresh backup. The existing CBT can continue using its local server and JSON regardless of Supabase availability.

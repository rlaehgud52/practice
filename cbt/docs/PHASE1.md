# MEDI-OS Phase 1 foundation

This commit establishes the first project and database boundaries. The current CBT remains the default application: Node.js 18+, vanilla browser JavaScript, static Vercel output, JSON question data, and browser-local answers/flags.

## Compatibility contract

- Keep the legacy bank shape: `title` and `questions[]`.
- Keep question fields and identifiers, one-based `answer`, `null` answers, order, and `/images/...` URLs.
- Keep the `cbt-2025-3-state` localStorage key with `answers` and `flags`.
- Do not migrate or rewrite the 35 existing questions as part of this foundation.
- The current app does not read `.env.example` and does not connect to Supabase. The example only documents future public configuration; no secret belongs in browser code.

## Database boundary

The migration creates private/shared bank metadata, question content, separate answer keys, and user-owned attempts. RLS is enabled on every table. Authenticated users can read shared bank content; only the bank owner can modify its content. Answer keys are visible only to the bank owner so shared question reads do not disclose correct answers. New banks and owner edits remain private; a future explicit review/publishing flow must be designed before promoting content to shared.

The migration is a proposal for local review. Do not run it against a hosted Supabase project until the owner approves project creation and remote changes. Do not seed the existing KAMC material: the current CBT README marks it for personal study only.

## Local baseline checks

Run from `cbt/`:

```powershell
node --version
node --check server.js
node -e "const fs=require('fs'); for (const p of ['data/questions.json','public/questions.json']) { const d=JSON.parse(fs.readFileSync(p,'utf8')); if (d.questions.length !== 35) throw new Error(p + ': expected 35 questions'); console.log(p, d.questions.length); }"
node server.js
```

Open `http://localhost:3000` and verify answering/flagging persists, JSON export/import works, and local question edits update both JSON copies. Check the same layout at desktop and iPad viewport widths. The feature branch has no remote Supabase setup, secret values, or seeded data.

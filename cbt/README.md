# 기종평 CBT (로컬)

Node.js 18 이상에서 실행합니다. 추가 패키지 설치는 필요하지 않습니다.

```bash
cd cbt
node server.js
```

브라우저에서 **http://localhost:3000** 을 엽니다. 포트를 바꾸려면 `PORT=3001 node server.js`를 사용하세요 (Windows PowerShell: `$env:PORT=3001; node server.js`). 서버는 내 컴퓨터의 `127.0.0.1`에만 연결됩니다.

- 2025년 기초의학종합평가 3교시 35문항과 사진자료가 포함되어 있습니다.
- 문제와 정답은 `data/questions.json`과 배포용 `public/questions.json`에 저장됩니다. **문항 관리** 화면에서 추가, 수정, 삭제하거나 JSON을 가져오고 내보낼 수 있습니다. 파일을 직접 수정한 경우 페이지를 새로고침하세요.
- `answer`는 **1부터 시작하는 선택지 번호**입니다. 정답을 모르면 `null`로 둡니다. 제공된 PDF에는 정답표가 없어 모든 정답은 현재 `null`입니다. 정답을 입력한 문제만 채점됩니다.
- `images`에는 `/images/파일명.png` 형태의 경로를 기록하고 실제 파일은 `public/images/`에 넣습니다. 문항 ID는 중복되지 않아야 합니다.
- 풀이 응답과 다시 보기 표시는 해당 브라우저의 로컬 저장소에 저장됩니다. 브라우저 데이터를 지우면 초기화됩니다.
- Vercel 배포 절차와 편집 저장 방식은 `VERCEL.md`를 참고하세요.
- 사용한 문항과 이미지의 저작권은 KAMC에 있습니다. 개인 학습용으로만 사용하세요.

## MEDI-OS foundation

The first foundation adds a Supabase schema and a separate, opt-in importer while preserving the current local CBT behavior. The app itself does not connect to Supabase; `.env.example` is documentation for the importer and future setup. See `docs/PHASE1.md` before any database migration or import.

### Legacy question import

The importer defaults to a read-only dry run:

```bash
node scripts/migrate-legacy-questions.js
```

To import into an already configured Supabase project, apply the migration first, then set `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and a valid `SUPABASE_USER_ACCESS_TOKEN` in the local environment and run:

```bash
node scripts/migrate-legacy-questions.js --apply
```

The importer creates a private subject and private questions owned by the authenticated user. It preserves legacy IDs, order, choices, one-based answers (including `null`), explanations, and image paths as metadata. It is idempotent for the same user and legacy IDs. It does not upload question images or PDF files, alter either source JSON, or modify the CBT's `localStorage` data. The KAMC source material remains subject to the personal-study-only notice above; do not share or publish it without rights approval.

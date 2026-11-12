create type public.content_visibility as enum ('private', 'shared', 'public');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.subjects (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (length(trim(title)) > 0),
  description text not null default '',
  visibility public.content_visibility not null default 'private',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, title)
);

create table public.exam_banks (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  subject_id uuid references public.subjects(id) on delete set null,
  source_key text not null,
  title text not null check (length(trim(title)) > 0),
  description text not null default '',
  visibility public.content_visibility not null default 'private',
  source_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (owner_id, source_key),
  check (jsonb_typeof(source_metadata) = 'object')
);

create table public.lectures (
  id uuid primary key default gen_random_uuid(),
  subject_id uuid not null references public.subjects(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (length(trim(title)) > 0),
  description text not null default '',
  visibility public.content_visibility not null default 'private',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, owner_id)
);

create table public.lecture_files (
  id uuid primary key default gen_random_uuid(),
  lecture_id uuid not null,
  owner_id uuid not null references auth.users(id) on delete cascade,
  storage_bucket text not null default 'lecture-files',
  storage_path text not null,
  original_name text not null,
  mime_type text not null,
  byte_size bigint check (byte_size is null or byte_size >= 0),
  checksum_sha256 text,
  created_at timestamptz not null default now(),
  foreign key (lecture_id, owner_id)
    references public.lectures(id, owner_id) on delete cascade,
  unique (storage_bucket, storage_path)
);

create table public.pdf_pages (
  id uuid primary key default gen_random_uuid(),
  lecture_file_id uuid not null references public.lecture_files(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  page_number integer not null check (page_number > 0),
  extracted_text text not null default '',
  created_at timestamptz not null default now(),
  unique (lecture_file_id, page_number)
);

create table public.extracted_blocks (
  id uuid primary key default gen_random_uuid(),
  pdf_page_id uuid not null references public.pdf_pages(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  block_order integer not null check (block_order > 0),
  block_type text not null default 'text',
  content text not null,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (pdf_page_id, block_order),
  check (jsonb_typeof(metadata) = 'object')
);

create table public.questions (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  exam_bank_id uuid not null references public.exam_banks(id) on delete cascade,
  subject_id uuid references public.subjects(id) on delete set null,
  lecture_id uuid references public.lectures(id) on delete set null,
  legacy_id text,
  legacy_number integer,
  question_type text not null default 'single_choice'
    check (question_type in ('single_choice', 'short_answer')),
  stem text not null,
  visibility public.content_visibility not null default 'private',
  legacy_metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (exam_bank_id, legacy_id),
  check (legacy_number is null or legacy_number > 0),
  check (jsonb_typeof(legacy_metadata) = 'object')
);

create table public.question_choices (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.questions(id) on delete cascade,
  position integer not null check (position > 0),
  choice_text text not null,
  created_at timestamptz not null default now(),
  unique (question_id, position),
  unique (id, question_id)
);

create table public.question_keys (
  question_id uuid primary key references public.questions(id) on delete cascade,
  answer smallint,
  expected_answer text,
  accepted_answers jsonb not null default '[]'::jsonb,
  explanation text not null default '',
  updated_at timestamptz not null default now(),
  check (answer is null or answer > 0),
  check (jsonb_typeof(accepted_answers) = 'array')
);

create table public.question_sources (
  id uuid primary key default gen_random_uuid(),
  question_id uuid not null references public.questions(id) on delete cascade,
  extracted_block_id uuid references public.extracted_blocks(id) on delete cascade,
  page_number integer check (page_number is null or page_number > 0),
  source_note text not null default '',
  created_at timestamptz not null default now(),
  check (extracted_block_id is not null or page_number is not null)
);

create table public.attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  subject_id uuid references public.subjects(id) on delete set null,
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.attempt_answers (
  id uuid primary key default gen_random_uuid(),
  attempt_id uuid not null references public.attempts(id) on delete cascade,
  question_id uuid not null references public.questions(id) on delete restrict,
  selected_choice_id uuid,
  answer_value smallint,
  answer_text text,
  is_correct boolean,
  answered_at timestamptz not null default now(),
  unique (attempt_id, question_id),
  foreign key (selected_choice_id, question_id)
    references public.question_choices(id, question_id) on delete restrict,
  check (answer_text is null or (selected_choice_id is null and answer_value is null))
);

create table public.question_memos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  question_id uuid not null references public.questions(id) on delete cascade,
  memo text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, question_id)
);

create table public.flashcards (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  question_id uuid references public.questions(id) on delete set null,
  front text not null,
  back text not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.review_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  flashcard_id uuid not null references public.flashcards(id) on delete cascade,
  rating smallint not null check (rating between 1 and 4),
  reviewed_at timestamptz not null default now(),
  elapsed_ms integer check (elapsed_ms is null or elapsed_ms >= 0)
);

create index lectures_subject_idx on public.lectures(subject_id);
create index exam_banks_owner_idx on public.exam_banks(owner_id, created_at desc);
create index exam_banks_subject_idx on public.exam_banks(subject_id);
create index lecture_files_lecture_idx on public.lecture_files(lecture_id);
create index pdf_pages_file_page_idx on public.pdf_pages(lecture_file_id, page_number);
create index extracted_blocks_page_idx on public.extracted_blocks(pdf_page_id, block_order);
create index questions_owner_visibility_idx on public.questions(owner_id, visibility);
create index questions_subject_idx on public.questions(subject_id);
create index question_choices_question_idx on public.question_choices(question_id, position);
create index question_sources_question_idx on public.question_sources(question_id);
create index attempts_user_started_idx on public.attempts(user_id, started_at desc);
create index attempt_answers_question_idx on public.attempt_answers(question_id);
create index question_memos_user_idx on public.question_memos(user_id);
create index flashcards_owner_idx on public.flashcards(owner_id);
create index review_logs_user_reviewed_idx on public.review_logs(user_id, reviewed_at desc);

alter table public.profiles enable row level security;
alter table public.subjects enable row level security;
alter table public.exam_banks enable row level security;
alter table public.lectures enable row level security;
alter table public.lecture_files enable row level security;
alter table public.pdf_pages enable row level security;
alter table public.extracted_blocks enable row level security;
alter table public.questions enable row level security;
alter table public.question_choices enable row level security;
alter table public.question_keys enable row level security;
alter table public.question_sources enable row level security;
alter table public.attempts enable row level security;
alter table public.attempt_answers enable row level security;
alter table public.question_memos enable row level security;
alter table public.flashcards enable row level security;
alter table public.review_logs enable row level security;

grant select, insert, update, delete on public.profiles, public.subjects, public.lectures,
  public.exam_banks,
  public.lecture_files, public.pdf_pages, public.extracted_blocks, public.questions,
  public.question_choices, public.question_keys, public.question_sources, public.attempts,
  public.attempt_answers, public.question_memos, public.flashcards, public.review_logs
  to authenticated;

create policy "profiles are self managed" on public.profiles
  for all to authenticated
  using (id = (select auth.uid()))
  with check (id = (select auth.uid()));

create policy "subjects readable by owner or visibility" on public.subjects
  for select to authenticated
  using (owner_id = (select auth.uid()) or visibility in ('shared', 'public'));
create policy "owners create private subjects" on public.subjects
  for insert to authenticated
  with check (owner_id = (select auth.uid()) and visibility = 'private');
create policy "owners update private subjects" on public.subjects
  for update to authenticated
  using (owner_id = (select auth.uid()) and visibility = 'private')
  with check (owner_id = (select auth.uid()) and visibility = 'private');
create policy "owners delete subjects" on public.subjects
  for delete to authenticated using (owner_id = (select auth.uid()));

create policy "exam banks readable by owner or visibility" on public.exam_banks
  for select to authenticated
  using (owner_id = (select auth.uid()) or visibility in ('shared', 'public'));
create policy "owners create private exam banks" on public.exam_banks
  for insert to authenticated
  with check (owner_id = (select auth.uid()) and visibility = 'private'
    and (subject_id is null or exists (select 1 from public.subjects s
      where s.id = subject_id and s.owner_id = (select auth.uid()))));
create policy "owners update private exam banks" on public.exam_banks
  for update to authenticated
  using (owner_id = (select auth.uid()) and visibility = 'private')
  with check (owner_id = (select auth.uid()) and visibility = 'private'
    and (subject_id is null or exists (select 1 from public.subjects s
      where s.id = subject_id and s.owner_id = (select auth.uid()))));
create policy "owners delete exam banks" on public.exam_banks
  for delete to authenticated using (owner_id = (select auth.uid()));

create policy "lectures readable by owner or visibility" on public.lectures
  for select to authenticated
  using (owner_id = (select auth.uid()) or visibility in ('shared', 'public'));
create policy "owners create private lectures" on public.lectures
  for insert to authenticated
  with check (owner_id = (select auth.uid()) and visibility = 'private'
    and exists (select 1 from public.subjects s
      where s.id = subject_id and s.owner_id = (select auth.uid())));
create policy "owners update private lectures" on public.lectures
  for update to authenticated
  using (owner_id = (select auth.uid()) and visibility = 'private')
  with check (owner_id = (select auth.uid()) and visibility = 'private'
    and exists (select 1 from public.subjects s
      where s.id = subject_id and s.owner_id = (select auth.uid())));
create policy "owners delete lectures" on public.lectures
  for delete to authenticated using (owner_id = (select auth.uid()));

create policy "lecture files readable with lecture" on public.lecture_files
  for select to authenticated
  using (exists (select 1 from public.lectures l where l.id = lecture_id
    and (l.owner_id = (select auth.uid()) or l.visibility in ('shared', 'public'))));
create policy "owners manage lecture files" on public.lecture_files
  for all to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()) and exists (
    select 1 from public.lectures l where l.id = lecture_id
      and l.owner_id = (select auth.uid()) and l.visibility = 'private'));

create policy "pdf pages readable with lecture file" on public.pdf_pages
  for select to authenticated
  using (exists (select 1 from public.lecture_files f
    join public.lectures l on l.id = f.lecture_id
    where f.id = lecture_file_id
      and (l.owner_id = (select auth.uid()) or l.visibility in ('shared', 'public'))));
create policy "owners manage pdf pages" on public.pdf_pages
  for all to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()) and exists (
    select 1 from public.lecture_files f where f.id = lecture_file_id
      and f.owner_id = (select auth.uid())));

create policy "blocks readable with pdf page" on public.extracted_blocks
  for select to authenticated
  using (exists (select 1 from public.pdf_pages p
    join public.lecture_files f on f.id = p.lecture_file_id
    join public.lectures l on l.id = f.lecture_id
    where p.id = pdf_page_id
      and (l.owner_id = (select auth.uid()) or l.visibility in ('shared', 'public'))));
create policy "owners manage extracted blocks" on public.extracted_blocks
  for all to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()) and exists (
    select 1 from public.pdf_pages p where p.id = pdf_page_id
      and p.owner_id = (select auth.uid())));

create policy "questions readable by owner or visibility" on public.questions
  for select to authenticated
  using (owner_id = (select auth.uid()) or (visibility in ('shared', 'public') and exists (
    select 1 from public.exam_banks b where b.id = exam_bank_id
      and b.visibility in ('shared', 'public'))));
create policy "owners create private questions" on public.questions
  for insert to authenticated
  with check (owner_id = (select auth.uid()) and visibility = 'private'
    and exists (select 1 from public.exam_banks b where b.id = exam_bank_id
      and b.owner_id = (select auth.uid()))
    and (subject_id is null or exists (select 1 from public.subjects s
      where s.id = subject_id and s.owner_id = (select auth.uid()))));
create policy "owners update private questions" on public.questions
  for update to authenticated
  using (owner_id = (select auth.uid()) and visibility = 'private')
  with check (owner_id = (select auth.uid()) and visibility = 'private'
    and exists (select 1 from public.exam_banks b where b.id = exam_bank_id
      and b.owner_id = (select auth.uid()))
    and (subject_id is null or exists (select 1 from public.subjects s
      where s.id = subject_id and s.owner_id = (select auth.uid()))));
create policy "owners delete questions" on public.questions
  for delete to authenticated using (owner_id = (select auth.uid()));

create policy "choices readable with question" on public.question_choices
  for select to authenticated
  using (exists (select 1 from public.questions q where q.id = question_id
    and (q.owner_id = (select auth.uid()) or (q.visibility in ('shared', 'public') and exists (
      select 1 from public.exam_banks b where b.id = q.exam_bank_id
        and b.visibility in ('shared', 'public'))))));
create policy "owners manage choices on private questions" on public.question_choices
  for all to authenticated
  using (exists (select 1 from public.questions q where q.id = question_id
    and q.owner_id = (select auth.uid()) and q.visibility = 'private'))
  with check (exists (select 1 from public.questions q where q.id = question_id
    and q.owner_id = (select auth.uid()) and q.visibility = 'private'));

create policy "owners manage answer keys" on public.question_keys
  for all to authenticated
  using (exists (select 1 from public.questions q where q.id = question_id
    and q.owner_id = (select auth.uid())))
  with check (exists (select 1 from public.questions q where q.id = question_id
    and q.owner_id = (select auth.uid())));

create policy "sources readable with question" on public.question_sources
  for select to authenticated
  using (exists (select 1 from public.questions q where q.id = question_id
    and (q.owner_id = (select auth.uid()) or (q.visibility in ('shared', 'public') and exists (
      select 1 from public.exam_banks b where b.id = q.exam_bank_id
        and b.visibility in ('shared', 'public'))))));
create policy "owners manage sources for own questions" on public.question_sources
  for all to authenticated
  using (exists (select 1 from public.questions q where q.id = question_id
    and q.owner_id = (select auth.uid())))
  with check (exists (select 1 from public.questions q where q.id = question_id
    and q.owner_id = (select auth.uid())));

create policy "users manage own attempts" on public.attempts
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
create policy "users manage answers in own attempts" on public.attempt_answers
  for all to authenticated
  using (exists (select 1 from public.attempts a where a.id = attempt_id
    and a.user_id = (select auth.uid())))
  with check (exists (select 1 from public.attempts a where a.id = attempt_id
    and a.user_id = (select auth.uid())));
create policy "users manage own question memos" on public.question_memos
  for all to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));
create policy "owners manage own flashcards" on public.flashcards
  for all to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));
create policy "users manage logs for own flashcards" on public.review_logs
  for all to authenticated
  using (user_id = (select auth.uid()) and exists (
    select 1 from public.flashcards f where f.id = flashcard_id
      and f.owner_id = (select auth.uid())))
  with check (user_id = (select auth.uid()) and exists (
    select 1 from public.flashcards f where f.id = flashcard_id
      and f.owner_id = (select auth.uid())));

insert into storage.buckets (id, name, public)
values ('lecture-files', 'lecture-files', false)
on conflict (id) do nothing;

create policy "owners read their lecture files" on storage.objects
  for select to authenticated
  using (bucket_id = 'lecture-files'
    and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "owners upload lecture files" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'lecture-files'
    and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "owners update their lecture files" on storage.objects
  for update to authenticated
  using (bucket_id = 'lecture-files'
    and (storage.foldername(name))[1] = (select auth.uid())::text)
  with check (bucket_id = 'lecture-files'
    and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "owners delete their lecture files" on storage.objects
  for delete to authenticated
  using (bucket_id = 'lecture-files'
    and (storage.foldername(name))[1] = (select auth.uid())::text);

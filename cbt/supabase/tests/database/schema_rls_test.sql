begin;

select plan(33);

select has_table('public', 'profiles', 'profiles table exists');
select has_table('public', 'subjects', 'subjects table exists');
select has_table('public', 'exam_banks', 'exam_banks table exists');
select has_table('public', 'lectures', 'lectures table exists');
select has_table('public', 'lecture_files', 'lecture_files table exists');
select has_table('public', 'pdf_pages', 'pdf_pages table exists');
select has_table('public', 'extracted_blocks', 'extracted_blocks table exists');
select has_table('public', 'questions', 'questions table exists');
select has_table('public', 'question_choices', 'question_choices table exists');
select has_table('public', 'question_keys', 'answer keys are stored separately');
select has_table('public', 'question_sources', 'question_sources table exists');
select has_table('public', 'attempts', 'attempts table exists');
select has_table('public', 'attempt_answers', 'attempt_answers table exists');
select has_table('public', 'question_memos', 'question_memos table exists');
select has_table('public', 'flashcards', 'flashcards table exists');
select has_table('public', 'review_logs', 'review_logs table exists');

select ok((select relrowsecurity from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname = 'profiles'), 'profiles has RLS enabled');
select ok((select relrowsecurity from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname = 'subjects'), 'subjects has RLS enabled');
select ok((select relrowsecurity from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname = 'exam_banks'), 'exam_banks has RLS enabled');
select ok((select relrowsecurity from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname = 'lectures'), 'lectures has RLS enabled');
select ok((select relrowsecurity from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname = 'lecture_files'), 'lecture_files has RLS enabled');
select ok((select relrowsecurity from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname = 'pdf_pages'), 'pdf_pages has RLS enabled');
select ok((select relrowsecurity from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname = 'extracted_blocks'), 'extracted_blocks has RLS enabled');
select ok((select relrowsecurity from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname = 'questions'), 'questions has RLS enabled');
select ok((select relrowsecurity from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname = 'question_choices'), 'question_choices has RLS enabled');
select ok((select relrowsecurity from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname = 'question_keys'), 'question_keys has RLS enabled');
select ok((select relrowsecurity from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname = 'question_sources'), 'question_sources has RLS enabled');
select ok((select relrowsecurity from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname = 'attempts'), 'attempts has RLS enabled');
select ok((select relrowsecurity from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname = 'attempt_answers'), 'attempt_answers has RLS enabled');
select ok((select relrowsecurity from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname = 'question_memos'), 'question_memos has RLS enabled');
select ok((select relrowsecurity from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname = 'flashcards'), 'flashcards has RLS enabled');
select ok((select relrowsecurity from pg_class c
  join pg_namespace n on n.oid = c.relnamespace
  where n.nspname = 'public' and c.relname = 'review_logs'), 'review_logs has RLS enabled');

select is((select public from storage.buckets where id = 'lecture-files'), false,
  'lecture-files bucket is private');

select * from finish();
rollback;

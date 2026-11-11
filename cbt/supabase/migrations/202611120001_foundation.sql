create table public.question_banks (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (length(trim(title)) > 0),
  visibility text not null default 'private'
    check (visibility in ('private', 'shared')),
  legacy_format_version integer not null default 1
    check (legacy_format_version > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.question_items (
  id uuid primary key default gen_random_uuid(),
  bank_id uuid not null references public.question_banks(id) on delete cascade,
  legacy_id text not null,
  position integer not null check (position > 0),
  stem text not null,
  choices jsonb not null,
  images jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(),
  unique (bank_id, legacy_id),
  unique (bank_id, position),
  check (case when jsonb_typeof(choices) = 'array'
    then jsonb_array_length(choices) >= 2 else false end),
  check (jsonb_typeof(images) = 'array')
);

create table public.question_keys (
  question_id uuid primary key references public.question_items(id) on delete cascade,
  answer smallint,
  explanation text not null default '',
  check (answer is null or answer > 0)
);

create table public.attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  bank_id uuid not null references public.question_banks(id) on delete cascade,
  answers jsonb not null default '{}'::jsonb,
  flags jsonb not null default '{}'::jsonb,
  started_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (jsonb_typeof(answers) = 'object'),
  check (jsonb_typeof(flags) = 'object')
);

create index question_items_bank_position_idx
  on public.question_items (bank_id, position);
create index attempts_user_updated_idx
  on public.attempts (user_id, updated_at desc);

alter table public.question_banks enable row level security;
alter table public.question_items enable row level security;
alter table public.question_keys enable row level security;
alter table public.attempts enable row level security;

grant select, insert, update, delete on public.question_banks to authenticated;
grant select, insert, update, delete on public.question_items to authenticated;
grant select, insert, update, delete on public.question_keys to authenticated;
grant select, insert, update, delete on public.attempts to authenticated;

create policy "owners read own banks and authenticated users read shared banks"
  on public.question_banks for select to authenticated
  using (owner_id = (select auth.uid()) or visibility = 'shared');

create policy "users create private banks"
  on public.question_banks for insert to authenticated
  with check (owner_id = (select auth.uid()) and visibility = 'private');

create policy "owners update private banks"
  on public.question_banks for update to authenticated
  using (owner_id = (select auth.uid()) and visibility = 'private')
  with check (owner_id = (select auth.uid()) and visibility = 'private');

create policy "owners delete own banks"
  on public.question_banks for delete to authenticated
  using (owner_id = (select auth.uid()));

create policy "read items in readable banks"
  on public.question_items for select to authenticated
  using (exists (
    select 1 from public.question_banks b
    where b.id = bank_id
      and (b.owner_id = (select auth.uid()) or b.visibility = 'shared')
  ));

create policy "owners add items to own private banks"
  on public.question_items for insert to authenticated
  with check (exists (
    select 1 from public.question_banks b
    where b.id = bank_id and b.owner_id = (select auth.uid())
      and b.visibility = 'private'
  ));

create policy "owners update items in own private banks"
  on public.question_items for update to authenticated
  using (exists (
    select 1 from public.question_banks b
    where b.id = bank_id and b.owner_id = (select auth.uid())
      and b.visibility = 'private'
  ))
  with check (exists (
    select 1 from public.question_banks b
    where b.id = bank_id and b.owner_id = (select auth.uid())
      and b.visibility = 'private'
  ));

create policy "owners delete items in own banks"
  on public.question_items for delete to authenticated
  using (exists (
    select 1 from public.question_banks b
    where b.id = bank_id and b.owner_id = (select auth.uid())
  ));

create policy "owners manage answer keys for own banks"
  on public.question_keys for all to authenticated
  using (exists (
    select 1 from public.question_items i
    join public.question_banks b on b.id = i.bank_id
    where i.id = question_id and b.owner_id = (select auth.uid())
  ))
  with check (exists (
    select 1 from public.question_items i
    join public.question_banks b on b.id = i.bank_id
    where i.id = question_id and b.owner_id = (select auth.uid())
  ));

create policy "users manage attempts for readable banks"
  on public.attempts for all to authenticated
  using (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.question_banks b
      where b.id = bank_id
        and (b.owner_id = (select auth.uid()) or b.visibility = 'shared')
    )
  )
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.question_banks b
      where b.id = bank_id
        and (b.owner_id = (select auth.uid()) or b.visibility = 'shared')
    )
  );

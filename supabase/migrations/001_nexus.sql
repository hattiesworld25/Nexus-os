-- Nimbus Cloud + Atlas Lakehouse schema. Run once in a fresh Supabase project.
create extension if not exists pgcrypto;

create table public.cloud_nodes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  parent_id uuid references public.cloud_nodes(id) on delete cascade,
  kind text not null check (kind in ('folder','file')),
  name text not null check (char_length(name) between 1 and 240),
  mime text,
  size bigint not null default 0 check (size >= 0),
  storage_path text,
  metadata jsonb not null default '{}'::jsonb,
  trashed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check ((kind='folder' and storage_path is null) or (kind='file' and storage_path is not null))
);
create index cloud_nodes_user_parent_idx on public.cloud_nodes(user_id,parent_id);
create index cloud_nodes_user_updated_idx on public.cloud_nodes(user_id,updated_at desc);

create table public.notes (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  title text not null default 'Untitled note', body text not null default '', trashed_at timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index notes_user_updated_idx on public.notes(user_id,updated_at desc);

create table public.contacts (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  name text not null, email text, phone text, company text, trashed_at timestamptz,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index contacts_user_name_idx on public.contacts(user_id,name);

create table public.events (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  title text not null, starts_at timestamptz not null, ends_at timestamptz not null,
  location text, notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  check (ends_at >= starts_at)
);
create index events_user_start_idx on public.events(user_id,starts_at);

create table public.tasks (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  title text not null, due_at timestamptz, completed boolean not null default false,
  priority text not null default 'normal' check(priority in ('low','normal','high')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index tasks_user_due_idx on public.tasks(user_id,completed,due_at);

create table public.shares (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  node_id uuid not null references public.cloud_nodes(id) on delete cascade,
  token text not null unique check(char_length(token) >= 24), expires_at timestamptz not null,
  created_at timestamptz not null default now()
);
create index shares_user_idx on public.shares(user_id);
create index shares_token_idx on public.shares(token);

create table public.datasets (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  name text not null, storage_path text not null, file_type text not null check(file_type in ('csv','json','parquet')),
  size bigint not null check(size >= 0), schema jsonb not null default '[]'::jsonb, row_count bigint,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
  unique(user_id,name)
);
create index datasets_user_idx on public.datasets(user_id,updated_at desc);

create table public.query_history (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  sql text not null, status text not null check(status in ('success','error')),
  duration_ms integer not null default 0, row_count integer not null default 0, error text,
  created_at timestamptz not null default now()
);
create index query_history_user_idx on public.query_history(user_id,created_at desc);

create table public.notebooks (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  name text not null, cells jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index notebooks_user_idx on public.notebooks(user_id,updated_at desc);

create table public.dashboards (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  name text not null, config jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index dashboards_user_idx on public.dashboards(user_id,updated_at desc);

create table public.pipelines (
  id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
  name text not null, sql text not null, status text not null default 'ready' check(status in ('ready','running','success','error')),
  last_run_at timestamptz, last_error text,
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index pipelines_user_idx on public.pipelines(user_id,updated_at desc);

create table public.ai_usage (
  user_id uuid not null references auth.users(id) on delete cascade,
  usage_date date not null default current_date, calls integer not null default 0 check(calls >= 0),
  primary key(user_id,usage_date)
);
alter table public.ai_usage enable row level security;
revoke all on public.ai_usage from anon, authenticated;

create or replace function public.reserve_ai_call(p_user uuid, p_limit integer)
returns boolean language plpgsql security definer set search_path = '' as $$
declare allowed boolean;
begin
  if p_limit < 1 or p_limit > 1000 then return false; end if;
  insert into public.ai_usage(user_id,usage_date,calls) values(p_user,current_date,1)
  on conflict(user_id,usage_date) do update set calls=public.ai_usage.calls+1
    where public.ai_usage.calls < p_limit
  returning true into allowed;
  return coalesce(allowed,false);
end $$;
revoke all on function public.reserve_ai_call(uuid,integer) from public,anon,authenticated;
grant execute on function public.reserve_ai_call(uuid,integer) to service_role;

create or replace function public.touch_updated_at() returns trigger
language plpgsql set search_path = '' as $$ begin new.updated_at=now(); return new; end $$;

do $$ declare t text; begin
  foreach t in array array['cloud_nodes','notes','contacts','events','tasks','datasets','notebooks','dashboards','pipelines'] loop
    execute format('create trigger %I_touch before update on public.%I for each row execute function public.touch_updated_at()',t,t);
  end loop;
end $$;

-- Owner-only grants and RLS for all client-facing tables.
do $$ declare t text; begin
  foreach t in array array['cloud_nodes','notes','contacts','events','tasks','shares','datasets','query_history','notebooks','dashboards','pipelines'] loop
    execute format('alter table public.%I enable row level security',t);
    execute format('revoke all on table public.%I from anon,authenticated',t);
    execute format('grant select,insert,update,delete on table public.%I to authenticated',t);
    execute format('create policy %I on public.%I for select to authenticated using ((select auth.uid())=user_id)',t||'_select_own',t);
    execute format('create policy %I on public.%I for insert to authenticated with check ((select auth.uid())=user_id)',t||'_insert_own',t);
    execute format('create policy %I on public.%I for update to authenticated using ((select auth.uid())=user_id) with check ((select auth.uid())=user_id)',t||'_update_own',t);
    execute format('create policy %I on public.%I for delete to authenticated using ((select auth.uid())=user_id)',t||'_delete_own',t);
  end loop;
end $$;

-- Prevent users from sharing another user's node even if a foreign id is guessed.
create schema if not exists private;
revoke all on schema private from public;
create or replace function private.share_node_owned(p_node uuid, p_user uuid) returns boolean
language sql stable security definer set search_path='' as $$
  select exists(select 1 from public.cloud_nodes where id=p_node and user_id=p_user and kind='file' and trashed_at is null)
$$;
revoke all on function private.share_node_owned(uuid,uuid) from public;
grant usage on schema private to authenticated;
grant execute on function private.share_node_owned(uuid,uuid) to authenticated;
drop policy shares_insert_own on public.shares;
create policy shares_insert_own on public.shares for insert to authenticated
with check ((select auth.uid())=user_id and private.share_node_owned(node_id,(select auth.uid())));

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types) values
('cloud-files','cloud-files',false,52428800,null),
('data-files','data-files',false,104857600,array['text/csv','application/json','application/x-ndjson','application/vnd.apache.parquet','application/octet-stream'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;

create policy cloud_storage_select_own on storage.objects for select to authenticated
using(bucket_id='cloud-files' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy cloud_storage_insert_own on storage.objects for insert to authenticated
with check(bucket_id='cloud-files' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy cloud_storage_update_own on storage.objects for update to authenticated
using(bucket_id='cloud-files' and (storage.foldername(name))[1]=(select auth.uid())::text)
with check(bucket_id='cloud-files' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy cloud_storage_delete_own on storage.objects for delete to authenticated
using(bucket_id='cloud-files' and (storage.foldername(name))[1]=(select auth.uid())::text);

create policy data_storage_select_own on storage.objects for select to authenticated
using(bucket_id='data-files' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy data_storage_insert_own on storage.objects for insert to authenticated
with check(bucket_id='data-files' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy data_storage_update_own on storage.objects for update to authenticated
using(bucket_id='data-files' and (storage.foldername(name))[1]=(select auth.uid())::text)
with check(bucket_id='data-files' and (storage.foldername(name))[1]=(select auth.uid())::text);
create policy data_storage_delete_own on storage.objects for delete to authenticated
using(bucket_id='data-files' and (storage.foldername(name))[1]=(select auth.uid())::text);

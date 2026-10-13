-- Max · Esquema v2
-- Ejecútalo UNA VEZ en Supabase → SQL Editor, ANTES de instalar la nueva versión de la app.
-- Es seguro repetirlo: usa "if not exists".

-- 1) Columnas nuevas en tablas existentes ---------------------------------------------
alter table public.categories    add column if not exists emoji text;
alter table public.savings_goals add column if not exists target_date timestamptz;
alter table public.credit_cards  add column if not exists payment_day integer;
alter table public.transactions  add column if not exists account_id uuid;
alter table public.transactions  add column if not exists receipt_path text;

-- 2) Cuentas (banco, ahorros, efectivo) ------------------------------------------------
create table if not exists public.accounts (
  id              uuid primary key,
  user_id         uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name            text not null,
  kind            text not null default 'Banco',
  initial_balance double precision not null default 0,
  is_deleted      boolean not null default false,
  updated_at      timestamptz not null default now()
);

alter table public.accounts enable row level security;

drop policy if exists "accounts_select_own" on public.accounts;
drop policy if exists "accounts_insert_own" on public.accounts;
drop policy if exists "accounts_update_own" on public.accounts;
drop policy if exists "accounts_delete_own" on public.accounts;

create policy "accounts_select_own" on public.accounts for select using (auth.uid() = user_id);
create policy "accounts_insert_own" on public.accounts for insert with check (auth.uid() = user_id);
create policy "accounts_update_own" on public.accounts for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "accounts_delete_own" on public.accounts for delete using (auth.uid() = user_id);

-- 3) Recibos: bucket privado, cada usuario solo ve su carpeta -------------------------
insert into storage.buckets (id, name, public)
values ('receipts', 'receipts', false)
on conflict (id) do nothing;

drop policy if exists "receipts_select_own" on storage.objects;
drop policy if exists "receipts_insert_own" on storage.objects;
drop policy if exists "receipts_update_own" on storage.objects;
drop policy if exists "receipts_delete_own" on storage.objects;

create policy "receipts_select_own" on storage.objects for select
  using (bucket_id = 'receipts' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "receipts_insert_own" on storage.objects for insert
  with check (bucket_id = 'receipts' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "receipts_update_own" on storage.objects for update
  using (bucket_id = 'receipts' and (storage.foldername(name))[1] = auth.uid()::text);
create policy "receipts_delete_own" on storage.objects for delete
  using (bucket_id = 'receipts' and (storage.foldername(name))[1] = auth.uid()::text);

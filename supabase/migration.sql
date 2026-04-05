-- ═══════════════════════════════════════════════════════════════════════════
-- PlatoDesk — COMPLETE MIGRATION SCRIPT
-- Run this in: app.supabase.com → SQL Editor → New query
--
-- SAFE TO RUN on an existing database — every statement uses IF NOT EXISTS
-- or checks before altering. Running it twice does nothing harmful.
-- ═══════════════════════════════════════════════════════════════════════════


-- ─────────────────────────────────────────────────────────────────────────────
-- BLOCK 1: restaurants — add subscription_renewed_at (Iteration 9)
-- ─────────────────────────────────────────────────────────────────────────────
do $$ begin
  if not exists (
    select 1 from information_schema.columns
    where table_name = 'restaurants' and column_name = 'subscription_renewed_at'
  ) then
    alter table restaurants add column subscription_renewed_at timestamptz;
  end if;
end $$;


-- ─────────────────────────────────────────────────────────────────────────────
-- BLOCK 2: orders — add needs_reprint (Iteration 4)
-- Set when a waiter edits an order that is already being prepared in kitchen,
-- so kitchen knows to reprint the updated ticket.
-- ─────────────────────────────────────────────────────────────────────────────
do $$ begin
  if not exists (
    select 1 from information_schema.columns
    where table_name = 'orders' and column_name = 'needs_reprint'
  ) then
    alter table orders add column needs_reprint boolean not null default false;
  end if;
end $$;


-- ─────────────────────────────────────────────────────────────────────────────
-- BLOCK 3: inventory_items — add unit_cost (Iteration 8)
-- Stores the last purchase price per unit; used to calculate stock value.
-- ─────────────────────────────────────────────────────────────────────────────
do $$ begin
  if not exists (
    select 1 from information_schema.columns
    where table_name = 'inventory_items' and column_name = 'unit_cost'
  ) then
    alter table inventory_items add column unit_cost numeric(10,2) not null default 0;
  end if;
end $$;


-- ─────────────────────────────────────────────────────────────────────────────
-- BLOCK 4: inventory_logs — add type and unit_cost (Iteration 8)
-- type distinguishes purchase / issue / adjustment entries.
-- unit_cost records the price at the time of each purchase for COGS reports.
-- ─────────────────────────────────────────────────────────────────────────────
-- ─────────────────────────────────────────────────────────────────────────────
-- BLOCK 4: inventory_logs — add type and unit_cost (Iteration 8)
-- type distinguishes purchase / issue / adjustment entries.
-- unit_cost records the price at the time of each purchase for COGS reports.
-- NOTE: The CHECK constraint is added separately from ADD COLUMN to avoid a
-- PostgreSQL quirk where inline CHECK constraints referencing a new column
-- fail inside a PL/pgSQL DO block (error 42703).
-- ─────────────────────────────────────────────────────────────────────────────
do $$ begin
  if not exists (
    select 1 from information_schema.columns
    where table_name = 'inventory_logs' and column_name = 'type'
  ) then
    alter table inventory_logs
      add column type text not null default 'adjustment';
  end if;
end $$;

-- Add the check constraint separately (idempotent — drops first if it exists)
alter table inventory_logs
  drop constraint if exists inventory_logs_type_check;
alter table inventory_logs
  add constraint inventory_logs_type_check
    check (type in ('adjustment', 'purchase', 'issue'));

do $$ begin
  if not exists (
    select 1 from information_schema.columns
    where table_name = 'inventory_logs' and column_name = 'unit_cost'
  ) then
    alter table inventory_logs add column unit_cost numeric(10,2) not null default 0;
  end if;
end $$;


-- ─────────────────────────────────────────────────────────────────────────────
-- BLOCK 5: subscription_payments table (Iteration 9)
-- Records every subscription payment attempt and its outcome.
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists subscription_payments (
  id                uuid primary key default uuid_generate_v4(),
  restaurant_id     uuid not null references restaurants(id) on delete cascade,
  plan              text not null,
  amount            numeric(10,2) not null,
  currency          text not null default 'PKR',
  payment_method    text not null,     -- easypaisa | jazzcash | card
  gateway           text not null,     -- safepay | stripe
  gateway_reference text,              -- Safepay tracker token or Stripe PaymentIntent id
  status            text not null default 'pending'
                      check (status in ('pending', 'paid', 'failed', 'refunded')),
  created_at        timestamptz not null default now(),
  paid_at           timestamptz
);


-- ─────────────────────────────────────────────────────────────────────────────
-- BLOCK 6: Ensure helper functions exist, then apply RLS for subscription_payments
--
-- current_restaurant_id() and current_staff_role() must exist before any
-- RLS policy that references them. CREATE OR REPLACE is idempotent — safe
-- whether the functions already exist or not.
-- ─────────────────────────────────────────────────────────────────────────────

-- Resolves the restaurant_id for the currently signed-in user.
-- SECURITY DEFINER runs as the function owner (postgres) so it can read the
-- staff table without triggering its own RLS policies (avoids infinite recursion).
create or replace function current_restaurant_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select restaurant_id
  from staff
  where auth_user_id = auth.uid()
    and is_active = true
  limit 1;
$$;

-- Resolves the role of the currently signed-in user.
create or replace function current_staff_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role
  from staff
  where auth_user_id = auth.uid()
    and is_active = true
  limit 1;
$$;

alter table subscription_payments enable row level security;

-- Drop old policies if re-running
drop policy if exists "sub_payments_select" on subscription_payments;
drop policy if exists "sub_payments_write"  on subscription_payments;
drop policy if exists "sub_payments_update" on subscription_payments;

-- Owner/manager can view payment history
create policy "sub_payments_select" on subscription_payments
  for select using (
    restaurant_id = current_restaurant_id()
    and current_staff_role() in ('owner', 'manager')
  );

-- The Flutter app inserts a pending row before redirecting to Safepay.
-- The Edge Function (service role, bypasses RLS) later updates it to paid/failed.
create policy "sub_payments_write" on subscription_payments
  for insert with check (
    restaurant_id = current_restaurant_id()
  );

-- No client-side update policy — status updates come from the Edge Function only.


-- ─────────────────────────────────────────────────────────────────────────────
-- BLOCK 7: Indexes for new columns and tables
-- ─────────────────────────────────────────────────────────────────────────────
create index if not exists idx_sub_payments_restaurant
  on subscription_payments (restaurant_id, created_at desc);

create index if not exists idx_sub_payments_status
  on subscription_payments (status);

create index if not exists idx_inventory_logs_type
  on inventory_logs (inventory_item_id, type, created_at desc);


-- ─────────────────────────────────────────────────────────────────────────────
-- BLOCK 8: staff billing metadata (Iteration 10 prep — safe to run now)
-- Needed for the staff billing lifecycle feature planned in Iteration 10.
-- ─────────────────────────────────────────────────────────────────────────────
do $$ begin
  if not exists (
    select 1 from information_schema.columns
    where table_name = 'staff' and column_name = 'activated_at'
  ) then
    alter table staff add column activated_at timestamptz;
  end if;
end $$;

do $$ begin
  if not exists (
    select 1 from information_schema.columns
    where table_name = 'staff' and column_name = 'billing_cycle_start'
  ) then
    alter table staff add column billing_cycle_start timestamptz;
  end if;
end $$;

do $$ begin
  if not exists (
    select 1 from information_schema.columns
    where table_name = 'staff' and column_name = 'is_billed_this_cycle'
  ) then
    alter table staff add column is_billed_this_cycle boolean not null default false;
  end if;
end $$;


-- ─────────────────────────────────────────────────────────────────────────────
-- VERIFICATION — run this SELECT after the migration to confirm all columns exist
-- ─────────────────────────────────────────────────────────────────────────────
select
  table_name,
  column_name,
  data_type,
  column_default
from information_schema.columns
where table_name in (
  'restaurants', 'orders', 'inventory_items',
  'inventory_logs', 'subscription_payments', 'staff'
)
and column_name in (
  'subscription_renewed_at',
  'needs_reprint',
  'unit_cost',
  'type',
  'gateway_reference',
  'activated_at',
  'billing_cycle_start',
  'is_billed_this_cycle'
)
order by table_name, column_name;

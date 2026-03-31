-- PlatoDesk — Supabase Schema
-- Safe to re-run: uses IF NOT EXISTS and DROP IF EXISTS throughout.
-- Run this in: app.supabase.com → SQL Editor → New query
-- Region: ap-south-1 (Mumbai)

-- ─────────────────────────────────────────────────────────────────────────────
-- Extensions
-- ─────────────────────────────────────────────────────────────────────────────
create extension if not exists "uuid-ossp";

-- ─────────────────────────────────────────────────────────────────────────────
-- restaurants
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists restaurants (
  id              uuid primary key default uuid_generate_v4(),
  name            text not null,
  owner_email     text not null,
  address         text not null default '',
  phone           text not null default '',
  plan            text not null default 'trial'
                    check (plan in ('trial','starter','standard','business','suspended')),
  trial_end_date  timestamptz,
  max_devices     int not null default 1,
  created_at      timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- staff
-- auth_user_id is nullable: NULL until an invited staff member signs up
-- ─────────────────────────────────────────────────────────────────────────────
create table if not exists staff (
  id                 uuid primary key default uuid_generate_v4(),
  invite_code        text unique,
  invite_expires_at  timestamptz,         -- null once claimed; set on invite creation
  restaurant_id      uuid not null references restaurants(id) on delete cascade,
  auth_user_id       uuid references auth.users(id) on delete cascade,  -- nullable for pending invites
  name               text not null,
  role               text not null default 'waiter'
                       check (role in ('owner','manager','waiter','kitchen')),
  device_name        text,
  is_active          boolean not null default true,
  added_at           timestamptz not null default now(),
  unique (restaurant_id, auth_user_id)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- App data tables (mirrors SQLite schema — restaurant_id on every table)
-- ─────────────────────────────────────────────────────────────────────────────

create table if not exists categories (
  id              bigserial primary key,
  uuid            text not null unique,
  restaurant_id   uuid not null references restaurants(id) on delete cascade,
  name            text not null,
  icon            text not null default 'restaurant',
  sort_order      int not null default 0,
  created_at      timestamptz not null default now()
);

create table if not exists menu_items (
  id              bigserial primary key,
  uuid            text not null unique,
  restaurant_id   uuid not null references restaurants(id) on delete cascade,
  category_id     bigint references categories(id) on delete set null,
  category_uuid   text not null,
  name            text not null,
  price           numeric(10,2) not null default 0,
  description     text,
  is_available    boolean not null default true,
  image_path      text,
  created_at      timestamptz not null default now()
);

create table if not exists cafe_tables (
  id              bigserial primary key,
  uuid            text not null unique,
  restaurant_id   uuid not null references restaurants(id) on delete cascade,
  name            text not null,
  capacity        int not null default 4,
  status          text not null default 'free'
                    check (status in ('free','occupied','reserved'))
);

create table if not exists customers (
  id              bigserial primary key,
  uuid            text not null unique,
  restaurant_id   uuid not null references restaurants(id) on delete cascade,
  name            text not null,
  phone           text,
  address         text,
  created_at      timestamptz not null default now()
);

create table if not exists orders (
  id              bigserial primary key,
  uuid            text not null unique,
  restaurant_id   uuid not null references restaurants(id) on delete cascade,
  type            text not null check (type in ('dine_in','takeaway','delivery')),
  table_uuid      text,
  table_id        bigint,
  customer_uuid   text,
  customer_id     bigint,
  delivery_address text,
  status          text not null default 'pending'
                    check (status in ('pending','preparing','ready','completed','cancelled')),
  discount_type   text not null default 'flat'
                    check (discount_type in ('flat','percent')),
  discount_value  numeric(10,2) not null default 0,
  tax_percent     numeric(5,2) not null default 0,
  subtotal        numeric(10,2) not null default 0,
  discount_amount numeric(10,2) not null default 0,
  tax_amount      numeric(10,2) not null default 0,
  total           numeric(10,2) not null default 0,
  note            text,
  created_at      timestamptz not null default now(),
  completed_at    timestamptz,
  is_locked       boolean not null default false
);

create table if not exists order_items (
  id              bigserial primary key,
  uuid            text not null unique,
  restaurant_id   uuid not null references restaurants(id) on delete cascade,
  order_id        bigint references orders(id) on delete cascade,
  order_uuid      text not null,
  menu_item_id    bigint references menu_items(id) on delete set null,
  menu_item_uuid  text not null,
  name_snapshot   text not null,
  price_snapshot  numeric(10,2) not null,
  quantity        int not null default 1,
  note            text
);

create table if not exists payments (
  id              bigserial primary key,
  uuid            text not null unique,
  restaurant_id   uuid not null references restaurants(id) on delete cascade,
  order_id        bigint unique references orders(id) on delete cascade,
  order_uuid      text not null unique,
  method          text not null check (method in ('cash','card')),
  amount_tendered numeric(10,2) not null default 0,
  change_amount   numeric(10,2) not null default 0,
  paid_at         timestamptz not null default now()
);

create table if not exists inventory_items (
  id                  bigserial primary key,
  uuid                text not null unique,
  restaurant_id       uuid not null references restaurants(id) on delete cascade,
  name                text not null,
  unit                text not null default 'kg',
  quantity            numeric(10,3) not null default 0,
  low_stock_threshold numeric(10,3) not null default 0,
  updated_at          timestamptz not null default now(),
  is_deleted          boolean not null default false
);

create table if not exists inventory_logs (
  id                  bigserial primary key,
  uuid                text not null unique,
  restaurant_id       uuid not null references restaurants(id) on delete cascade,
  inventory_item_id   bigint references inventory_items(id) on delete set null,
  inventory_item_uuid text not null,
  change_amount       numeric(10,3) not null,
  reason              text,
  created_at          timestamptz not null default now()
);

create table if not exists activity_logs (
  id              bigserial primary key,
  uuid            text not null unique,
  restaurant_id   uuid not null references restaurants(id) on delete cascade,
  action_type     text not null,
  entity_type     text,
  entity_id       text,
  entity_name     text,
  details         text,
  created_at      timestamptz not null default now()
);

create table if not exists expenses (
  id              bigserial primary key,
  uuid            text not null unique,
  restaurant_id   uuid not null references restaurants(id) on delete cascade,
  category        text not null default 'other',
  amount          numeric(10,2) not null,
  description     text not null default '',
  date            date not null,
  created_at      timestamptz not null default now()
);

create table if not exists billing_events (
  id              uuid primary key default uuid_generate_v4(),
  restaurant_id   uuid not null references restaurants(id) on delete cascade,
  device_id       uuid references staff(id) on delete set null,
  event_type      text not null check (event_type in ('device_added','device_removed','plan_changed')),
  created_at      timestamptz not null default now(),
  effective_date  timestamptz not null default now()
);

create table if not exists device_billing_snapshots (
  id              uuid primary key default uuid_generate_v4(),
  restaurant_id   uuid not null references restaurants(id) on delete cascade,
  period_start    timestamptz not null,
  device_count    int not null default 1,
  locked_at       timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- Migrations: add columns to existing tables if they don't exist yet
-- ─────────────────────────────────────────────────────────────────────────────
do $$ begin
  -- staff.invite_code (added for invite-code join flow)
  if not exists (
    select 1 from information_schema.columns
    where table_name = 'staff' and column_name = 'invite_code'
  ) then
    alter table staff add column invite_code text unique;
  end if;

  -- staff.auth_user_id: make nullable if it isn't already
  -- (pending invited staff have no auth account yet)
  alter table staff alter column auth_user_id drop not null;

exception when others then null; -- ignore if already nullable
end $$;

do $$ begin
  -- orders.is_locked (added in SQLite db v5 — must match here so sync push succeeds)
  if not exists (
    select 1 from information_schema.columns
    where table_name = 'orders' and column_name = 'is_locked'
  ) then
    alter table orders add column is_locked boolean not null default false;
  end if;
exception when others then null;
end $$;

do $$ begin
  -- staff.invite_expires_at (added for 72-hour invite code expiry)
  if not exists (
    select 1 from information_schema.columns
    where table_name = 'staff' and column_name = 'invite_expires_at'
  ) then
    alter table staff add column invite_expires_at timestamptz;
  end if;
exception when others then null;
end $$;

do $$ begin
  -- inventory_items.is_deleted (soft-delete flag; preserves inventory_logs history)
  if not exists (
    select 1 from information_schema.columns
    where table_name = 'inventory_items' and column_name = 'is_deleted'
  ) then
    alter table inventory_items add column is_deleted boolean not null default false;
  end if;
exception when others then null;
end $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- Row Level Security (RLS)
-- ─────────────────────────────────────────────────────────────────────────────

alter table restaurants              enable row level security;
alter table staff                    enable row level security;
alter table categories               enable row level security;
alter table menu_items               enable row level security;
alter table cafe_tables              enable row level security;
alter table customers                enable row level security;
alter table orders                   enable row level security;
alter table order_items              enable row level security;
alter table payments                 enable row level security;
alter table inventory_items          enable row level security;
alter table inventory_logs           enable row level security;
alter table activity_logs            enable row level security;
alter table expenses                 enable row level security;
alter table billing_events           enable row level security;
alter table device_billing_snapshots enable row level security;

-- Helper function: resolve restaurant_id for the signed-in user
-- SECURITY DEFINER is critical — without it, the function queries the staff
-- table which triggers its own RLS policy which calls this function again
-- → infinite recursion → "stack depth limit exceeded" (code 54001).
create or replace function current_restaurant_id()
returns uuid
language sql
stable
security definer                -- runs as function owner (postgres), bypasses RLS
set search_path = public        -- prevent search_path injection
as $$
  select restaurant_id
  from staff
  where auth_user_id = auth.uid()
    and is_active = true
  limit 1;
$$;

-- Helper function: resolve the role of the signed-in user.
-- Same SECURITY DEFINER pattern as current_restaurant_id() to avoid recursion.
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

-- ─────────────────────────────────────────────────────────────────────────────
-- claim_invite_code RPC
-- Atomically validates and claims an invite code for a newly signed-up user.
-- SECURITY DEFINER so it can read/update staff rows without open RLS policies.
-- Returns the claimed staff row on success; raises an exception on failure.
-- ─────────────────────────────────────────────────────────────────────────────
create or replace function claim_invite_code(p_code text)
returns json
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row staff%rowtype;
begin
  -- Atomically claim: only succeeds if code exists, is not yet linked, and has
  -- not expired. Clears both invite_code and invite_expires_at on success.
  update staff
  set auth_user_id      = auth.uid(),
      invite_code       = null,
      invite_expires_at = null
  where upper(invite_code) = upper(p_code)
    and auth_user_id is null
    and (invite_expires_at is null or invite_expires_at > now())
  returning * into v_row;

  if not found then
    -- Distinguish expired from invalid for a better user message
    if exists (
      select 1 from staff
      where upper(invite_code) = upper(p_code)
        and auth_user_id is null
        and invite_expires_at <= now()
    ) then
      raise exception 'expired_code'
        using hint = 'This invite code has expired. Ask your manager to generate a new one.';
    end if;
    raise exception 'invalid_or_used_code'
      using hint = 'The invite code is invalid or has already been used.';
  end if;

  return row_to_json(v_row);
end;
$$;

-- Drop existing policies before recreating (idempotent)
-- Includes both old blanket policy names and new split policy names so this
-- block is safe to re-run after partial migrations.
do $$ begin
  -- old blanket policies
  drop policy if exists "restaurant_select"       on restaurants;
  drop policy if exists "restaurant_insert"       on restaurants;
  drop policy if exists "restaurant_update"       on restaurants;
  drop policy if exists "staff_all"               on staff;
  drop policy if exists "staff_invite_select"     on staff;
  drop policy if exists "staff_insert_self"       on staff;
  drop policy if exists "staff_claim_invite"      on staff;
  drop policy if exists "categories_all"          on categories;
  drop policy if exists "menu_items_all"          on menu_items;
  drop policy if exists "cafe_tables_all"         on cafe_tables;
  drop policy if exists "customers_all"           on customers;
  drop policy if exists "orders_all"              on orders;
  drop policy if exists "order_items_all"         on order_items;
  drop policy if exists "payments_all"            on payments;
  drop policy if exists "inventory_items_all"     on inventory_items;
  drop policy if exists "inventory_logs_all"      on inventory_logs;
  drop policy if exists "activity_logs_all"       on activity_logs;
  drop policy if exists "expenses_all"            on expenses;
  drop policy if exists "billing_events_all"      on billing_events;
  drop policy if exists "snapshots_all"           on device_billing_snapshots;
  -- new split policies (safe to drop-if-exists so re-run is idempotent)
  drop policy if exists "restaurant_owner_update"     on restaurants;
  drop policy if exists "staff_select"                on staff;
  drop policy if exists "staff_owner_insert"          on staff;
  drop policy if exists "staff_owner_update"          on staff;
  drop policy if exists "staff_owner_delete"          on staff;
  drop policy if exists "categories_select"           on categories;
  drop policy if exists "categories_write"            on categories;
  drop policy if exists "categories_update"           on categories;
  drop policy if exists "categories_delete"           on categories;
  drop policy if exists "menu_items_select"           on menu_items;
  drop policy if exists "menu_items_write"            on menu_items;
  drop policy if exists "menu_items_update"           on menu_items;
  drop policy if exists "menu_items_delete"           on menu_items;
  drop policy if exists "cafe_tables_select"          on cafe_tables;
  drop policy if exists "cafe_tables_write"           on cafe_tables;
  drop policy if exists "cafe_tables_update"          on cafe_tables;
  drop policy if exists "cafe_tables_delete"          on cafe_tables;
  drop policy if exists "customers_select"            on customers;
  drop policy if exists "customers_write"             on customers;
  drop policy if exists "customers_update"            on customers;
  drop policy if exists "customers_delete"            on customers;
  drop policy if exists "orders_select"               on orders;
  drop policy if exists "orders_write"                on orders;
  drop policy if exists "orders_update"               on orders;
  drop policy if exists "orders_delete"               on orders;
  drop policy if exists "order_items_select"          on order_items;
  drop policy if exists "order_items_write"           on order_items;
  drop policy if exists "order_items_update"          on order_items;
  drop policy if exists "order_items_delete"          on order_items;
  drop policy if exists "payments_select"             on payments;
  drop policy if exists "payments_write"              on payments;
  drop policy if exists "payments_update"             on payments;
  drop policy if exists "payments_delete"             on payments;
  drop policy if exists "inventory_items_select"      on inventory_items;
  drop policy if exists "inventory_items_write"       on inventory_items;
  drop policy if exists "inventory_items_update"      on inventory_items;
  drop policy if exists "inventory_items_delete"      on inventory_items;
  drop policy if exists "inventory_logs_select"       on inventory_logs;
  drop policy if exists "inventory_logs_write"        on inventory_logs;
  drop policy if exists "inventory_logs_update"       on inventory_logs;
  drop policy if exists "inventory_logs_delete"       on inventory_logs;
  drop policy if exists "activity_logs_select"        on activity_logs;
  drop policy if exists "activity_logs_write"         on activity_logs;
  drop policy if exists "activity_logs_update"        on activity_logs;
  drop policy if exists "activity_logs_delete"        on activity_logs;
  drop policy if exists "expenses_select"             on expenses;
  drop policy if exists "expenses_write"              on expenses;
  drop policy if exists "expenses_update"             on expenses;
  drop policy if exists "expenses_delete"             on expenses;
  drop policy if exists "billing_events_select"       on billing_events;
  drop policy if exists "billing_events_write"        on billing_events;
  drop policy if exists "billing_events_update"       on billing_events;
  drop policy if exists "billing_events_delete"       on billing_events;
  drop policy if exists "snapshots_select"            on device_billing_snapshots;
  drop policy if exists "snapshots_write"             on device_billing_snapshots;
  drop policy if exists "snapshots_update"            on device_billing_snapshots;
  drop policy if exists "snapshots_delete"            on device_billing_snapshots;
end $$;

-- ── restaurants ───────────────────────────────────────────────────────────────
-- Any signed-in user can read their restaurant row.
create policy "restaurant_select" on restaurants
  for select using (id = current_restaurant_id());

-- Allowed during owner signup (no staff row exists yet, so current_restaurant_id() is null).
create policy "restaurant_insert" on restaurants
  for insert with check (true);

-- Only the owner may update restaurant settings (name, plan, etc.).
create policy "restaurant_owner_update" on restaurants
  for update using (
    id = current_restaurant_id()
    and current_staff_role() = 'owner'
  );

-- ── staff ─────────────────────────────────────────────────────────────────────
-- All active staff members can view their restaurant's staff list.
create policy "staff_select" on staff
  for select using (restaurant_id = current_restaurant_id());

-- Owner signup: lets a newly registered user insert their own owner staff row
-- before any restaurant/staff rows exist (current_restaurant_id() would be null).
create policy "staff_insert_self" on staff
  for insert with check (auth_user_id = auth.uid());

-- Only the owner can add new pending staff rows (invite flow).
create policy "staff_owner_insert" on staff
  for insert with check (
    restaurant_id = current_restaurant_id()
    and current_staff_role() = 'owner'
  );

-- Only the owner can change roles, deactivate, or re-activate staff.
create policy "staff_owner_update" on staff
  for update using (
    restaurant_id = current_restaurant_id()
    and current_staff_role() = 'owner'
  );

-- Only the owner can permanently remove a staff record.
create policy "staff_owner_delete" on staff
  for delete using (
    restaurant_id = current_restaurant_id()
    and current_staff_role() = 'owner'
  );

-- NOTE: The old "staff_invite_select" and "staff_claim_invite" open policies
-- have been intentionally removed. Invite code lookup and claim are handled
-- exclusively through the claim_invite_code() SECURITY DEFINER RPC, preventing
-- cross-restaurant invite code enumeration.

-- ── categories ────────────────────────────────────────────────────────────────
-- All roles can read (waiters/kitchen need the menu structure).
create policy "categories_select" on categories
  for select using (restaurant_id = current_restaurant_id());

-- Only owner/manager can create, edit, or remove categories.
create policy "categories_write" on categories
  for insert with check (
    restaurant_id = current_restaurant_id()
    and current_staff_role() in ('owner', 'manager')
  );
create policy "categories_update" on categories
  for update using (
    restaurant_id = current_restaurant_id()
    and current_staff_role() in ('owner', 'manager')
  );
create policy "categories_delete" on categories
  for delete using (
    restaurant_id = current_restaurant_id()
    and current_staff_role() in ('owner', 'manager')
  );

-- ── menu_items ────────────────────────────────────────────────────────────────
create policy "menu_items_select" on menu_items
  for select using (restaurant_id = current_restaurant_id());

create policy "menu_items_write" on menu_items
  for insert with check (
    restaurant_id = current_restaurant_id()
    and current_staff_role() in ('owner', 'manager')
  );
create policy "menu_items_update" on menu_items
  for update using (
    restaurant_id = current_restaurant_id()
    and current_staff_role() in ('owner', 'manager')
  );
create policy "menu_items_delete" on menu_items
  for delete using (
    restaurant_id = current_restaurant_id()
    and current_staff_role() in ('owner', 'manager')
  );

-- ── cafe_tables ───────────────────────────────────────────────────────────────
-- All roles read tables (waiter/kitchen need to see occupancy).
create policy "cafe_tables_select" on cafe_tables
  for select using (restaurant_id = current_restaurant_id());

-- Only owner/manager can create or delete tables.
create policy "cafe_tables_write" on cafe_tables
  for insert with check (
    restaurant_id = current_restaurant_id()
    and current_staff_role() in ('owner', 'manager')
  );

-- All roles can update table status (free ↔ occupied during order flow).
create policy "cafe_tables_update" on cafe_tables
  for update using (restaurant_id = current_restaurant_id());

create policy "cafe_tables_delete" on cafe_tables
  for delete using (
    restaurant_id = current_restaurant_id()
    and current_staff_role() in ('owner', 'manager')
  );

-- ── customers ─────────────────────────────────────────────────────────────────
-- All roles can look up and create customers (waiter creates delivery customers).
create policy "customers_select" on customers
  for select using (restaurant_id = current_restaurant_id());
create policy "customers_write" on customers
  for insert with check (restaurant_id = current_restaurant_id());
create policy "customers_update" on customers
  for update using (restaurant_id = current_restaurant_id());

-- Only owner/manager can delete customer records.
create policy "customers_delete" on customers
  for delete using (
    restaurant_id = current_restaurant_id()
    and current_staff_role() in ('owner', 'manager')
  );

-- ── orders ────────────────────────────────────────────────────────────────────
-- All roles can read, create, and update orders (status changes, adding items).
create policy "orders_select" on orders
  for select using (restaurant_id = current_restaurant_id());
create policy "orders_write" on orders
  for insert with check (restaurant_id = current_restaurant_id());
create policy "orders_update" on orders
  for update using (restaurant_id = current_restaurant_id());

-- Only owner/manager can hard-delete an order record.
create policy "orders_delete" on orders
  for delete using (
    restaurant_id = current_restaurant_id()
    and current_staff_role() in ('owner', 'manager')
  );

-- ── order_items ───────────────────────────────────────────────────────────────
-- All roles can manage order items (waiter adds/removes items).
create policy "order_items_select" on order_items
  for select using (restaurant_id = current_restaurant_id());
create policy "order_items_write" on order_items
  for insert with check (restaurant_id = current_restaurant_id());
create policy "order_items_update" on order_items
  for update using (restaurant_id = current_restaurant_id());
create policy "order_items_delete" on order_items
  for delete using (restaurant_id = current_restaurant_id());

-- ── payments ──────────────────────────────────────────────────────────────────
-- All roles can record and view payments.
create policy "payments_select" on payments
  for select using (restaurant_id = current_restaurant_id());
create policy "payments_write" on payments
  for insert with check (restaurant_id = current_restaurant_id());

-- Only owner/manager can void (update/delete) a payment record.
create policy "payments_update" on payments
  for update using (
    restaurant_id = current_restaurant_id()
    and current_staff_role() in ('owner', 'manager')
  );
create policy "payments_delete" on payments
  for delete using (
    restaurant_id = current_restaurant_id()
    and current_staff_role() in ('owner', 'manager')
  );

-- ── inventory_items ───────────────────────────────────────────────────────────
-- All roles can view stock levels (kitchen needs to see low-stock).
create policy "inventory_items_select" on inventory_items
  for select using (restaurant_id = current_restaurant_id());

-- Only owner/manager can add, adjust, or remove inventory items.
create policy "inventory_items_write" on inventory_items
  for insert with check (
    restaurant_id = current_restaurant_id()
    and current_staff_role() in ('owner', 'manager')
  );
create policy "inventory_items_update" on inventory_items
  for update using (
    restaurant_id = current_restaurant_id()
    and current_staff_role() in ('owner', 'manager')
  );
create policy "inventory_items_delete" on inventory_items
  for delete using (
    restaurant_id = current_restaurant_id()
    and current_staff_role() in ('owner', 'manager')
  );

-- ── inventory_logs ────────────────────────────────────────────────────────────
-- All roles can read and create logs (any device may record an adjustment).
create policy "inventory_logs_select" on inventory_logs
  for select using (restaurant_id = current_restaurant_id());
create policy "inventory_logs_write" on inventory_logs
  for insert with check (restaurant_id = current_restaurant_id());

-- Only owner/manager can delete log entries.
create policy "inventory_logs_update" on inventory_logs
  for update using (
    restaurant_id = current_restaurant_id()
    and current_staff_role() in ('owner', 'manager')
  );
create policy "inventory_logs_delete" on inventory_logs
  for delete using (
    restaurant_id = current_restaurant_id()
    and current_staff_role() in ('owner', 'manager')
  );

-- ── activity_logs ─────────────────────────────────────────────────────────────
-- All roles emit activity logs; all can read them.
create policy "activity_logs_select" on activity_logs
  for select using (restaurant_id = current_restaurant_id());
create policy "activity_logs_write" on activity_logs
  for insert with check (restaurant_id = current_restaurant_id());

-- Only owner/manager can update or purge log entries.
create policy "activity_logs_update" on activity_logs
  for update using (
    restaurant_id = current_restaurant_id()
    and current_staff_role() in ('owner', 'manager')
  );
create policy "activity_logs_delete" on activity_logs
  for delete using (
    restaurant_id = current_restaurant_id()
    and current_staff_role() in ('owner', 'manager')
  );

-- ── expenses ──────────────────────────────────────────────────────────────────
-- Only owner/manager can see or manage expenses (financial data).
create policy "expenses_select" on expenses
  for select using (
    restaurant_id = current_restaurant_id()
    and current_staff_role() in ('owner', 'manager')
  );
create policy "expenses_write" on expenses
  for insert with check (
    restaurant_id = current_restaurant_id()
    and current_staff_role() in ('owner', 'manager')
  );
create policy "expenses_update" on expenses
  for update using (
    restaurant_id = current_restaurant_id()
    and current_staff_role() in ('owner', 'manager')
  );
create policy "expenses_delete" on expenses
  for delete using (
    restaurant_id = current_restaurant_id()
    and current_staff_role() in ('owner', 'manager')
  );

-- ── billing_events ────────────────────────────────────────────────────────────
create policy "billing_events_select" on billing_events
  for select using (
    restaurant_id = current_restaurant_id()
    and current_staff_role() in ('owner', 'manager')
  );
create policy "billing_events_write" on billing_events
  for insert with check (
    restaurant_id = current_restaurant_id()
    and current_staff_role() in ('owner', 'manager')
  );
create policy "billing_events_update" on billing_events
  for update using (
    restaurant_id = current_restaurant_id()
    and current_staff_role() = 'owner'
  );
create policy "billing_events_delete" on billing_events
  for delete using (
    restaurant_id = current_restaurant_id()
    and current_staff_role() = 'owner'
  );

-- ── device_billing_snapshots ──────────────────────────────────────────────────
create policy "snapshots_select" on device_billing_snapshots
  for select using (
    restaurant_id = current_restaurant_id()
    and current_staff_role() in ('owner', 'manager')
  );
create policy "snapshots_write" on device_billing_snapshots
  for insert with check (
    restaurant_id = current_restaurant_id()
    and current_staff_role() in ('owner', 'manager')
  );
create policy "snapshots_update" on device_billing_snapshots
  for update using (
    restaurant_id = current_restaurant_id()
    and current_staff_role() = 'owner'
  );
create policy "snapshots_delete" on device_billing_snapshots
  for delete using (
    restaurant_id = current_restaurant_id()
    and current_staff_role() = 'owner'
  );

-- ─────────────────────────────────────────────────────────────────────────────
-- Indexes
-- ─────────────────────────────────────────────────────────────────────────────

create index if not exists idx_orders_restaurant     on orders          (restaurant_id, created_at desc);
create index if not exists idx_order_items_uuid      on order_items     (order_uuid);
create index if not exists idx_payments_uuid         on payments        (order_uuid);
create index if not exists idx_activity_logs         on activity_logs   (restaurant_id, created_at desc);
create index if not exists idx_expenses              on expenses        (restaurant_id, date desc);
create index if not exists idx_inventory_logs_uuid   on inventory_logs  (inventory_item_uuid);
create index if not exists idx_staff_auth_user       on staff           (auth_user_id);

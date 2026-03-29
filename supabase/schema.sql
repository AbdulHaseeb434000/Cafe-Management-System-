-- PlatoDesk — Supabase Schema
-- Run this in the Supabase SQL Editor (app.supabase.com → SQL Editor → New query)
-- Region: ap-south-1 (Mumbai)

-- ─────────────────────────────────────────────────────────────────────────────
-- Extensions
-- ─────────────────────────────────────────────────────────────────────────────
create extension if not exists "uuid-ossp";

-- ─────────────────────────────────────────────────────────────────────────────
-- restaurants
-- ─────────────────────────────────────────────────────────────────────────────
create table restaurants (
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
-- ─────────────────────────────────────────────────────────────────────────────
create table staff (
  id              uuid primary key default uuid_generate_v4(),
  restaurant_id   uuid not null references restaurants(id) on delete cascade,
  auth_user_id    uuid not null references auth.users(id) on delete cascade,
  name            text not null,
  role            text not null default 'waiter'
                    check (role in ('owner','manager','waiter','kitchen')),
  device_name     text,
  is_active       boolean not null default true,
  added_at        timestamptz not null default now(),
  unique (restaurant_id, auth_user_id)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- App data tables (mirrors SQLite schema — restaurant_id added to every table)
-- ─────────────────────────────────────────────────────────────────────────────

create table categories (
  id              bigserial primary key,
  uuid            text not null unique,
  restaurant_id   uuid not null references restaurants(id) on delete cascade,
  name            text not null,
  icon            text not null default 'restaurant',
  sort_order      int not null default 0,
  created_at      timestamptz not null default now()
);

create table menu_items (
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

create table cafe_tables (
  id              bigserial primary key,
  uuid            text not null unique,
  restaurant_id   uuid not null references restaurants(id) on delete cascade,
  name            text not null,
  capacity        int not null default 4,
  status          text not null default 'free'
                    check (status in ('free','occupied','reserved'))
);

create table customers (
  id              bigserial primary key,
  uuid            text not null unique,
  restaurant_id   uuid not null references restaurants(id) on delete cascade,
  name            text not null,
  phone           text,
  address         text,
  created_at      timestamptz not null default now()
);

create table orders (
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
  completed_at    timestamptz
);

create table order_items (
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

create table payments (
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

create table inventory_items (
  id              bigserial primary key,
  uuid            text not null unique,
  restaurant_id   uuid not null references restaurants(id) on delete cascade,
  name            text not null,
  unit            text not null default 'kg',
  quantity        numeric(10,3) not null default 0,
  low_stock_threshold numeric(10,3) not null default 0,
  updated_at      timestamptz not null default now()
);

create table inventory_logs (
  id              bigserial primary key,
  uuid            text not null unique,
  restaurant_id   uuid not null references restaurants(id) on delete cascade,
  inventory_item_id bigint references inventory_items(id) on delete set null,
  inventory_item_uuid text not null,
  change_amount   numeric(10,3) not null,
  reason          text,
  created_at      timestamptz not null default now()
);

create table activity_logs (
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

-- ─────────────────────────────────────────────────────────────────────────────
-- Billing / subscription tracking
-- ─────────────────────────────────────────────────────────────────────────────

create table billing_events (
  id              uuid primary key default uuid_generate_v4(),
  restaurant_id   uuid not null references restaurants(id) on delete cascade,
  device_id       uuid references staff(id) on delete set null,
  event_type      text not null check (event_type in ('device_added','device_removed','plan_changed')),
  created_at      timestamptz not null default now(),
  effective_date  timestamptz not null default now()
);

create table device_billing_snapshots (
  id              uuid primary key default uuid_generate_v4(),
  restaurant_id   uuid not null references restaurants(id) on delete cascade,
  period_start    timestamptz not null,
  device_count    int not null default 1,
  locked_at       timestamptz not null default now()
);

-- ─────────────────────────────────────────────────────────────────────────────
-- Row Level Security (RLS)
-- Each restaurant can only access its own data.
-- ─────────────────────────────────────────────────────────────────────────────

alter table restaurants         enable row level security;
alter table staff               enable row level security;
alter table categories          enable row level security;
alter table menu_items          enable row level security;
alter table cafe_tables         enable row level security;
alter table customers           enable row level security;
alter table orders              enable row level security;
alter table order_items         enable row level security;
alter table payments            enable row level security;
alter table inventory_items     enable row level security;
alter table inventory_logs      enable row level security;
alter table activity_logs       enable row level security;
alter table billing_events      enable row level security;
alter table device_billing_snapshots enable row level security;

-- Helper function: get restaurant_id for the current auth user
create or replace function current_restaurant_id()
returns uuid
language sql
stable
as $$
  select restaurant_id
  from staff
  where auth_user_id = auth.uid()
    and is_active = true
  limit 1;
$$;

-- restaurants: user can only see their own restaurant
create policy "restaurant_select" on restaurants
  for select using (id = current_restaurant_id());

create policy "restaurant_insert" on restaurants
  for insert with check (true); -- allowed during signup

create policy "restaurant_update" on restaurants
  for update using (id = current_restaurant_id());

-- staff: users in the same restaurant
create policy "staff_all" on staff
  for all using (restaurant_id = current_restaurant_id());

-- All app data tables: scoped to current restaurant
create policy "categories_all"      on categories      for all using (restaurant_id = current_restaurant_id());
create policy "menu_items_all"      on menu_items      for all using (restaurant_id = current_restaurant_id());
create policy "cafe_tables_all"     on cafe_tables     for all using (restaurant_id = current_restaurant_id());
create policy "customers_all"       on customers       for all using (restaurant_id = current_restaurant_id());
create policy "orders_all"          on orders          for all using (restaurant_id = current_restaurant_id());
create policy "order_items_all"     on order_items     for all using (restaurant_id = current_restaurant_id());
create policy "payments_all"        on payments        for all using (restaurant_id = current_restaurant_id());
create policy "inventory_items_all" on inventory_items for all using (restaurant_id = current_restaurant_id());
create policy "inventory_logs_all"  on inventory_logs  for all using (restaurant_id = current_restaurant_id());
create policy "activity_logs_all"   on activity_logs   for all using (restaurant_id = current_restaurant_id());
create policy "billing_events_all"  on billing_events  for all using (restaurant_id = current_restaurant_id());
create policy "snapshots_all"       on device_billing_snapshots for all using (restaurant_id = current_restaurant_id());

-- ─────────────────────────────────────────────────────────────────────────────
-- Indexes for common query patterns
-- ─────────────────────────────────────────────────────────────────────────────

create index on orders          (restaurant_id, created_at desc);
create index on order_items     (order_uuid);
create index on payments        (order_uuid);
create index on activity_logs   (restaurant_id, created_at desc);
create index on inventory_logs  (inventory_item_uuid);
create index on staff           (auth_user_id);

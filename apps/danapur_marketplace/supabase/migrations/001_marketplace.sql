-- Apply to a dedicated Supabase project in SQL Editor. Safe to run again.
-- No sample shops or products are inserted into the shared database.
begin;
create extension if not exists pgcrypto;

create table if not exists public.shops (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null unique references auth.users(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 3 and 80),
  category text not null check (category in ('Grocery','Electronics','Fashion','Home','Food & sweets')),
  area text not null check (area in ('Danapur Bazaar','Saguna More','Gola Road','RPS More','Takiyapar','Nasriganj','Bibiganj','Other in Danapur')),
  address text not null check (char_length(btrim(address)) between 6 and 180),
  phone text not null check (phone ~ '^[6-9][0-9]{9}$'),
  description text not null default '' check (char_length(description) <= 400),
  hours text not null default '' check (char_length(hours) <= 80),
  is_published boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create table if not exists public.products (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  name text not null check (char_length(btrim(name)) between 3 and 100),
  category text not null check (category in ('Grocery','Electronics','Fashion','Home','Food & sweets')),
  price_paise bigint not null check (price_paise between 1 and 100000000),
  mrp_paise bigint check (mrp_paise is null or (mrp_paise >= price_paise and mrp_paise <= 100000000)),
  unit text not null default 'each' check (char_length(btrim(unit)) between 1 and 32),
  description text not null default '' check (char_length(description) <= 800),
  image_url text check (image_url is null or (image_url like 'https://%' and char_length(image_url) <= 2048)),
  illustration text not null default 'bag' check (illustration in ('bag','rice','earbuds','shirt','pan','oil','watch','sweets','milk')),
  is_available boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists shops_area_category_idx on public.shops(area, category);
create index if not exists products_shop_idx on public.products(shop_id);
create index if not exists products_category_price_idx on public.products(category, price_paise);

create or replace function public.marketplace_stamp()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if TG_OP = 'UPDATE' then
    if NEW.id <> OLD.id then raise exception 'Listing IDs cannot change'; end if;
    if TG_TABLE_NAME = 'shops' then
      if NEW.owner_id <> OLD.owner_id then raise exception 'Shop ownership cannot change'; end if;
    else
      if NEW.shop_id <> OLD.shop_id then raise exception 'Product shop cannot change'; end if;
    end if;
    NEW.created_at := OLD.created_at;
  else
    NEW.created_at := now();
  end if;
  NEW.updated_at := now();
  return NEW;
end;
$$;
drop trigger if exists shops_stamp on public.shops;
create trigger shops_stamp before insert or update on public.shops for each row execute function public.marketplace_stamp();
drop trigger if exists products_stamp on public.products;
create trigger products_stamp before insert or update on public.products for each row execute function public.marketplace_stamp();

alter table public.shops enable row level security;
alter table public.products enable row level security;
grant usage on schema public to anon, authenticated;
grant select on public.shops, public.products to anon, authenticated;
grant insert, update, delete on public.shops, public.products to authenticated;

drop policy if exists shops_read on public.shops;
create policy shops_read on public.shops for select to anon, authenticated
  using (is_published or owner_id = (select auth.uid()));
drop policy if exists shops_insert on public.shops;
create policy shops_insert on public.shops for insert to authenticated with check (owner_id = (select auth.uid()));
drop policy if exists shops_update on public.shops;
create policy shops_update on public.shops for update to authenticated
  using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()));
drop policy if exists shops_delete on public.shops;
create policy shops_delete on public.shops for delete to authenticated using (owner_id = (select auth.uid()));

drop policy if exists products_read on public.products;
create policy products_read on public.products for select to anon, authenticated using (
  exists (select 1 from public.shops s where s.id = shop_id and (s.is_published or s.owner_id = (select auth.uid())))
);
drop policy if exists products_insert on public.products;
create policy products_insert on public.products for insert to authenticated with check (
  exists (select 1 from public.shops s where s.id = shop_id and s.owner_id = (select auth.uid()))
);
drop policy if exists products_update on public.products;
create policy products_update on public.products for update to authenticated using (
  exists (select 1 from public.shops s where s.id = shop_id and s.owner_id = (select auth.uid()))
) with check (
  exists (select 1 from public.shops s where s.id = shop_id and s.owner_id = (select auth.uid()))
);
drop policy if exists products_delete on public.products;
create policy products_delete on public.products for delete to authenticated using (
  exists (select 1 from public.shops s where s.id = shop_id and s.owner_id = (select auth.uid()))
);

-- Photos are public by design. Do not upload personal/confidential documents.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('catalog-media', 'catalog-media', true, 524288, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = true, file_size_limit = excluded.file_size_limit, allowed_mime_types = excluded.allowed_mime_types;
drop policy if exists catalog_media_read on storage.objects;
create policy catalog_media_read on storage.objects for select to anon, authenticated using (bucket_id = 'catalog-media');
drop policy if exists catalog_media_insert on storage.objects;
create policy catalog_media_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'catalog-media' and (storage.foldername(name))[1] = (select auth.uid())::text
    and exists (select 1 from public.shops s where s.owner_id = (select auth.uid())));
drop policy if exists catalog_media_delete on storage.objects;
create policy catalog_media_delete on storage.objects for delete to authenticated
  using (bucket_id = 'catalog-media' and (storage.foldername(name))[1] = (select auth.uid())::text);
commit;

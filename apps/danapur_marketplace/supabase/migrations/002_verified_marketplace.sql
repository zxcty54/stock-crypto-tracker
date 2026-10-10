-- Run after 001_marketplace.sql, in a DEDICATED Supabase project's SQL Editor.
-- Idempotent production extension. Never installs an admin or invents prices.
begin;

create table if not exists public.market_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
alter table public.market_admins enable row level security;
revoke all on public.market_admins from anon, authenticated;
grant select on public.market_admins to authenticated;
drop policy if exists admin_self_read on public.market_admins;
create policy admin_self_read on public.market_admins for select to authenticated using (user_id = (select auth.uid()));
create or replace function public.is_market_admin() returns boolean language sql stable security definer
  set search_path = public, pg_catalog as $$
  select exists(select 1 from public.market_admins where user_id = auth.uid());
$$;
revoke all on function public.is_market_admin() from public;
grant execute on function public.is_market_admin() to anon, authenticated;

alter table public.shops drop constraint if exists shops_category_check;
alter table public.products drop constraint if exists products_category_check;
alter table public.shops add constraint shops_category_check check (category in ('Grocery','Electronics','Fashion','Home','Food & sweets','Hardware','Furniture','Electrical','Building materials','Books & stationery','Pharmacy & healthcare','Automotive','Jewellery','Fresh produce','Sports & toys','Other'));
alter table public.products add constraint products_category_check check (category in ('Grocery','Electronics','Fashion','Home','Food & sweets','Hardware','Furniture','Electrical','Building materials','Books & stationery','Pharmacy & healthcare','Automotive','Jewellery','Fresh produce','Sports & toys','Other'));
alter table public.shops add column if not exists business_type text not null default 'Retailer';
alter table public.shops add column if not exists review_status text not null default 'pending';
alter table public.shops add column if not exists verification_photo_path text;
alter table public.shops add column if not exists review_note text not null default '';
alter table public.shops add column if not exists reviewed_by uuid references auth.users(id) on delete set null;
alter table public.shops add column if not exists reviewed_at timestamptz;
alter table public.shops add column if not exists whatsapp_checked boolean not null default false;
alter table public.shops drop constraint if exists shops_business_type_check;
alter table public.shops add constraint shops_business_type_check check (business_type in ('Retailer','Wholesaler','Retailer & wholesaler'));
alter table public.shops drop constraint if exists shops_review_status_check;
alter table public.shops add constraint shops_review_status_check check (review_status in ('pending','approved','rejected','suspended'));
alter table public.shops drop constraint if exists shops_review_note_check;
alter table public.shops add constraint shops_review_note_check check (char_length(review_note) <= 400);
alter table public.shops drop constraint if exists shops_proof_path_check;
alter table public.shops add constraint shops_proof_path_check check (verification_photo_path is null or (verification_photo_path like owner_id::text || '/%' and verification_photo_path !~ '\.\.' and char_length(verification_photo_path) <= 200));
alter table public.shops drop constraint if exists shops_approved_proof_check;
alter table public.shops add constraint shops_approved_proof_check check (review_status <> 'approved' or (verification_photo_path is not null and whatsapp_checked and reviewed_at is not null));
create index if not exists shops_review_idx on public.shops(review_status, created_at);

create table if not exists public.market_settings (
  id integer primary key default 1 check(id = 1),
  verification_phone text not null default '' check(verification_phone = '' or verification_phone ~ '^[6-9][0-9]{9}$'),
  support_email text not null default '' check(char_length(support_email) <= 254),
  privacy_url text not null default '' check(privacy_url = '' or (privacy_url like 'https://%' and char_length(privacy_url) <= 500)),
  terms_url text not null default '' check(terms_url = '' or (terms_url like 'https://%' and char_length(terms_url) <= 500)),
  mandi_name text not null default 'Danapur Mandi' check(char_length(btrim(mandi_name)) between 3 and 80),
  updated_at timestamptz not null default now()
);
insert into public.market_settings(id) values(1) on conflict(id) do nothing;
alter table public.market_settings enable row level security;
grant select on public.market_settings to anon, authenticated;
revoke insert, update, delete on public.market_settings from anon, authenticated;
drop policy if exists settings_read on public.market_settings;
create policy settings_read on public.market_settings for select to anon, authenticated using(true);

create table if not exists public.mandi_items (
  id text primary key check(id ~ '^[a-z][a-z0-9_-]{1,49}$'),
  name text not null check(char_length(btrim(name)) between 2 and 80),
  hindi_name text not null check(char_length(btrim(hindi_name)) between 1 and 80),
  category text not null check(category in ('Vegetables','Fruits')),
  default_unit text not null default 'kg' check(default_unit in ('kg','dozen','piece','bunch','100 kg')),
  is_active boolean not null default true
);
create table if not exists public.mandi_rates (
  id uuid primary key default gen_random_uuid(),
  item_id text not null references public.mandi_items(id),
  price_type text not null check(price_type in ('wholesale','retail')),
  unit text not null check(unit in ('kg','dozen','piece','bunch','100 kg')),
  min_paise bigint not null check(min_paise between 1 and 100000000),
  max_paise bigint not null check(max_paise between min_paise and 100000000),
  effective_date date not null,
  note text not null default '' check(char_length(note) <= 160),
  updated_by uuid references auth.users(id) on delete set null,
  updated_at timestamptz not null default now(),
  unique(item_id, price_type, effective_date)
);
create index if not exists mandi_latest_idx on public.mandi_rates(item_id, price_type, effective_date desc);
alter table public.mandi_items enable row level security;
alter table public.mandi_rates enable row level security;
grant select on public.mandi_items, public.mandi_rates to anon, authenticated;
revoke insert, update, delete on public.mandi_items, public.mandi_rates from anon, authenticated;
drop policy if exists mandi_items_read on public.mandi_items;
create policy mandi_items_read on public.mandi_items for select to anon, authenticated using(is_active or public.is_market_admin());
drop policy if exists mandi_rates_read on public.mandi_rates;
create policy mandi_rates_read on public.mandi_rates for select to anon, authenticated using(exists(select 1 from public.mandi_items i where i.id = item_id and i.is_active) or public.is_market_admin());
create or replace view public.current_mandi_rates with(security_invoker=true) as
  select distinct on(item_id, price_type) * from public.mandi_rates
  where effective_date <= (now() at time zone 'Asia/Kolkata')::date
  order by item_id, price_type, effective_date desc, updated_at desc;
grant select on public.current_mandi_rates to anon, authenticated;

create table if not exists public.market_audit (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references auth.users(id) on delete set null,
  action text not null,
  target text not null,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);
alter table public.market_audit enable row level security;
grant select on public.market_audit to authenticated;
revoke insert, update, delete on public.market_audit from anon, authenticated;
drop policy if exists audit_admin_read on public.market_audit;
create policy audit_admin_read on public.market_audit for select to authenticated using(public.is_market_admin());

create or replace function public.shop_review_guard() returns trigger language plpgsql
  set search_path = public, pg_catalog as $$
begin
  if auth.uid() is not null and not public.is_market_admin() then
    if TG_OP = 'INSERT' then
      if NEW.review_status <> 'pending' or NEW.review_note <> '' or NEW.reviewed_by is not null or NEW.reviewed_at is not null or NEW.whatsapp_checked then
        raise exception 'Only an administrator can review shops' using errcode='42501';
      end if;
      if NEW.verification_photo_path is null then raise exception 'A private storefront photo is required'; end if;
    else
      if NEW.review_status <> OLD.review_status or NEW.review_note <> OLD.review_note or NEW.reviewed_by is distinct from OLD.reviewed_by or NEW.reviewed_at is distinct from OLD.reviewed_at or NEW.whatsapp_checked <> OLD.whatsapp_checked then
        raise exception 'Only an administrator can review shops' using errcode='42501';
      end if;
      if (NEW.name,NEW.address,NEW.phone,NEW.category,NEW.business_type,NEW.area,NEW.verification_photo_path) is distinct from (OLD.name,OLD.address,OLD.phone,OLD.category,OLD.business_type,OLD.area,OLD.verification_photo_path) then
        if OLD.review_status = 'suspended' then raise exception 'Contact the administrator before changing a suspended shop'; end if;
        NEW.review_status := 'pending'; NEW.review_note := ''; NEW.reviewed_by := null; NEW.reviewed_at := null; NEW.whatsapp_checked := false;
      end if;
    end if;
    if NEW.verification_photo_path is not null and not exists(select 1 from storage.objects o where o.bucket_id='shop-verification' and o.name=NEW.verification_photo_path) then
      raise exception 'Upload the storefront photo before submitting';
    end if;
  end if;
  return NEW;
end;
$$;
drop trigger if exists shop_review_guard on public.shops;
create trigger shop_review_guard before insert or update on public.shops for each row execute function public.shop_review_guard();

-- Replace old public visibility. Pending/rejected/suspended shops stay private.
drop policy if exists shops_read on public.shops;
create policy shops_read on public.shops for select to anon, authenticated using((is_published and review_status='approved') or owner_id=(select auth.uid()) or public.is_market_admin());
drop policy if exists shops_insert on public.shops;
create policy shops_insert on public.shops for insert to authenticated with check(owner_id=(select auth.uid()) and review_status='pending');
drop policy if exists products_read on public.products;
create policy products_read on public.products for select to anon, authenticated using(exists(select 1 from public.shops s where s.id=shop_id and ((s.is_published and s.review_status='approved') or s.owner_id=(select auth.uid()) or public.is_market_admin())));

-- A dedicated private bucket: no public URL, owner/admin access only.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('shop-verification','shop-verification',false,524288,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=false,file_size_limit=excluded.file_size_limit,allowed_mime_types=excluded.allowed_mime_types;
drop policy if exists proof_read on storage.objects;
create policy proof_read on storage.objects for select to authenticated using(bucket_id='shop-verification' and ((storage.foldername(name))[1]=(select auth.uid())::text or public.is_market_admin()));
create or replace function public.can_upload_shop_proof() returns boolean language plpgsql security definer set search_path=public,pg_catalog as $$
begin
 if auth.uid() is null then return false; end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text,0));
 return (select count(*) from storage.objects o where o.bucket_id='shop-verification' and (storage.foldername(o.name))[1]=auth.uid()::text) < 4;
end;
$$;
revoke all on function public.can_upload_shop_proof() from public;
grant execute on function public.can_upload_shop_proof() to authenticated;
drop policy if exists proof_insert on storage.objects;
create policy proof_insert on storage.objects for insert to authenticated with check(bucket_id='shop-verification' and (storage.foldername(name))[1]=(select auth.uid())::text and public.can_upload_shop_proof());
drop policy if exists proof_delete on storage.objects;
create policy proof_delete on storage.objects for delete to authenticated using(bucket_id='shop-verification' and (storage.foldername(name))[1]=(select auth.uid())::text and not exists(select 1 from public.shops s where s.verification_photo_path=storage.objects.name));

create or replace function public.review_market_shop(p_shop_id uuid, p_decision text, p_note text, p_whatsapp_checked boolean)
returns void language plpgsql security definer set search_path=public,pg_catalog as $$
begin
  if not public.is_market_admin() then raise exception 'Administrator access required' using errcode='42501'; end if;
  if p_decision not in ('approved','rejected','suspended') then raise exception 'Invalid review decision'; end if;
  if char_length(btrim(p_note)) not between 3 and 400 then raise exception 'A review note of 3-400 characters is required'; end if;
  if p_decision='approved' and (not p_whatsapp_checked or not exists(select 1 from public.shops s join storage.objects o on o.name=s.verification_photo_path and o.bucket_id='shop-verification' where s.id=p_shop_id)) then
    raise exception 'Check the uploaded storefront photo and WhatsApp proof before approval';
  end if;
  update public.shops set review_status=p_decision, review_note=btrim(p_note), reviewed_by=auth.uid(), reviewed_at=now(), whatsapp_checked=p_whatsapp_checked where id=p_shop_id;
  if not found then raise exception 'Shop request not found'; end if;
  insert into public.market_audit(actor_id,action,target,details) values(auth.uid(),'shop_'||p_decision,p_shop_id::text,jsonb_build_object('note',btrim(p_note),'whatsapp_checked',p_whatsapp_checked));
end;
$$;
revoke all on function public.review_market_shop(uuid,text,text,boolean) from public;
grant execute on function public.review_market_shop(uuid,text,text,boolean) to authenticated;

create or replace function public.set_mandi_rate(p_item_id text,p_price_type text,p_unit text,p_min_paise bigint,p_max_paise bigint,p_effective_date date,p_note text)
returns void language plpgsql security definer set search_path=public,pg_catalog as $$
begin
  if not public.is_market_admin() then raise exception 'Administrator access required' using errcode='42501'; end if;
  if p_effective_date > (now() at time zone 'Asia/Kolkata')::date or p_effective_date < '2020-01-01'::date then raise exception 'Use today or a valid past market date'; end if;
  if not exists(select 1 from public.mandi_items where id=p_item_id and is_active) then raise exception 'Commodity not found or inactive'; end if;
  insert into public.mandi_rates(item_id,price_type,unit,min_paise,max_paise,effective_date,note,updated_by)
    values(p_item_id,p_price_type,p_unit,p_min_paise,p_max_paise,p_effective_date,btrim(p_note),auth.uid())
    on conflict(item_id,price_type,effective_date) do update set unit=excluded.unit,min_paise=excluded.min_paise,max_paise=excluded.max_paise,note=excluded.note,updated_by=auth.uid(),updated_at=now();
  insert into public.market_audit(actor_id,action,target,details) values(auth.uid(),'mandi_rate_updated',p_item_id,jsonb_build_object('type',p_price_type,'unit',p_unit,'date',p_effective_date,'min_paise',p_min_paise,'max_paise',p_max_paise));
end;
$$;
revoke all on function public.set_mandi_rate(text,text,text,bigint,bigint,date,text) from public;
grant execute on function public.set_mandi_rate(text,text,text,bigint,bigint,date,text) to authenticated;

create or replace function public.set_market_settings(p_phone text,p_email text,p_privacy_url text,p_terms_url text,p_mandi_name text)
returns void language plpgsql security definer set search_path=public,pg_catalog as $$
begin
  if not public.is_market_admin() then raise exception 'Administrator access required' using errcode='42501'; end if;
  update public.market_settings set verification_phone=btrim(p_phone),support_email=btrim(p_email),privacy_url=btrim(p_privacy_url),terms_url=btrim(p_terms_url),mandi_name=btrim(p_mandi_name),updated_at=now() where id=1;
  insert into public.market_audit(actor_id,action,target) values(auth.uid(),'settings_updated','market_settings');
end;
$$;
revoke all on function public.set_market_settings(text,text,text,text,text) from public;
grant execute on function public.set_market_settings(text,text,text,text,text) to authenticated;

create or replace function public.delete_market_account() returns void language plpgsql security definer set search_path=public,pg_catalog as $$
begin
  if auth.uid() is null then raise exception 'Sign in first' using errcode='42501'; end if;
  lock table public.market_admins in share row exclusive mode;
  if public.is_market_admin() and (select count(*) from public.market_admins) < 2 then raise exception 'Create another administrator before deleting the last admin account'; end if;
  delete from auth.users where id=auth.uid();
end;
$$;
revoke all on function public.delete_market_account() from public;
grant execute on function public.delete_market_account() to authenticated;
create or replace function public.can_delete_market_account() returns boolean language sql stable security definer set search_path=public,pg_catalog as $$
 select auth.uid() is not null and (not public.is_market_admin() or (select count(*) from public.market_admins) > 1);
$$;
revoke all on function public.can_delete_market_account() from public;
grant execute on function public.can_delete_market_account() to authenticated;

create or replace function public.add_mandi_item(p_id text,p_name text,p_hindi text,p_category text,p_unit text)
returns void language plpgsql security definer set search_path=public,pg_catalog as $$
begin
 if not public.is_market_admin() then raise exception 'Administrator access required' using errcode='42501'; end if;
 insert into public.mandi_items(id,name,hindi_name,category,default_unit) values(p_id,btrim(p_name),btrim(p_hindi),p_category,p_unit);
 insert into public.market_audit(actor_id,action,target) values(auth.uid(),'commodity_added',p_id);
end;
$$;
revoke all on function public.add_mandi_item(text,text,text,text,text) from public;
grant execute on function public.add_mandi_item(text,text,text,text,text) to authenticated;
commit;

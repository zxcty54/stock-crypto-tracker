-- Run after 001 + 002. Cash-only commerce; no gateway or fake payment receipts.
begin;
alter table public.shops add column if not exists is_open boolean not null default true;
alter table public.shops add column if not exists offers_delivery boolean not null default false;
alter table public.shops add column if not exists latitude double precision;
alter table public.shops add column if not exists longitude double precision;
alter table public.shops add column if not exists delivery_base_paise bigint not null default 0;
alter table public.shops add column if not exists paid_through timestamptz;
alter table public.shops add column if not exists is_sample boolean not null default false;
alter table public.shops drop constraint if exists shop_delivery_config;
alter table public.shops add constraint shop_delivery_config check(delivery_base_paise between 0 and 10000000 and ((latitude is null and longitude is null) or (latitude between -90 and 90 and longitude between -180 and 180)) and (not offers_delivery or (latitude is not null and longitude is not null)));
alter table public.products add column if not exists discount_paise bigint not null default 0;
alter table public.products add column if not exists delivery_allowed boolean not null default false;
alter table public.products add column if not exists delivery_extra_paise bigint not null default 0;
alter table public.products add column if not exists is_sample boolean not null default false;
alter table public.products drop constraint if exists product_cash_pricing;
alter table public.products add constraint product_cash_pricing check(discount_paise between 0 and price_paise-1 and delivery_extra_paise between 0 and 10000000);
alter table public.market_settings add column if not exists billing_enabled boolean not null default false;
alter table public.market_settings add column if not exists billing_started_at timestamptz;
alter table public.market_settings add column if not exists monthly_fee_paise bigint not null default 29900 check(monthly_fee_paise=29900);

-- Keep the display names consistent with Flutter's expanded directory.
alter table public.shops drop constraint if exists shops_category_check;
alter table public.products drop constraint if exists products_category_check;
alter table public.shops add constraint shops_category_check check(category in ('Grocery','Electronics','Fashion','Home','Food & sweets','Hardware','Furniture','Electrical','Building materials','Books & stationery','Pharmacy & healthcare','Automotive','Jewellery','Fresh produce','Sports & toys','Other','Footwear','Garments','Photography','Mobile & accessories','Computer & accessories','Beauty & cosmetics','Bags & luggage','Kitchen & appliances','Dairy','Meat & fish','Bakery','Restaurant & snacks','Optical','Watches','Baby & kids','Pet supplies','Agriculture & seeds','Paints & plumbing','Tools & machinery','Handicrafts & gifts','Tailoring','Repairs & services','Printing & signage','Books & education'));
alter table public.products add constraint products_category_check check(category in ('Grocery','Electronics','Fashion','Home','Food & sweets','Hardware','Furniture','Electrical','Building materials','Books & stationery','Pharmacy & healthcare','Automotive','Jewellery','Fresh produce','Sports & toys','Other','Footwear','Garments','Photography','Mobile & accessories','Computer & accessories','Beauty & cosmetics','Bags & luggage','Kitchen & appliances','Dairy','Meat & fish','Bakery','Restaurant & snacks','Optical','Watches','Baby & kids','Pet supplies','Agriculture & seeds','Paints & plumbing','Tools & machinery','Handicrafts & gifts','Tailoring','Repairs & services','Printing & signage','Books & education'));

create or replace function public.cash_shop_guard() returns trigger language plpgsql set search_path=public,pg_catalog as $$
begin
 if auth.uid() is not null and not public.is_market_admin() then
  if TG_OP='INSERT' then
   if NEW.paid_through is not null or NEW.is_sample then raise exception 'Only admin can assign membership/sample records' using errcode='42501'; end if;
  else
   if NEW.paid_through is distinct from OLD.paid_through or NEW.is_sample <> OLD.is_sample then raise exception 'Only admin can assign membership/sample records' using errcode='42501'; end if;
   if (NEW.latitude,NEW.longitude) is distinct from (OLD.latitude,OLD.longitude) then
    if OLD.review_status='suspended' then raise exception 'Contact admin before moving a suspended shop'; end if;
    NEW.review_status:='pending'; NEW.review_note:=''; NEW.reviewed_by:=null; NEW.reviewed_at:=null; NEW.whatsapp_checked:=false;
   end if;
  end if;
 end if;
 return NEW;
end;
$$;
drop trigger if exists zz_cash_shop_guard on public.shops;
create trigger zz_cash_shop_guard before insert or update on public.shops for each row execute function public.cash_shop_guard();
create or replace function public.product_sample_guard() returns trigger language plpgsql set search_path=public,pg_catalog as $$
begin
 if auth.uid() is not null and not public.is_market_admin() and (TG_OP='INSERT' and NEW.is_sample or TG_OP='UPDATE' and NEW.is_sample <> OLD.is_sample) then raise exception 'Only admin can tag sample records' using errcode='42501'; end if;
 return NEW;
end;
$$;
drop trigger if exists product_sample_guard on public.products;
create trigger product_sample_guard before insert or update on public.products for each row execute function public.product_sample_guard();

create or replace function public.shop_membership_active(p_shop uuid) returns boolean language sql stable security definer set search_path=public,pg_catalog as $$
 select coalesce((select not m.billing_enabled or s.paid_through>now() or now()<m.billing_started_at+interval '30 days' from public.shops s cross join public.market_settings m where s.id=p_shop and m.id=1),false);
$$;
revoke all on function public.shop_membership_active(uuid) from public;
grant execute on function public.shop_membership_active(uuid) to anon,authenticated;

create table if not exists public.cash_orders (
 id uuid primary key default gen_random_uuid(), request_id uuid not null,
 buyer_id uuid references auth.users(id) on delete set null,
 seller_id uuid references auth.users(id) on delete set null,
 shop_id uuid references public.shops(id) on delete set null,
 shop_name text not null, shop_category text not null,
 customer_name text not null check(char_length(btrim(customer_name)) between 2 and 80),
 customer_phone text not null check(customer_phone ~ '^[6-9][0-9]{9}$'),
 address text not null check(char_length(btrim(address)) between 6 and 300),
 fulfilment text not null check(fulfilment in ('delivery','pickup')),
 latitude double precision, longitude double precision, distance_m double precision,
 subtotal_paise bigint not null check(subtotal_paise between 1 and 1000000000),
 discount_paise bigint not null check(discount_paise >= 0),
 delivery_paise bigint not null check(delivery_paise >= 0),
 total_paise bigint not null check(total_paise=subtotal_paise-discount_paise+delivery_paise and total_paise between 1 and 1000000000),
 status text not null default 'placed' check(status in ('placed','accepted','ready','completed','cancelled')),
 status_note text not null default '' check(char_length(status_note)<=300),
 is_sample boolean not null default false,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 closed_by uuid references auth.users(id) on delete set null,
 unique(buyer_id,request_id),
 check(fulfilment <> 'delivery' or (latitude between -90 and 90 and longitude between -180 and 180 and distance_m between 0 and 500))
);
create table if not exists public.cash_order_lines (
 id uuid primary key default gen_random_uuid(), order_id uuid not null references public.cash_orders(id) on delete cascade,
 product_id uuid references public.products(id) on delete set null,
 name text not null, category text not null, unit text not null,
 quantity integer not null check(quantity between 1 and 100),
 base_paise bigint not null, discount_paise bigint not null, delivery_extra_paise bigint not null
);
create index if not exists orders_buyer_time on public.cash_orders(buyer_id,created_at desc);
create index if not exists orders_seller_time on public.cash_orders(seller_id,created_at desc);
create index if not exists order_lines_order on public.cash_order_lines(order_id);
alter table public.cash_orders enable row level security;
alter table public.cash_order_lines enable row level security;
revoke all on public.cash_orders,public.cash_order_lines from anon,authenticated;
grant select on public.cash_orders,public.cash_order_lines to authenticated;
drop policy if exists order_participant_read on public.cash_orders;
create policy order_participant_read on public.cash_orders for select to authenticated using(buyer_id=(select auth.uid()) or seller_id=(select auth.uid()));
drop policy if exists order_line_participant_read on public.cash_order_lines;
create policy order_line_participant_read on public.cash_order_lines for select to authenticated using(exists(select 1 from public.cash_orders o where o.id=order_id));

create table if not exists public.personal_expenses (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 order_id uuid unique references public.cash_orders(id) on delete cascade,
 amount_paise bigint not null check(amount_paise between 1 and 1000000000),
 category text not null check(char_length(btrim(category)) between 1 and 80),
 note text not null default '' check(char_length(note)<=300),
 spent_on date not null, is_sample boolean not null default false,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index if not exists expenses_user_date on public.personal_expenses(user_id,spent_on desc);
alter table public.personal_expenses enable row level security;
revoke all on public.personal_expenses from anon,authenticated;
grant select on public.personal_expenses to authenticated;
drop policy if exists expense_own_read on public.personal_expenses;
create policy expense_own_read on public.personal_expenses for select to authenticated using(user_id=(select auth.uid()));

create or replace function public.distance_metres(a_lat double precision,a_lon double precision,b_lat double precision,b_lon double precision)
returns double precision language sql immutable set search_path=pg_catalog as $$
 select 6371000.0*2*asin(least(1.0,sqrt(power(sin(radians(b_lat-a_lat)/2),2)+cos(radians(a_lat))*cos(radians(b_lat))*power(sin(radians(b_lon-a_lon)/2),2))));
$$;
revoke all on function public.distance_metres(double precision,double precision,double precision,double precision) from public;
grant execute on function public.distance_metres(double precision,double precision,double precision,double precision) to authenticated;

create or replace function public.place_cash_order(p_shop uuid,p_items jsonb,p_mode text,p_name text,p_phone text,p_address text,p_lat double precision,p_lon double precision,p_accuracy double precision,p_measured_at timestamptz,p_request uuid)
returns uuid language plpgsql security definer set search_path=public,pg_catalog as $$
declare s public.shops; p public.products; item jsonb; qty integer; sub bigint:=0; disc bigint:=0; shipping bigint:=0; dist double precision; oid uuid;
begin
 if auth.uid() is null then raise exception 'Sign in to order' using errcode='42501'; end if;
 if p_request is null then raise exception 'Order request ID required'; end if;
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||p_request::text,1));
 select id into oid from public.cash_orders where buyer_id=auth.uid() and request_id=p_request;
 if found then return oid; end if;
 if jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items) not between 1 and 20 then raise exception 'Cart must contain 1-20 products'; end if;
 if p_mode not in ('delivery','pickup') then raise exception 'Choose delivery or shop pickup'; end if;
 select * into s from public.shops where id=p_shop for share;
 if not found or not s.is_open or not s.is_published or s.review_status<>'approved' then raise exception 'Shop is closed, hidden or not approved'; end if;
 if s.owner_id=auth.uid() then raise exception 'You cannot order from your own shop'; end if;
 if not public.shop_membership_active(p_shop) then raise exception 'This shop is not currently accepting app orders'; end if;
 if p_mode='delivery' then
  if not s.offers_delivery or s.latitude is null or p_lat is null or p_lon is null or not(p_lat between -90 and 90 and p_lon between -180 and 180) then raise exception 'Delivery needs shop coordinates and your current location'; end if;
  if p_accuracy is null or p_accuracy<0 or p_accuracy>50 or p_measured_at is null or p_measured_at<now()-interval '2 minutes' or p_measured_at>now()+interval '30 seconds' then raise exception 'Get a recent accurate location or choose pickup'; end if;
  dist:=public.distance_metres(s.latitude,s.longitude,p_lat,p_lon);
  if dist>500 then raise exception 'Home-delivery COD is limited to a 500 m straight-line radius. Choose pickup'; end if;
  shipping:=s.delivery_base_paise;
 end if;
 if (select count(distinct (value->>'product_id')) from jsonb_array_elements(p_items)) <> jsonb_array_length(p_items) then raise exception 'Combine duplicate cart lines'; end if;
 for item in select value from jsonb_array_elements(p_items) loop
  qty:=(item->>'quantity')::integer;
  if qty is null or qty not between 1 and 100 then raise exception 'Quantity must be 1-100 listed units'; end if;
  select * into p from public.products where id=(item->>'product_id')::uuid and shop_id=p_shop for share;
  if not found or not p.is_available then raise exception 'A cart product is unavailable or belongs to another shop'; end if;
  if p_mode='delivery' and not p.delivery_allowed then raise exception 'One product is pickup-only. Choose pickup or remove it'; end if;
  sub:=sub+p.price_paise*qty; disc:=disc+p.discount_paise*qty;
  if p_mode='delivery' then shipping:=shipping+p.delivery_extra_paise*qty; end if;
 end loop;
 insert into public.cash_orders(request_id,buyer_id,seller_id,shop_id,shop_name,shop_category,customer_name,customer_phone,address,fulfilment,latitude,longitude,distance_m,subtotal_paise,discount_paise,delivery_paise,total_paise,is_sample)
 values(p_request,auth.uid(),s.owner_id,s.id,s.name,s.category,btrim(p_name),btrim(p_phone),btrim(p_address),p_mode,case when p_mode='delivery' then p_lat end,case when p_mode='delivery' then p_lon end,dist,sub,disc,shipping,sub-disc+shipping,s.is_sample) returning id into oid;
 for item in select value from jsonb_array_elements(p_items) loop
  select * into p from public.products where id=(item->>'product_id')::uuid;
  insert into public.cash_order_lines(order_id,product_id,name,category,unit,quantity,base_paise,discount_paise,delivery_extra_paise)
  values(oid,p.id,p.name,p.category,p.unit,(item->>'quantity')::integer,p.price_paise,p.discount_paise,case when p_mode='delivery' then p.delivery_extra_paise else 0 end);
 end loop;
 return oid;
end;
$$;
revoke all on function public.place_cash_order(uuid,jsonb,text,text,text,text,double precision,double precision,double precision,timestamptz,uuid) from public;
grant execute on function public.place_cash_order(uuid,jsonb,text,text,text,text,double precision,double precision,double precision,timestamptz,uuid) to authenticated;

create or replace function public.change_cash_order(p_id uuid,p_status text,p_note text)
returns void language plpgsql security definer set search_path=public,pg_catalog as $$
declare o public.cash_orders;
begin
 select * into o from public.cash_orders where id=p_id for update;
 if not found or auth.uid() is null or (auth.uid() is distinct from o.buyer_id and auth.uid() is distinct from o.seller_id) then raise exception 'Only this buyer/seller can update the order' using errcode='42501'; end if;
 if o.status in ('completed','cancelled') then
  if o.status=p_status then return; end if;
  raise exception 'Closed orders cannot change';
 end if;
 if p_status not in ('accepted','ready','completed','cancelled') then raise exception 'Invalid order status'; end if;
 if p_status in ('accepted','ready') and auth.uid() is distinct from o.seller_id then raise exception 'Only seller can accept/prepare' using errcode='42501'; end if;
 if p_status='accepted' and o.status<>'placed' or p_status='ready' and o.status not in ('placed','accepted') then raise exception 'Order status cannot move backwards'; end if;
 if char_length(btrim(p_note)) not between 3 and 300 then raise exception 'Add a short status/cancellation note'; end if;
 update public.cash_orders set status=p_status,status_note=btrim(p_note),updated_at=now(),closed_by=case when p_status in ('completed','cancelled') then auth.uid() end where id=p_id;
 if p_status='completed' and o.buyer_id is not null then
  insert into public.personal_expenses(user_id,order_id,amount_paise,category,note,spent_on,is_sample)
   values(o.buyer_id,o.id,o.total_paise,o.shop_category,'Order at '||o.shop_name,(now() at time zone 'Asia/Kolkata')::date,o.is_sample) on conflict(order_id) do nothing;
 end if;
end;
$$;
revoke all on function public.change_cash_order(uuid,text,text) from public;
grant execute on function public.change_cash_order(uuid,text,text) to authenticated;

create or replace function public.save_personal_expense(p_id uuid,p_amount bigint,p_category text,p_note text,p_date date)
returns void language plpgsql security definer set search_path=public,pg_catalog as $$
begin
 if auth.uid() is null then raise exception 'Sign in first' using errcode='42501'; end if;
 if p_date is null or p_date>(now() at time zone 'Asia/Kolkata')::date or p_date<'2020-01-01' then raise exception 'Use today or a valid past expense date'; end if;
 if p_id is null then insert into public.personal_expenses(user_id,amount_paise,category,note,spent_on) values(auth.uid(),p_amount,btrim(p_category),btrim(p_note),p_date);
 else
  update public.personal_expenses set amount_paise=p_amount,category=btrim(p_category),note=btrim(p_note),spent_on=p_date,updated_at=now() where id=p_id and user_id=auth.uid() and order_id is null;
  if not found then raise exception 'Only your manual expenses can be edited' using errcode='42501'; end if;
 end if;
end;
$$;
revoke all on function public.save_personal_expense(uuid,bigint,text,text,date) from public;
grant execute on function public.save_personal_expense(uuid,bigint,text,text,date) to authenticated;
create or replace function public.delete_personal_expense(p_id uuid) returns void language plpgsql security definer set search_path=public,pg_catalog as $$
begin
 if auth.uid() is null then raise exception 'Sign in first' using errcode='42501'; end if;
 delete from public.personal_expenses where id=p_id and user_id=auth.uid() and order_id is null;
 if not found then raise exception 'Only your manual expenses can be removed' using errcode='42501'; end if;
end;
$$;
revoke all on function public.delete_personal_expense(uuid) from public;
grant execute on function public.delete_personal_expense(uuid) to authenticated;

create or replace function public.configure_cash_billing(p_enabled boolean) returns void language plpgsql security definer set search_path=public,pg_catalog as $$
begin
 if not public.is_market_admin() then raise exception 'Admin only' using errcode='42501'; end if;
 update public.market_settings set billing_enabled=p_enabled,billing_started_at=case when p_enabled then coalesce(billing_started_at,now()) else billing_started_at end,updated_at=now() where id=1;
 insert into public.market_audit(actor_id,action,target,details) values(auth.uid(),'billing_switch','market_settings',jsonb_build_object('enabled',p_enabled,'monthly_paise',29900));
end;
$$;
revoke all on function public.configure_cash_billing(boolean) from public;
grant execute on function public.configure_cash_billing(boolean) to authenticated;
create or replace function public.extend_shop_membership(p_shop uuid,p_until timestamptz,p_note text) returns void language plpgsql security definer set search_path=public,pg_catalog as $$
begin
 if not public.is_market_admin() then raise exception 'Admin only' using errcode='42501'; end if;
 if p_until is null or p_until<=now() or char_length(btrim(p_note)) not between 3 and 300 then raise exception 'Choose a future access date and note'; end if;
 update public.shops set paid_through=p_until where id=p_shop;
 if not found then raise exception 'Shop not found'; end if;
 insert into public.market_audit(actor_id,action,target,details) values(auth.uid(),'membership_extended',p_shop::text,jsonb_build_object('until',p_until,'note',btrim(p_note),'online_payment',false));
end;
$$;
revoke all on function public.extend_shop_membership(uuid,timestamptz,text) from public;
grant execute on function public.extend_shop_membership(uuid,timestamptz,text) to authenticated;
create or replace function public.purge_sample_catalog() returns void language plpgsql security definer set search_path=public,pg_catalog as $$
begin
 if not public.is_market_admin() then raise exception 'Admin only' using errcode='42501'; end if;
 delete from public.cash_orders where is_sample;
 delete from public.personal_expenses where is_sample;
 delete from public.products where is_sample;
 delete from public.shops where is_sample;
 insert into public.market_audit(actor_id,action,target) values(auth.uid(),'sample_catalog_removed','sample_records_only');
end;
$$;
revoke all on function public.purge_sample_catalog() from public;
grant execute on function public.purge_sample_catalog() to authenticated;
create or replace function public.can_delete_market_account() returns boolean language sql stable security definer set search_path=public,pg_catalog as $$
 select auth.uid() is not null and (not public.is_market_admin() or (select count(*) from public.market_admins)>1)
 and not exists(select 1 from public.cash_orders where (buyer_id=auth.uid() or seller_id=auth.uid()) and status not in ('completed','cancelled'));
$$;
revoke all on function public.can_delete_market_account() from public;
grant execute on function public.can_delete_market_account() to authenticated;
create or replace function public.delete_market_account() returns void language plpgsql security definer set search_path=public,pg_catalog as $$
begin
 if auth.uid() is null then raise exception 'Sign in first' using errcode='42501'; end if;
 lock table public.market_admins in share row exclusive mode;
 if not public.can_delete_market_account() then raise exception 'Close pending orders first; the last admin also needs a replacement'; end if;
 delete from auth.users where id=auth.uid();
end;
$$;
revoke all on function public.delete_market_account() from public;
grant execute on function public.delete_market_account() to authenticated;
-- Approval authority is the admin panel. WhatsApp is optional extra evidence.
create or replace function public.review_cash_shop(p_shop_id uuid,p_decision text,p_note text,p_photo_checked boolean)
returns void language plpgsql security definer set search_path=public,pg_catalog as $$
begin
 if not public.is_market_admin() then raise exception 'Administrator access required' using errcode='42501'; end if;
 if p_decision not in ('approved','rejected','suspended') or char_length(btrim(p_note)) not between 3 and 400 then raise exception 'Choose a valid decision and review note'; end if;
 if p_decision='approved' and (not p_photo_checked or not exists(select 1 from public.shops s join storage.objects o on o.bucket_id='shop-verification' and o.name=s.verification_photo_path where s.id=p_shop_id)) then raise exception 'Review the private storefront photo before approval'; end if;
 -- Legacy schema review flag retained for backwards-compatible 002 constraints;
 -- this function does NOT assert that WhatsApp messages were read/verified.
 update public.shops set review_status=p_decision,review_note=btrim(p_note),reviewed_by=auth.uid(),reviewed_at=now(),whatsapp_checked=p_photo_checked where id=p_shop_id;
 if not found then raise exception 'Shop request not found'; end if;
 insert into public.market_audit(actor_id,action,target,details) values(auth.uid(),'shop_'||p_decision,p_shop_id::text,jsonb_build_object('photo_reviewed',p_photo_checked,'note',btrim(p_note),'whatsapp_required',false));
end;
$$;
revoke all on function public.review_cash_shop(uuid,text,text,boolean) from public;
grant execute on function public.review_cash_shop(uuid,text,text,boolean) to authenticated;
create or replace function public.guard_active_shop_orders() returns trigger language plpgsql security definer set search_path=public,pg_catalog as $$
begin
 if exists(select 1 from public.cash_orders where shop_id=OLD.id and status not in ('completed','cancelled')) then raise exception 'Complete or cancel open orders before deleting this shop'; end if;
 return OLD;
end;
$$;
drop trigger if exists guard_active_shop_orders on public.shops;
create trigger guard_active_shop_orders before delete on public.shops for each row execute function public.guard_active_shop_orders();
commit;

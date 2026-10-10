-- Aangan: Bihar-first rentals with private contact, moderated listings and chat.
-- Apply this migration in the Supabase SQL editor (or with `supabase db push`).

begin;

create extension if not exists pgcrypto;

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  username text,
  full_name text not null default 'Aangan member' check (char_length(full_name) between 1 and 80),
  account_type text not null default 'seeker' check (account_type in ('seeker', 'owner', 'broker')),
  phone_number text check (phone_number is null or char_length(phone_number) between 7 and 32),
  phone_visible boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Additive columns also support projects that already had the old StockPulse
-- `profiles` table. Existing public profile fields are left intact.
alter table public.profiles
  add column if not exists username text,
  add column if not exists full_name text not null default 'Aangan member',
  add column if not exists account_type text not null default 'seeker',
  add column if not exists phone_number text,
  add column if not exists phone_visible boolean not null default false,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

create table if not exists public.user_roles (
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null check (role in ('admin', 'moderator')),
  granted_at timestamptz not null default now(),
  primary key (user_id, role)
);

create table if not exists public.listings (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users (id) on delete cascade,
  title text not null check (char_length(title) between 8 and 90),
  description text not null check (char_length(description) between 20 and 1200),
  district text not null check (char_length(district) between 2 and 80),
  town text not null check (char_length(town) between 2 and 100),
  block text not null check (char_length(block) between 2 and 100),
  locality text not null check (char_length(locality) between 2 and 140),
  road text not null default '',
  landmark text not null default '',
  pincode text not null default '' check (pincode = '' or pincode ~ '^[0-9]{6}$'),
  property_type text not null check (property_type in (
    'Apartment', 'Independent floor', 'Independent house', 'Studio', 'PG / shared home'
  )),
  furnishing text not null check (furnishing in ('Unfurnished', 'Semi-furnished', 'Furnished')),
  lister_type text not null check (lister_type in ('owner', 'broker')),
  broker_fee text not null default 'No brokerage' check (broker_fee in (
    'No brokerage', 'Half month rent', 'One month rent', 'Discuss before visit'
  )),
  host_name text not null check (char_length(host_name) between 1 and 80),
  monthly_rent integer not null check (monthly_rent between 1 and 10000000),
  deposit integer not null default 0 check (deposit between 0 and 100000000),
  bedrooms smallint not null default 1 check (bedrooms between 0 and 10),
  bathrooms smallint not null default 1 check (bathrooms between 1 and 10),
  area_sqft integer not null check (area_sqft between 1 and 100000),
  rent_negotiable boolean not null default false,
  maintenance_included boolean not null default false,
  show_exact_address boolean not null default false,
  available_from date,
  amenities text[] not null default '{}',
  tenant_rules jsonb not null default '{}'::jsonb check (jsonb_typeof(tenant_rules) = 'object'),
  photo_paths text[] not null default '{}',
  status text not null default 'pending' check (status in ('pending', 'published', 'rejected', 'paused', 'rented')),
  rejection_note text not null default '' check (char_length(rejection_note) <= 500),
  approved_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists listings_public_search_idx
  on public.listings (district, town, block, monthly_rent)
  where status = 'published';
create index if not exists listings_owner_created_idx
  on public.listings (owner_id, created_at desc);
create index if not exists listings_pending_created_idx
  on public.listings (created_at asc)
  where status = 'pending';
create index if not exists listings_rules_gin_idx
  on public.listings using gin (tenant_rules);

create table if not exists public.listing_reports (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings (id) on delete cascade,
  reporter_id uuid not null references auth.users (id) on delete cascade,
  reason text not null check (char_length(reason) between 5 and 300),
  created_at timestamptz not null default now(),
  unique (listing_id, reporter_id)
);

create table if not exists public.listing_reviews (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings (id) on delete cascade,
  admin_id uuid not null references auth.users (id),
  decision text not null check (decision in ('published', 'rejected')),
  note text not null default '' check (char_length(note) <= 500),
  created_at timestamptz not null default now()
);

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null references public.listings (id) on delete cascade,
  listing_title text not null,
  buyer_id uuid not null references auth.users (id) on delete cascade,
  seller_id uuid not null references auth.users (id) on delete cascade,
  last_message_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  unique (listing_id, buyer_id),
  check (buyer_id <> seller_id)
);
create index if not exists conversations_buyer_idx
  on public.conversations (buyer_id, last_message_at desc);
create index if not exists conversations_seller_idx
  on public.conversations (seller_id, last_message_at desc);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  sender_id uuid not null references auth.users (id) on delete cascade,
  body text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now()
);
create index if not exists messages_conversation_created_idx
  on public.messages (conversation_id, created_at asc);

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = public, pg_temp
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.user_roles
    where user_id = auth.uid() and role = 'admin'
  );
$$;

-- Used by the private Storage bucket policy. This exposes only a boolean and
-- intentionally checks the approved status without exposing address columns.
create or replace function public.is_published_listing(p_listing_id text)
returns boolean
language sql
stable
security definer
set search_path = public, pg_temp
as $$
  select exists (
    select 1 from public.listings
    where id::text = p_listing_id and status = 'published'
  );
$$;

create or replace function public.admin_review_listing(
  p_listing_id uuid,
  p_decision text,
  p_note text default null
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_admin_id uuid := auth.uid();
  v_note text := coalesce(trim(p_note), '');
begin
  if v_admin_id is null or not public.is_admin() then
    raise exception 'Admin access required' using errcode = '42501';
  end if;
  if p_decision not in ('published', 'rejected') then
    raise exception 'Decision must be published or rejected';
  end if;
  if p_decision = 'rejected' and v_note = '' then
    raise exception 'A decline reason is required';
  end if;

  update public.listings
     set status = p_decision,
         approved_at = case when p_decision = 'published' then now() else approved_at end,
         rejection_note = case when p_decision = 'rejected' then left(v_note, 500) else '' end,
         updated_at = now()
   where id = p_listing_id and status = 'pending';

  if not found then
    raise exception 'Listing not found or already reviewed';
  end if;

  insert into public.listing_reviews (listing_id, admin_id, decision, note)
  values (p_listing_id, v_admin_id, p_decision, left(v_note, 500));
end;
$$;

create or replace function public.resubmit_listing(p_listing_id uuid)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.listings
     set status = 'pending', rejection_note = '', updated_at = now()
   where id = p_listing_id
     and owner_id = auth.uid()
     and status = 'rejected';
  if not found then
    raise exception 'Only your declined listing can be resubmitted';
  end if;
end;
$$;

create or replace function public.set_my_listing_status(
  p_listing_id uuid,
  p_status text
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_current_status text;
  v_approved_at timestamptz;
begin
  select status, approved_at
    into v_current_status, v_approved_at
    from public.listings
   where id = p_listing_id and owner_id = auth.uid()
   for update;

  if not found then
    raise exception 'Listing not found';
  end if;

  if not (
    (v_current_status = 'published' and p_status in ('paused', 'rented'))
    or (v_current_status = 'paused' and p_status = 'published' and v_approved_at is not null)
  ) then
    raise exception 'This listing status change is not allowed';
  end if;

  update public.listings
     set status = p_status, updated_at = now()
   where id = p_listing_id;
end;
$$;

create or replace function public.get_or_create_conversation(p_listing_id uuid)
returns uuid
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_buyer_id uuid := auth.uid();
  v_conversation_id uuid;
begin
  if v_buyer_id is null then
    raise exception 'Sign in to message this host' using errcode = '42501';
  end if;

  insert into public.conversations (listing_id, listing_title, buyer_id, seller_id)
  select l.id, l.title, v_buyer_id, l.owner_id
    from public.listings l
   where l.id = p_listing_id
     and l.status = 'published'
     and l.owner_id <> v_buyer_id
  on conflict (listing_id, buyer_id)
  do update set listing_title = excluded.listing_title
  returning id into v_conversation_id;

  if v_conversation_id is null then
    raise exception 'Listing is unavailable or cannot be messaged';
  end if;
  return v_conversation_id;
end;
$$;

create or replace function public.get_owner_contact_phone(p_listing_id uuid)
returns text
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_phone text;
begin
  if auth.uid() is null then
    raise exception 'Sign in to request contact details' using errcode = '42501';
  end if;

  select p.phone_number into v_phone
    from public.listings l
    join public.profiles p on p.id = l.owner_id
   where l.id = p_listing_id
     and l.status = 'published'
     and l.owner_id <> auth.uid()
     and p.phone_visible = true
     and p.phone_number is not null;
  return v_phone;
end;
$$;

create or replace function public.touch_conversation_after_message()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  update public.conversations
     set last_message_at = new.created_at
   where id = new.conversation_id;
  return new;
end;
$$;

create or replace view public.listing_public
with (security_barrier = true)
as
select
  l.id,
  l.owner_id,
  l.title,
  l.description,
  l.district,
  l.town,
  l.block,
  l.locality,
  case when l.show_exact_address then l.road else '' end as road,
  case when l.show_exact_address then l.landmark else '' end as landmark,
  case when l.show_exact_address then l.pincode else '' end as pincode,
  l.property_type,
  l.furnishing,
  l.lister_type,
  l.broker_fee,
  l.host_name,
  l.monthly_rent,
  l.deposit,
  l.bedrooms,
  l.bathrooms,
  l.area_sqft,
  l.rent_negotiable,
  l.maintenance_included,
  l.show_exact_address,
  l.available_from,
  l.amenities,
  l.tenant_rules,
  l.photo_paths,
  l.status,
  l.created_at
from public.listings l
where l.status = 'published';

create trigger profiles_touch_updated_at
before update on public.profiles
for each row execute function public.touch_updated_at();
create trigger listings_touch_updated_at
before update on public.listings
for each row execute function public.touch_updated_at();
create trigger messages_touch_conversation
 after insert on public.messages
 for each row execute function public.touch_conversation_after_message();

-- Remove any legacy profile policies before installing the private-phone policy.
do $$
declare
  existing_policy record;
begin
  for existing_policy in
    select policyname
    from pg_policies
    where schemaname = 'public' and tablename = 'profiles'
  loop
    execute format('drop policy %I on public.profiles', existing_policy.policyname);
  end loop;
end;
$$;

alter table public.profiles enable row level security;
alter table public.user_roles enable row level security;
alter table public.listings enable row level security;
alter table public.listing_reports enable row level security;
alter table public.listing_reviews enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;

create policy profiles_read_own_or_admin
  on public.profiles for select to authenticated
  using (id = auth.uid() or public.is_admin());
create policy profiles_insert_own
  on public.profiles for insert to authenticated
  with check (id = auth.uid());
create policy profiles_update_own
  on public.profiles for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create policy user_roles_read_own_or_admin
  on public.user_roles for select to authenticated
  using (user_id = auth.uid() or public.is_admin());

-- The base table is private to its owner and admins. Public discovery uses the
-- narrow listing_public view, which masks road/PIN/landmark unless opted in.
create policy listings_read_owner_or_admin
  on public.listings for select to authenticated
  using (owner_id = auth.uid() or public.is_admin());
create policy listings_create_pending
  on public.listings for insert to authenticated
  with check (owner_id = auth.uid() and status = 'pending');
create policy listings_edit_unreviewed
  on public.listings for update to authenticated
  using (owner_id = auth.uid() and status in ('pending', 'rejected'))
  with check (owner_id = auth.uid() and status in ('pending', 'rejected'));
create policy listings_delete_unreviewed
  on public.listings for delete to authenticated
  using (owner_id = auth.uid() and status in ('pending', 'rejected'));

create policy reports_create_own
  on public.listing_reports for insert to authenticated
  with check (
    reporter_id = auth.uid()
    and public.is_published_listing(listing_id::text)
  );
create policy reports_read_admin
  on public.listing_reports for select to authenticated
  using (public.is_admin());

create policy reviews_read_admin
  on public.listing_reviews for select to authenticated
  using (public.is_admin());

create policy conversations_read_participant
  on public.conversations for select to authenticated
  using (buyer_id = auth.uid() or seller_id = auth.uid());

create policy messages_read_participant
  on public.messages for select to authenticated
  using (
    exists (
      select 1 from public.conversations c
      where c.id = conversation_id
        and (c.buyer_id = auth.uid() or c.seller_id = auth.uid())
    )
  );
create policy messages_send_as_participant
  on public.messages for insert to authenticated
  with check (
    sender_id = auth.uid()
    and exists (
      select 1 from public.conversations c
      where c.id = conversation_id
        and (c.buyer_id = auth.uid() or c.seller_id = auth.uid())
    )
  );

-- Listing photos live in a private bucket. Published image links are signed;
-- owners can upload/read only inside their own user/listing folder.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'rental-photos',
  'rental-photos',
  false,
  8388608,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update set
  public = false,
  file_size_limit = 8388608,
  allowed_mime_types = excluded.allowed_mime_types;

create policy rental_photos_read_owner_or_live
  on storage.objects for select to anon, authenticated
  using (
    bucket_id = 'rental-photos'
    and (
      (auth.uid() is not null and (storage.foldername(name))[1] = auth.uid()::text)
      or public.is_published_listing((storage.foldername(name))[2])
      or (
        public.is_admin()
        and exists (
          select 1 from public.listings l
          where l.id::text = (storage.foldername(name))[2]
        )
      )
    )
  );
create policy rental_photos_upload_pending_owner
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'rental-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
    and exists (
      select 1 from public.listings l
      where l.id::text = (storage.foldername(name))[2]
        and l.owner_id = auth.uid()
        and l.status in ('pending', 'rejected')
    )
  );
create policy rental_photos_delete_unreviewed_owner
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'rental-photos'
    and (storage.foldername(name))[1] = auth.uid()::text
    and exists (
      select 1 from public.listings l
      where l.id::text = (storage.foldername(name))[2]
        and l.owner_id = auth.uid()
        and l.status in ('pending', 'rejected')
    )
  );

-- Least-privilege grants. No anonymous access to the raw listings/profiles,
-- no client writes to role/review tables, and no direct conversation creation.
grant select, insert, update on public.profiles to authenticated;
grant select on public.user_roles to authenticated;
grant select, insert, update, delete on public.listings to authenticated;
grant select on public.listing_public to anon, authenticated;
grant select, insert on public.listing_reports to authenticated;
grant select on public.listing_reviews to authenticated;
grant select on public.conversations to authenticated;
grant select, insert on public.messages to authenticated;

revoke all on public.listings from anon;
revoke all on public.profiles from anon;
revoke all on public.user_roles from anon;
revoke all on public.listing_reports from anon;
revoke all on public.listing_reviews from anon;
revoke all on public.conversations from anon;
revoke all on public.messages from anon;
revoke delete on public.profiles from authenticated;
revoke update, delete on public.listing_reports from anon, authenticated;
revoke insert, update, delete on public.user_roles from anon, authenticated;
revoke insert, update, delete on public.listing_reviews from anon, authenticated;
revoke insert, update, delete on public.conversations from anon, authenticated;
revoke update, delete on public.messages from anon, authenticated;
revoke all on function public.touch_updated_at() from public, anon, authenticated;
revoke all on function public.touch_conversation_after_message() from public, anon, authenticated;
revoke all on function public.admin_review_listing(uuid, text, text) from public, anon;
revoke all on function public.resubmit_listing(uuid) from public, anon;
revoke all on function public.set_my_listing_status(uuid, text) from public, anon;
revoke all on function public.get_or_create_conversation(uuid) from public, anon;
revoke all on function public.get_owner_contact_phone(uuid) from public, anon;

grant execute on function public.is_admin() to anon, authenticated;
grant execute on function public.is_published_listing(text) to anon, authenticated;
grant execute on function public.admin_review_listing(uuid, text, text) to authenticated;
grant execute on function public.resubmit_listing(uuid) to authenticated;
grant execute on function public.set_my_listing_status(uuid, text) to authenticated;
grant execute on function public.get_or_create_conversation(uuid) to authenticated;
grant execute on function public.get_owner_contact_phone(uuid) to authenticated;

-- Make chat updates arrive live in the Flutter inbox/chat stream.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    begin
      alter publication supabase_realtime add table public.messages;
    exception when duplicate_object then
      null;
    end;
  end if;
end;
$$;

commit;

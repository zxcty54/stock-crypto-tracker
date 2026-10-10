-- Post-completion feedback only. Apply after 001, 002 and 003.
begin;
create table if not exists public.shop_order_reviews (
 id uuid primary key default gen_random_uuid(),
 order_id uuid not null unique references public.cash_orders(id) on delete cascade,
 buyer_id uuid not null references auth.users(id) on delete cascade,
 shop_id uuid not null references public.shops(id) on delete cascade,
 rating integer not null check(rating between 1 and 5),
 comment_text text not null default '' check(char_length(btrim(comment_text)) <= 500),
 moderation_status text not null default 'pending' check(moderation_status in ('pending','published','hidden')),
 moderation_note text not null default '' check(char_length(moderation_note)<=300),
 moderated_by uuid references auth.users(id) on delete set null,
 published_at timestamptz,
 is_sample boolean not null default false,
 created_at timestamptz not null default now()
);
create index if not exists shop_reviews_public_idx on public.shop_order_reviews(shop_id,moderation_status,created_at desc);
create index if not exists shop_reviews_buyer_idx on public.shop_order_reviews(buyer_id);
alter table public.shop_order_reviews enable row level security;
revoke all on public.shop_order_reviews from anon,authenticated;
grant select on public.shop_order_reviews to authenticated;
drop policy if exists review_private_read on public.shop_order_reviews;
create policy review_private_read on public.shop_order_reviews for select to authenticated using(
 buyer_id=(select auth.uid()) or public.is_market_admin() or
 exists(select 1 from public.shops s where s.id=shop_id and s.owner_id=(select auth.uid()))
);

-- Intentionally owner-executed, sanitized public projection: never expose order,
-- customer identity/contact/address/location or moderation notes. RLS-protected
-- private table is NOT granted to anon. Explicit publication/shop filters apply.
create or replace view public.public_shop_reviews with(security_barrier=true) as
 select r.id,r.shop_id,r.rating,r.comment_text,r.created_at,r.published_at,r.is_sample
 from public.shop_order_reviews r join public.shops s on s.id=r.shop_id
 where r.moderation_status='published' and s.review_status='approved' and s.is_published;
revoke all on public.public_shop_reviews from public,anon,authenticated;
grant select on public.public_shop_reviews to anon,authenticated;

create or replace function public.submit_completed_review(p_order_id uuid,p_rating integer,p_comment text)
returns uuid language plpgsql security definer set search_path=public,pg_catalog as $$
declare o public.cash_orders; review_id uuid;
begin
 if auth.uid() is null then raise exception 'Sign in as the order buyer' using errcode='42501'; end if;
 select * into o from public.cash_orders where id=p_order_id for share;
 if not found or o.buyer_id is distinct from auth.uid() then raise exception 'Only this order buyer can leave feedback' using errcode='42501'; end if;
 if o.status<>'completed' then raise exception 'Feedback is available only after the order is completed'; end if;
 if o.shop_id is null then raise exception 'The reviewed shop no longer exists'; end if;
 if p_rating is null or p_rating not between 1 and 5 or p_comment is null or char_length(btrim(p_comment))>500 then raise exception 'Use 1-5 stars and an optional comment of up to 500 characters'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_order_id::text,2));
 if exists(select 1 from public.shop_order_reviews where order_id=p_order_id) then raise exception 'You have already reviewed this order'; end if;
 insert into public.shop_order_reviews(order_id,buyer_id,shop_id,rating,comment_text,is_sample)
 values(o.id,auth.uid(),o.shop_id,p_rating,btrim(p_comment),o.is_sample) returning id into review_id;
 return review_id;
end;
$$;
revoke all on function public.submit_completed_review(uuid,integer,text) from public;
grant execute on function public.submit_completed_review(uuid,integer,text) to authenticated;

create or replace function public.moderate_order_review(p_review_id uuid,p_publish boolean,p_note text)
returns void language plpgsql security definer set search_path=public,pg_catalog as $$
begin
 if not public.is_market_admin() then raise exception 'Administrator access required' using errcode='42501'; end if;
 if p_publish is null or p_note is null or char_length(btrim(p_note)) not between 3 and 300 then raise exception 'Add a moderation reason of 3-300 characters'; end if;
 update public.shop_order_reviews set moderation_status=case when p_publish then 'published' else 'hidden' end,
 moderation_note=btrim(p_note),moderated_by=auth.uid(),published_at=case when p_publish then now() else null end where id=p_review_id;
 if not found then raise exception 'Feedback not found'; end if;
 insert into public.market_audit(actor_id,action,target,details) values(auth.uid(),case when p_publish then 'order_review_published' else 'order_review_hidden' end,p_review_id::text,jsonb_build_object('reason',btrim(p_note)));
end;
$$;
revoke all on function public.moderate_order_review(uuid,boolean,text) from public;
grant execute on function public.moderate_order_review(uuid,boolean,text) to authenticated;

-- Include tagged feedback in sample cleanup, including standalone sample rows.
create or replace function public.purge_sample_catalog() returns void language plpgsql security definer set search_path=public,pg_catalog as $$
begin
 if not public.is_market_admin() then raise exception 'Admin only' using errcode='42501'; end if;
 delete from public.shop_order_reviews where is_sample;
 delete from public.cash_orders where is_sample;
 delete from public.personal_expenses where is_sample;
 delete from public.products where is_sample;
 delete from public.shops where is_sample;
 insert into public.market_audit(actor_id,action,target) values(auth.uid(),'sample_catalog_removed','sample_records_only');
end;
$$;
revoke all on function public.purge_sample_catalog() from public;
grant execute on function public.purge_sample_catalog() to authenticated;
commit;

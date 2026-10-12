-- Content reporting and in-app UGC flagging for Google Play compliance.
begin;
create table if not exists public.content_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid references auth.users(id) on delete set null,
  target_type text not null check(target_type in ('shop','product','review')),
  target_id text not null check(char_length(btrim(target_id)) between 1 and 100),
  target_title text not null default '' check(char_length(target_title) <= 200),
  reason text not null check(char_length(btrim(reason)) between 3 and 100),
  details text not null default '' check(char_length(details) <= 500),
  status text not null default 'pending' check(status in ('pending','investigated','dismissed')),
  status_note text not null default '' check(char_length(status_note) <= 300),
  moderated_by uuid references auth.users(id) on delete set null,
  is_sample boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists content_reports_status_idx on public.content_reports(status, created_at desc);
alter table public.content_reports enable row level security;
revoke all on public.content_reports from anon, authenticated;
grant select on public.content_reports to authenticated;
drop policy if exists content_reports_admin_read on public.content_reports;
create policy content_reports_admin_read on public.content_reports for select to authenticated using(
  public.is_market_admin() or reporter_id = (select auth.uid())
);

create or replace function public.submit_content_report(
  p_target_type text,
  p_target_id text,
  p_target_title text,
  p_reason text,
  p_details text
) returns uuid language plpgsql security definer set search_path=public,pg_catalog as $$
declare
  report_id uuid;
begin
  if p_target_type not in ('shop','product','review') then
    raise exception 'Invalid report target type';
  end if;
  if char_length(btrim(p_target_id)) not between 1 and 100 or char_length(btrim(p_reason)) not between 3 and 100 or char_length(p_details) > 500 then
    raise exception 'Invalid report reason or details';
  end if;
  insert into public.content_reports(reporter_id, target_type, target_id, target_title, reason, details)
  values(auth.uid(), p_target_type, btrim(p_target_id), btrim(p_target_title), btrim(p_reason), btrim(p_details))
  returning id into report_id;
  insert into public.market_audit(actor_id, action, target, details)
  values(auth.uid(), 'user_report_submitted', p_target_type || ':' || btrim(p_target_id),
    jsonb_build_object('reason', btrim(p_reason), 'report_id', report_id));
  return report_id;
end;
$$;
revoke all on function public.submit_content_report(text,text,text,text,text) from public;
grant execute on function public.submit_content_report(text,text,text,text,text) to anon, authenticated;

create or replace function public.resolve_content_report(
  p_report_id uuid,
  p_status text,
  p_note text
) returns void language plpgsql security definer set search_path=public,pg_catalog as $$
begin
  if not public.is_market_admin() then raise exception 'Administrator access required' using errcode='42501'; end if;
  if p_status not in ('investigated','dismissed') or char_length(btrim(p_note)) not between 3 and 300 then
    raise exception 'Choose investigated or dismissed with a note of 3-300 characters';
  end if;
  update public.content_reports set status=p_status, status_note=btrim(p_note), moderated_by=auth.uid(), updated_at=now() where id=p_report_id;
  if not found then raise exception 'Report not found'; end if;
  insert into public.market_audit(actor_id, action, target, details)
  values(auth.uid(), 'report_' || p_status, p_report_id::text, jsonb_build_object('note', btrim(p_note)));
end;
$$;
revoke all on function public.resolve_content_report(uuid,text,text) from public;
grant execute on function public.resolve_content_report(uuid,text,text) to authenticated;

-- Enhanced sample purge cleans sample reports as well
create or replace function public.purge_sample_catalog() returns void language plpgsql security definer set search_path=public,pg_catalog as $$
begin
 if not public.is_market_admin() then raise exception 'Admin only' using errcode='42501'; end if;
 delete from public.content_reports where is_sample;
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

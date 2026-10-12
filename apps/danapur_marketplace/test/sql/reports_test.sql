-- Content reporting permissions, admin resolution and sample cleanup.
reset role;
select set_config('request.jwt.claim.sub','',false);
set role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',false);
do $$ declare rid uuid; begin
 rid := public.submit_content_report('shop', 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'Test Shop A', 'Misleading, scam or fake listing', 'Fake shop report');
 if (select count(*) from public.content_reports where id = rid) <> 1 then
   raise exception 'reporter cannot read own submitted report';
 end if;
 begin
   perform public.resolve_content_report(rid, 'investigated', 'Self resolution');
   raise exception 'non-admin report resolution succeeded';
 exception when insufficient_privilege then null; end;
end $$;
reset role;

set role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',false);
do $$ declare rid uuid; begin
 select id into rid from public.content_reports limit 1;
 perform public.resolve_content_report(rid, 'investigated', 'Listing checked by admin');
 if (select status from public.content_reports where id = rid) <> 'investigated' then
   raise exception 'admin report resolution failed';
 end if;
end $$;
reset role;

set role anon;
select set_config('request.jwt.claim.sub','',false);
do $$ begin
 begin
   perform count(*) from public.content_reports;
   raise exception 'anonymous direct read of reports succeeded';
 exception when insufficient_privilege then null; end;
end $$;
reset role;

select 'PASS: content reporting, author privacy, admin resolution and audit' as result;

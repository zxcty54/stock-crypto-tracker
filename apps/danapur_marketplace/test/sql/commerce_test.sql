-- Disposable CI test only: never install customer/sample fixture data in production.
reset role;
select set_config('request.jwt.claim.sub','',false);
update public.shops set offers_delivery=true,latitude=25.636,longitude=85.041,delivery_base_paise=2000,is_open=true where id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
update public.products set discount_paise=1000,delivery_allowed=true,delivery_extra_paise=500 where id='aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa';
set role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',false);
select public.review_cash_shop('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','approved','Photo reviewed in admin panel',true);
reset role;
set role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',false);
do $$ declare oid uuid; again uuid; begin
 oid:=public.place_cash_order('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','[{"product_id":"aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa","quantity":2,"price_paise":1}]','delivery','Buyer test','8888888888','Test address, nearby',25.6363,85.041,10,now(),'cccccccc-0001-4001-8001-cccccccccccc');
 if (select total_paise from public.cash_orders where id=oid)<>21000 then raise exception 'server pricing/discount/delivery failed'; end if;
 again:=public.place_cash_order('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','[]','pickup','Buyer test','8888888888','Test pickup',null,null,null,null,'cccccccc-0001-4001-8001-cccccccccccc');
 if again<>oid then raise exception 'idempotency failed'; end if;
 begin perform public.place_cash_order('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','[{"product_id":"aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa","quantity":1}]','delivery','Buyer test','8888888888','Far away address',25.646,85.041,10,now(),'cccccccc-0002-4002-8002-cccccccccccc'); raise exception 'outside-radius delivery accepted'; exception when raise_exception then if SQLERRM='outside-radius delivery accepted' then raise; end if; end;
 begin perform public.place_cash_order('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','[{"product_id":"aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa","quantity":1}]','delivery','Buyer test','8888888888','Test address',25.636,85.041,80,now(),'cccccccc-0003-4003-8003-cccccccccccc'); raise exception 'inaccurate GPS accepted'; exception when raise_exception then if SQLERRM='inaccurate GPS accepted' then raise; end if; end;
 begin perform public.place_cash_order('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','[{"product_id":"bbbbbbbb-2222-4222-8222-bbbbbbbbbbbb","quantity":1}]','pickup','Buyer test','8888888888','Test pickup',null,null,null,null,'cccccccc-0004-4004-8004-cccccccccccc'); raise exception 'cross-shop cart accepted'; exception when raise_exception then if SQLERRM='cross-shop cart accepted' then raise; end if; end;
 perform public.change_cash_order(oid,'completed','Buyer received items; cash self-reported');
 perform public.change_cash_order(oid,'completed','Duplicate completion retry');
 if (select count(*) from public.personal_expenses where order_id=oid)<>1 then raise exception 'duplicate completion expense'; end if;
 if (select amount_paise from public.personal_expenses where order_id=oid)<>21000 then raise exception 'expense total wrong'; end if;
 begin perform public.change_cash_order(oid,'cancelled','Try to reopen completed order'); raise exception 'closed order changed'; exception when raise_exception then if SQLERRM='closed order changed' then raise; end if; end;
 begin insert into public.cash_orders(request_id,shop_name) values(gen_random_uuid(),'fake'); raise exception 'direct order insert accepted'; exception when insufficient_privilege then null; end;
 perform public.save_personal_expense(null,5000,'Travel','Manual test record',(now() at time zone 'Asia/Kolkata')::date);
end $$;
reset role;
-- Snapshot prices must not mutate with catalogue edits. Pickup ignores radius.
select set_config('request.jwt.claim.sub','',false);
update public.products set price_paise=15000,delivery_allowed=false where id='aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa';
set role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',false);
do $$ declare oid uuid; begin
 if (select total_paise from public.cash_orders where request_id='cccccccc-0001-4001-8001-cccccccccccc')<>21000 then raise exception 'order price snapshot changed'; end if;
 begin perform public.place_cash_order('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','[{"product_id":"aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa","quantity":1}]','delivery','Buyer test','8888888888','Test address',25.636,85.041,10,now(),'cccccccc-0005-4005-8005-cccccccccccc'); raise exception 'pickup-only product delivered'; exception when raise_exception then if SQLERRM='pickup-only product delivered' then raise; end if; end;
 oid:=public.place_cash_order('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','[{"product_id":"aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa","quantity":1}]','pickup','Buyer test','8888888888','Shop pickup',null,null,null,null,'cccccccc-0006-4006-8006-cccccccccccc');
 if (select delivery_paise from public.cash_orders where id=oid)<>0 then raise exception 'pickup charged delivery'; end if;
 perform public.change_cash_order(oid,'cancelled','Buyer cancelled before pickup');
 if exists(select 1 from public.personal_expenses where order_id=oid) then raise exception 'cancelled order counted as expense'; end if;
end $$;
reset role;
set role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false);
do $$ begin
 if (select count(*) from public.cash_orders)<>2 then raise exception 'seller cannot see assigned orders'; end if;
 if (select count(*) from public.personal_expenses)<>0 then raise exception 'buyer expenses leaked to seller'; end if;
 begin perform public.configure_cash_billing(true); raise exception 'seller enabled billing'; exception when insufficient_privilege then null; end;
 begin update public.shops set paid_through=now()+interval '1 year' where owner_id=auth.uid(); raise exception 'seller granted membership'; exception when insufficient_privilege then null; end;
end $$;
reset role;
set role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',false);
do $$ begin
 if (select count(*) from public.cash_orders)<>0 then raise exception 'order addresses leaked to nonparticipant admin'; end if;
 if (select billing_enabled from public.market_settings) then raise exception 'billing should default off'; end if;
 perform public.configure_cash_billing(true);
 if not public.shop_membership_active('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa') then raise exception 'initial membership grace missing'; end if;
end $$;
reset role;
select set_config('request.jwt.claim.sub','',false);
update public.market_settings set billing_started_at=now()-interval '31 days';
set role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',false);
do $$ begin
 begin perform public.place_cash_order('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','[{"product_id":"aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa","quantity":1}]','pickup','Buyer test','8888888888','Shop pickup',null,null,null,null,'cccccccc-0007-4007-8007-cccccccccccc'); raise exception 'expired membership accepted'; exception when raise_exception then if SQLERRM='expired membership accepted' then raise; end if; end;
end $$;
reset role;
set role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',false);
select public.extend_shop_membership('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',now()+interval '30 days','Offline access extension, not digital payment');
do $$ begin
 if not public.shop_membership_active('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa') then raise exception 'admin membership extension failed'; end if;
 perform public.purge_sample_catalog();
end $$;
reset role;
select set_config('request.jwt.claim.sub','',false);
do $$ begin
 if (select count(*) from public.cash_orders)<>2 then raise exception 'sample purge removed real orders'; end if;
 if public.distance_metres(25.636,85.041,25.636,85.041)<>0 then raise exception 'distance identity failed'; end if;
end $$;
select 'PASS: cash checkout, 500m gate, product delivery, immutable prices, participant privacy, completion/cancel, expenses, billing switch and safe sample purge' as result;

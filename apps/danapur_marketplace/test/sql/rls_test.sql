-- Disposable CI fixture data only; NEVER deploy to a real project.
insert into auth.users values('11111111-1111-4111-8111-111111111111'),('22222222-2222-4222-8222-222222222222'),('33333333-3333-4333-8333-333333333333');
insert into public.market_admins(user_id) values('33333333-3333-4333-8333-333333333333');
insert into storage.objects(bucket_id,name) values
 ('shop-verification','11111111-1111-4111-8111-111111111111/front.jpeg'),
 ('shop-verification','22222222-2222-4222-8222-222222222222/front.jpeg');
insert into public.shops(id,owner_id,name,category,area,address,phone,is_published,business_type,verification_photo_path) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','11111111-1111-4111-8111-111111111111','Test Shop A','Hardware','Danapur Bazaar','Test address A','9999999999',true,'Wholesaler','11111111-1111-4111-8111-111111111111/front.jpeg'),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','22222222-2222-4222-8222-222222222222','Test Shop B','Furniture','Danapur Bazaar','Test address B','8888888888',false,'Retailer','22222222-2222-4222-8222-222222222222/front.jpeg');
insert into public.products(id,shop_id,name,category,price_paise) values
 ('aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Test Tool A','Hardware',10000),
 ('bbbbbbbb-2222-4222-8222-bbbbbbbbbbbb','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Test Chair B','Furniture',20000);

set role anon;
select set_config('request.jwt.claim.sub','',false);
do $$ begin
 if (select count(*) from public.shops) <> 0 then raise exception 'pending shops leaked publicly'; end if;
 if (select count(*) from public.products) <> 0 then raise exception 'pending products leaked publicly'; end if;
 if (select count(*) from public.mandi_items) <> 117 then raise exception 'expected full unpriced commodity catalogue'; end if;
 if (select count(*) from public.current_mandi_rates) <> 0 then raise exception 'fake prices were seeded'; end if;
 if (select count(*) from storage.objects where bucket_id='shop-verification') <> 0 then raise exception 'private storefront proof leaked'; end if;
 begin update public.products set price_paise=1; raise exception 'anonymous write succeeded'; exception when insufficient_privilege then null; end;
end $$;
reset role;

set role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',false);
do $$ declare changed integer; begin
 if public.is_market_admin() then raise exception 'seller acquired admin'; end if;
 if (select count(*) from public.shops) <> 1 then raise exception 'owner cannot see own pending shop'; end if;
 if (select count(*) from public.products) <> 1 then raise exception 'owner cannot see own pending products'; end if;
 if (select count(*) from storage.objects where bucket_id='shop-verification') <> 1 then raise exception 'owner proof isolation failed'; end if;
 if (select count(*) from public.market_audit) <> 0 then raise exception 'audit leaked to seller'; end if;
 begin insert into public.market_admins(user_id) values(auth.uid()); raise exception 'self-admin assignment succeeded'; exception when insufficient_privilege then null; end;
 begin perform public.review_market_shop('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','approved','fake approval',true); raise exception 'seller RPC approval succeeded'; exception when insufficient_privilege then null; end;
 begin update public.shops set review_status='approved',whatsapp_checked=true,reviewed_at=now() where owner_id=auth.uid(); raise exception 'seller direct approval succeeded'; exception when insufficient_privilege then null; end;
 begin perform public.set_mandi_rate('potato','wholesale','kg',100,100,current_date,'fake'); raise exception 'seller price RPC succeeded'; exception when insufficient_privilege then null; end;
 begin update public.mandi_rates set min_paise=1; raise exception 'seller direct price write succeeded'; exception when insufficient_privilege then null; end;
 update public.products set price_paise=1 where shop_id='aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'; get diagnostics changed=row_count;
 if changed <> 0 then raise exception 'cross-owner price write succeeded'; end if;
 begin update public.products set mrp_paise=1 where shop_id='bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'; raise exception 'invalid MRP accepted'; exception when check_violation then null; end;
 begin update public.shops set business_type='Invalid' where owner_id=auth.uid(); raise exception 'invalid business type accepted'; exception when check_violation then null; end;
 begin update public.shops set owner_id='11111111-1111-4111-8111-111111111111' where owner_id=auth.uid(); raise exception 'ownership changed'; exception when raise_exception or insufficient_privilege or unique_violation then null; end;
 begin insert into storage.objects(bucket_id,name) values('shop-verification','11111111-1111-4111-8111-111111111111/attack.jpeg'); raise exception 'cross-owner proof upload succeeded'; exception when insufficient_privilege then null; end;
 delete from storage.objects where bucket_id='shop-verification' and name='22222222-2222-4222-8222-222222222222/front.jpeg'; get diagnostics changed=row_count;
 if changed <> 0 then raise exception 'referenced verification photo was deleted'; end if;
end $$;
reset role;

set role authenticated;
select set_config('request.jwt.claim.sub','33333333-3333-4333-8333-333333333333',false);
do $$ begin
 if not public.is_market_admin() then raise exception 'trusted admin not recognised'; end if;
 if (select count(*) from public.shops) <> 2 then raise exception 'admin cannot review queue'; end if;
 if (select count(*) from storage.objects where bucket_id='shop-verification') <> 2 then raise exception 'admin cannot view private proof'; end if;
 begin perform public.review_market_shop('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','approved','Photo reviewed',false); raise exception 'approval without WhatsApp proof succeeded'; exception when raise_exception then if SQLERRM='approval without WhatsApp proof succeeded' then raise; end if; end;
 perform public.review_market_shop('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','approved','Photo and sender reviewed',true);
 perform public.set_mandi_rate('potato','wholesale','kg',1234,1500,(now() at time zone 'Asia/Kolkata')::date,'Actual test fixture rate');
 perform public.set_mandi_rate('potato','wholesale','kg',900,1000,(now() at time zone 'Asia/Kolkata')::date-1,'Historical test fixture rate');
 perform public.set_mandi_rate('potato','retail','kg',1800,1800,(now() at time zone 'Asia/Kolkata')::date,'Separate retail fixture rate');
 perform public.set_market_settings('9999999999','support@example.test','https://example.test/privacy','https://example.test/terms','Danapur Mandi');
 if (select count(*) from public.market_audit) < 5 then raise exception 'admin actions not audited'; end if;
 begin perform public.set_mandi_rate('potato','wholesale','kg',100,100,(now() at time zone 'Asia/Kolkata')::date+1,'future'); raise exception 'future date accepted'; exception when raise_exception then if SQLERRM='future date accepted' then raise; end if; end;
 begin perform public.set_mandi_rate('potato','wholesale','kg',200,100,current_date,'invalid range'); raise exception 'invalid range accepted'; exception when check_violation then null; end;
 if public.can_delete_market_account() then raise exception 'last-admin account deletion permitted'; end if;
end $$;
reset role;

set role anon;
select set_config('request.jwt.claim.sub','',false);
do $$ begin
 if (select count(*) from public.shops) <> 1 or (select count(*) from public.products) <> 1 then raise exception 'approved public catalogue not visible'; end if;
 if (select count(*) from public.current_mandi_rates) <> 2 then raise exception 'latest rates/types incorrect'; end if;
 if (select min_paise from public.current_mandi_rates where item_id='potato' and price_type='wholesale') <> 1234 then raise exception 'history replaced newest rate'; end if;
 if (select count(*) from storage.objects where bucket_id='shop-verification') <> 0 then raise exception 'approval made proof public'; end if;
end $$;
reset role;

set role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false);
update public.shops set address='Changed identity address' where owner_id=auth.uid();
do $$ begin
 if (select review_status from public.shops where owner_id=auth.uid()) <> 'pending' then raise exception 'identity edit did not reset approval'; end if;
 if (select whatsapp_checked from public.shops where owner_id=auth.uid()) then raise exception 'old WhatsApp verification survived identity edit'; end if;
end $$;
reset role;
set role anon;
select set_config('request.jwt.claim.sub','',false);
do $$ begin
 if (select count(*) from public.shops) <> 0 or (select count(*) from public.products) <> 0 then raise exception 're-review did not hide listings'; end if;
end $$;
reset role;
select 'PASS: verified visibility, owner/admin isolation, private proof, immutable ownership, mandi history/units/types, no self-approval, audit and last-admin protection' as result;

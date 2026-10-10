insert into auth.users values ('11111111-1111-4111-8111-111111111111'), ('22222222-2222-4222-8222-222222222222');
insert into public.shops(id,owner_id,name,category,area,address,phone,is_published) values
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','11111111-1111-4111-8111-111111111111','Test Shop A','Grocery','Danapur Bazaar','Test address A','9999999999',true),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','22222222-2222-4222-8222-222222222222','Test Shop B','Grocery','Danapur Bazaar','Test address B','8888888888',false);
insert into public.products(id,shop_id,name,category,price_paise) values
 ('aaaaaaaa-1111-4111-8111-aaaaaaaaaaaa','aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Test Rice A','Grocery',10000),
 ('bbbbbbbb-2222-4222-8222-bbbbbbbbbbbb','bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','Test Rice B','Grocery',20000);

set role anon;
select set_config('request.jwt.claim.sub','',false);
do $$ begin
  if (select count(*) from public.shops) <> 1 then raise exception 'anon must see only published shops'; end if;
  if (select count(*) from public.products) <> 1 then raise exception 'anon must not see unpublished products'; end if;
  begin
    update public.products set price_paise = 1;
    raise exception 'anon unexpectedly updated products';
  exception when insufficient_privilege then null; end;
end $$;
reset role;

set role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',false);
do $$ declare changed integer; begin
  if (select count(*) from public.shops) <> 2 then raise exception 'owner must see own private shop and public shop'; end if;
  if (select count(*) from public.products) <> 2 then raise exception 'owner must see own private products'; end if;
  update public.products set price_paise = 1 where shop_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  get diagnostics changed = row_count;
  if changed <> 0 then raise exception 'cross-owner product update succeeded'; end if;
  delete from public.shops where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  get diagnostics changed = row_count;
  if changed <> 0 then raise exception 'cross-owner shop delete succeeded'; end if;
  begin
    insert into public.products(shop_id,name,category,price_paise) values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','Injected product','Grocery',100);
    raise exception 'cross-owner insert succeeded';
  exception when insufficient_privilege then null; end;
  begin
    insert into public.shops(owner_id,name,category,area,address,phone) values ('11111111-1111-4111-8111-111111111111','Impersonated shop','Grocery','Danapur Bazaar','Fake address','9999999999');
    raise exception 'owner impersonation succeeded';
  exception when insufficient_privilege then null; end;
  begin
    update public.products set price_paise = -1 where shop_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
    raise exception 'negative price accepted';
  exception when check_violation then null; end;
  begin
    update public.products set mrp_paise = 1 where shop_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
    raise exception 'MRP below selling price accepted';
  exception when check_violation then null; end;
  begin
    insert into storage.objects(bucket_id,name) values ('catalog-media','11111111-1111-4111-8111-111111111111/injected.png');
    raise exception 'cross-owner photo upload accepted';
  exception when insufficient_privilege then null; end;
  insert into storage.objects(bucket_id,name) values ('catalog-media','22222222-2222-4222-8222-222222222222/own.png');
  update public.products set price_paise = 12345 where shop_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
  if (select price_paise from public.products where shop_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb') <> 12345 then raise exception 'own product update failed'; end if;
end $$;
reset role;

set role authenticated;
select set_config('request.jwt.claim.sub','11111111-1111-4111-8111-111111111111',false);
do $$ declare changed integer; begin
  if (select count(*) from public.shops) <> 1 then raise exception 'owner A saw owner B private shop'; end if;
  delete from storage.objects where name = '22222222-2222-4222-8222-222222222222/own.png';
  get diagnostics changed = row_count;
  if changed <> 0 then raise exception 'cross-owner photo delete accepted'; end if;
  update public.shops set is_published = false where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
  if (select count(*) from public.products) <> 1 then raise exception 'owner cannot read own unpublished products'; end if;
end $$;
reset role;

set role anon;
select set_config('request.jwt.claim.sub','',false);
do $$ begin
  if (select count(*) from public.shops) <> 0 then raise exception 'unpublished shop leaked to anon'; end if;
  if (select count(*) from public.products) <> 0 then raise exception 'unpublished products leaked to anon'; end if;
end $$;
reset role;

set role authenticated;
select set_config('request.jwt.claim.sub','22222222-2222-4222-8222-222222222222',false);
delete from public.shops where id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
delete from storage.objects where name = '22222222-2222-4222-8222-222222222222/own.png';
reset role;
do $$ begin
  if exists (select 1 from public.products where shop_id = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb') then raise exception 'product cascade failed'; end if;
  if exists (select 1 from storage.objects) then raise exception 'own photo delete failed'; end if;
end $$;
select 'RLS tests passed: public reads, private visibility, owner-only CRUD, price checks, storage ownership and cascade.' as result;

-- OPTIONAL TEST DATA, never automatic. Apply after all three migrations.
-- Create/confirm a dedicated TEST owner through normal Supabase Auth first.
-- Replace the UUID below. No Auth users, passwords or real storefront proof are fabricated.
-- Use a test project/account, not your actual business shop owner.
-- All rows are explicitly tagged sample and contacts disabled by the UI.
begin;
do $$ declare test_owner uuid := 'REPLACE_WITH_CONFIRMED_TEST_OWNER_UUID'::uuid;
begin
 if not exists(select 1 from auth.users where id=test_owner) then raise exception 'Create and confirm the dedicated test owner first'; end if;
 if exists(select 1 from public.shops where owner_id=test_owner and not is_sample) then raise exception 'Do not replace a real owner shop with sample data'; end if;
 insert into public.shops(id,owner_id,name,category,area,address,phone,review_status,is_sample,is_open,offers_delivery,latitude,longitude,delivery_base_paise,verification_photo_path,reviewed_at,whatsapp_checked,review_note)
 values('f0000000-0000-4000-8000-000000000001',test_owner,'Sample Daily Needs — TEST ONLY','Grocery','Danapur Bazaar','Fictional sample storefront; not a delivery address','9000000000','approved',true,true,true,25.636,85.041,2000,test_owner::text||'/sample-no-real-photo.jpeg',now(),true,'Fictional sample; not real shop/photo verification')
 on conflict(id) do nothing;
 insert into public.products(id,shop_id,name,category,price_paise,discount_paise,unit,delivery_allowed,delivery_extra_paise,is_sample,illustration)
 values('f0000000-0000-4000-8000-000000000002','f0000000-0000-4000-8000-000000000001','Sample rice — 1 kg','Grocery',8000,500,'1 kg pack',true,0,true,'rice'),
 ('f0000000-0000-4000-8000-000000000003','f0000000-0000-4000-8000-000000000001','Sample oil — 1 litre','Grocery',15000,1000,'1 litre',true,500,true,'oil'),
 ('f0000000-0000-4000-8000-000000000004','f0000000-0000-4000-8000-000000000001','Sample bulk rice — pickup only','Grocery',320000,0,'50 kg sack',false,0,true,'rice') on conflict(id) do nothing;
end $$;
commit;
-- Use a different signed-in buyer to test cash orders. There is no real fulfilment.
-- Admin -> Membership & samples -> Remove sample data calls purge_sample_catalog().
-- Test Auth accounts are not deleted by sample cleanup; remove them separately if desired.

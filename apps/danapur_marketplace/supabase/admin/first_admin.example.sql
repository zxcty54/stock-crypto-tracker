-- Run ONLY in the dedicated project's Supabase SQL Editor, after you create
-- and confirm your own email/password account in this app.
-- Find its UUID in Supabase Authentication -> Users.
-- Replace the placeholder below; this is NOT an app self-admin signup.
-- Do not put service-role credentials in Flutter/Git/chat.
insert into public.market_admins(user_id)
values ('REPLACE_WITH_YOUR_CONFIRMED_AUTH_USER_UUID'::uuid)
on conflict(user_id) do nothing;

-- After signing out/in or refreshing, Admin panel is available to that account.
-- To add another trusted administrator, repeat with their confirmed user UUID.

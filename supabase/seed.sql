-- Disposable development data only. No fixed passwords; log in via local Inbucket.
insert into auth.users(id,instance_id,aud,role,email,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at)
values
 ('10000000-0000-4000-8000-000000000001','00000000-0000-0000-0000-000000000000','authenticated','authenticated','emma@example.test',now(),'{"provider":"email","providers":["email"]}','{}',now(),now()),
 ('10000000-0000-4000-8000-000000000002','00000000-0000-0000-0000-000000000000','authenticated','authenticated','alice@example.test',now(),'{"provider":"email","providers":["email"]}','{}',now(),now());
update public.users set display_name='Emma' where id='10000000-0000-4000-8000-000000000001';
update public.users set display_name='Alice' where id='10000000-0000-4000-8000-000000000002';

do $$ declare g uuid; i uuid; begin
 perform set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000001',true);
 g:=public.create_group('Paris Friends');
 perform public.add_friend(g,'Thomas'); perform public.add_friend(g,'Lucie');
 i:=public.issue_group_invite(g,repeat('e',64));
 update public.invites set expires_at=now()-interval '1 day' where id=i;
 perform set_config('request.jwt.claim.sub','10000000-0000-4000-8000-000000000002',true);
 perform public.create_group('Ski Crew');
end $$;
-- Alice is outside Paris Friends for isolation tests. Later-phase entities are deferred.

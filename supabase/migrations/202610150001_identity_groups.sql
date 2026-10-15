create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create table public.users (
 id uuid primary key references auth.users(id) on delete restrict,
 display_name text not null default 'Friend' check (length(trim(display_name)) between 1 and 80),
 avatar_key text,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create table public.groups (
 id uuid primary key default gen_random_uuid(), name text not null check(length(trim(name)) between 1 and 80), cover_key text,
 created_by_user_id uuid not null references public.users(id),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), deleted_at timestamptz
);
create table public.persons (
 id uuid primary key default gen_random_uuid(), group_id uuid not null references public.groups(id),
 display_name text not null check(length(trim(display_name)) between 1 and 80),
 claimed_by_user_id uuid references public.users(id), created_by_user_id uuid not null references public.users(id),
 status text not null check(status in ('unclaimed','claimed','removed','disputed')),
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(id,group_id), check(status not in ('unclaimed','claimed') or (status='claimed')=(claimed_by_user_id is not null))
);
create index persons_user on public.persons(claimed_by_user_id);
create table public.group_members (
 group_id uuid not null references public.groups(id), person_id uuid not null,
 role text not null check(role in ('owner','member')), joined_at timestamptz not null default now(),
 primary key(group_id,person_id), foreign key(person_id,group_id) references public.persons(id,group_id)
);
create unique index one_group_owner on public.group_members(group_id) where role='owner';
create index group_members_person on public.group_members(person_id,group_id);
create table public.person_contacts (
 id uuid primary key default gen_random_uuid(), person_id uuid not null references public.persons(id),
 contact_type text not null check(contact_type in ('email','phone')), encrypted_value text not null check(encrypted_value like 'v1:%'),
 contact_hash text not null check(contact_hash ~ '^[a-f0-9]{64}$'), verified_at timestamptz,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(person_id,contact_type)
);
create table public.invites (
 id uuid primary key default gen_random_uuid(), purpose text not null default 'group' check(purpose='group'),
 target_id uuid not null references public.groups(id), token_hash text not null unique check(token_hash ~ '^[a-f0-9]{64}$'),
 created_by_user_id uuid not null references public.users(id), expires_at timestamptz not null default now()+interval '7 days',
 max_uses integer not null default 1 check(max_uses between 1 and 100), use_count integer not null default 0 check(use_count>=0 and use_count<=max_uses),
 revoked_at timestamptz, used_at timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create index invites_target on public.invites(target_id,created_at desc);
create table public.invite_redemptions (
 invite_id uuid not null references public.invites(id), user_id uuid not null references public.users(id),
 person_id uuid not null references public.persons(id), created_at timestamptz not null default now(), primary key(invite_id,user_id)
);
create table public.audit_logs (
 id uuid primary key default gen_random_uuid(), actor_user_id uuid references public.users(id),
 action text not null, entity_type text not null, entity_id uuid not null,
 before_json jsonb, after_json jsonb, created_at timestamptz not null default now()
);
create table public.rate_limits (
 user_id uuid not null references public.users(id), action text not null, bucket timestamptz not null,
 attempts integer not null check(attempts>0), primary key(user_id,action,bucket)
);

create function private.touch() returns trigger language plpgsql set search_path='' as $$ begin new.updated_at=now(); return new; end $$;
create trigger touch_users before update on public.users for each row execute function private.touch();
create trigger touch_groups before update on public.groups for each row execute function private.touch();
create trigger touch_persons before update on public.persons for each row execute function private.touch();
create trigger touch_contacts before update on public.person_contacts for each row execute function private.touch();
create trigger touch_invites before update on public.invites for each row execute function private.touch();
create function private.on_auth_user() returns trigger language plpgsql security definer set search_path='' as $$
begin insert into public.users(id,display_name) values(new.id,'Friend'); return new; end $$;
create trigger on_auth_user after insert on auth.users for each row execute function private.on_auth_user();

create function private.member_of(p_group uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.group_members m join public.persons p on p.id=m.person_id join public.groups g on g.id=m.group_id where m.group_id=p_group and p.claimed_by_user_id=auth.uid() and p.status='claimed' and g.deleted_at is null)
$$;
create function private.owner_of(p_group uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.group_members m join public.persons p on p.id=m.person_id join public.groups g on g.id=m.group_id where m.group_id=p_group and m.role='owner' and p.claimed_by_user_id=auth.uid() and p.status='claimed' and g.deleted_at is null)
$$;
create function private.require_user() returns uuid language plpgsql stable security definer set search_path='' as $$
begin if auth.uid() is null then raise exception 'unauthenticated' using errcode='28000'; end if; return auth.uid(); end $$;
create function private.lock_owner(p_group uuid) returns void language plpgsql security definer set search_path='' as $$
begin perform private.require_user(); perform 1 from public.groups where id=p_group for update; if not private.owner_of(p_group) then raise exception 'unavailable' using errcode='42501'; end if; end $$;
create function private.log(p_action text,p_kind text,p_id uuid) returns void language sql security definer set search_path='' as $$
 insert into public.audit_logs(actor_user_id,action,entity_type,entity_id) values(auth.uid(),p_action,p_kind,p_id)
$$;
create function private.throttle(p_action text,p_limit integer) returns boolean language plpgsql security definer set search_path='' as $$
declare n integer;
begin
 insert into public.rate_limits(user_id,action,bucket,attempts) values(private.require_user(),p_action,date_trunc('hour',now()),1)
 on conflict(user_id,action,bucket) do update set attempts=public.rate_limits.attempts+1 returning attempts into n;
 return n<=p_limit;
end $$;

-- Deferred invariant permits atomic ownership transfer but rejects orphan groups.
create function private.owner_invariant() returns trigger language plpgsql security definer set search_path='' as $$
declare g uuid;
begin
 if tg_table_name='groups' then g=new.id; else g=coalesce(new.group_id,old.group_id); end if;
 if exists(select 1 from public.groups where id=g and deleted_at is null) and
 (select count(*) from public.group_members m join public.persons p on p.id=m.person_id where m.group_id=g and m.role='owner' and p.claimed_by_user_id is not null and p.status='claimed')<>1 then raise exception 'group_requires_one_claimed_owner'; end if;
 return null;
end $$;
create constraint trigger group_owner_required after insert or update on public.groups deferrable initially deferred for each row execute function private.owner_invariant();
create constraint trigger membership_owner_required after insert or update or delete on public.group_members deferrable initially deferred for each row execute function private.owner_invariant();

alter table public.users enable row level security;
alter table public.groups enable row level security;
alter table public.persons enable row level security;
alter table public.group_members enable row level security;
alter table public.person_contacts enable row level security;
alter table public.invites enable row level security;
alter table public.invite_redemptions enable row level security;
alter table public.audit_logs enable row level security;
alter table public.rate_limits enable row level security;
revoke all on public.users,public.groups,public.persons,public.group_members,public.person_contacts,public.invites,public.invite_redemptions,public.audit_logs,public.rate_limits from anon,authenticated;
grant select on public.users,public.groups,public.persons,public.group_members to authenticated;
grant select(id,purpose,target_id,created_by_user_id,expires_at,max_uses,use_count,revoked_at,used_at,created_at,updated_at) on public.invites to authenticated;
create policy self_read on public.users for select to authenticated using(id=(select auth.uid()));
create policy group_read on public.groups for select to authenticated using(private.member_of(id));
create policy person_read on public.persons for select to authenticated using(status<>'removed' and private.member_of(group_id));
create policy membership_read on public.group_members for select to authenticated using(private.member_of(group_id));
create policy invite_owner_read on public.invites for select to authenticated using(private.owner_of(target_id));

create function public.update_profile(p_name text) returns void language plpgsql security definer set search_path='' as $$
begin update public.users set display_name=trim(p_name) where id=private.require_user(); end $$;
create function public.create_group(p_name text) returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=private.require_user(); g uuid; p uuid;
begin
 if not private.throttle('create_group',30) then raise exception 'rate_limit'; end if;
 insert into public.groups(name,created_by_user_id) values(trim(p_name),u) returning id into g;
 insert into public.persons(group_id,display_name,claimed_by_user_id,created_by_user_id,status) select g,display_name,u,u,'claimed' from public.users where id=u returning id into p;
 insert into public.group_members values(g,p,'owner',now()); perform private.log('group_created','group',g); return g;
end $$;
create function public.rename_group(p_group uuid,p_name text) returns void language plpgsql security definer set search_path='' as $$
begin perform private.lock_owner(p_group); update public.groups set name=trim(p_name) where id=p_group; perform private.log('group_renamed','group',p_group); end $$;
create function public.add_friend(p_group uuid,p_name text,p_contact jsonb default null) returns uuid language plpgsql security definer set search_path='' as $$
declare p uuid;
begin
 perform private.lock_owner(p_group);
 insert into public.persons(group_id,display_name,created_by_user_id,status) values(p_group,trim(p_name),auth.uid(),'unclaimed') returning id into p;
 insert into public.group_members values(p_group,p,'member',now());
 if p_contact is not null then insert into public.person_contacts(person_id,contact_type,encrypted_value,contact_hash) values(p,p_contact->>'contact_type',p_contact->>'encrypted_value',p_contact->>'contact_hash'); end if;
 perform private.log('placeholder_created','person',p); return p;
end $$;
create function public.issue_group_invite(p_group uuid,p_hash text) returns uuid language plpgsql security definer set search_path='' as $$
declare i uuid;
begin
 perform private.lock_owner(p_group); if not private.throttle('issue_invite',30) then raise exception 'rate_limit'; end if;
 insert into public.invites(target_id,token_hash,created_by_user_id) values(p_group,p_hash,auth.uid()) returning id into i;
 perform private.log('invite_created','invite',i); return i;
end $$;
create function public.revoke_group_invite(p_invite uuid) returns void language plpgsql security definer set search_path='' as $$
declare g uuid;
begin select target_id into g from public.invites where id=p_invite; perform private.lock_owner(g); update public.invites set revoked_at=coalesce(revoked_at,now()) where id=p_invite; perform private.log('invite_revoked','invite',p_invite); end $$;
create function public.redeem_group_invite(p_hash text) returns uuid language plpgsql security definer set search_path='' as $$
declare u uuid:=private.require_user(); i public.invites; g uuid; p uuid;
begin
 -- Invalid attempts RETURN NULL instead of raising: the throttle write must commit.
 if not private.throttle('redeem_invite',30) then return null; end if;
 select target_id into g from public.invites where token_hash=p_hash;
 if g is null then return null; end if;
 perform 1 from public.groups where id=g for update;
 select * into i from public.invites where token_hash=p_hash for update;
 if exists(select 1 from public.invite_redemptions where invite_id=i.id and user_id=u) then
  if private.member_of(g) then return g; else return null; end if;
 end if;
 if i.revoked_at is not null or i.expires_at<=now() or i.use_count>=i.max_uses or exists(select 1 from public.groups where id=g and deleted_at is not null) then return null; end if;
 select m.person_id into p from public.group_members m join public.persons pp on pp.id=m.person_id where m.group_id=g and pp.claimed_by_user_id=u and pp.status='claimed' order by m.person_id limit 1;
 if p is null then
  insert into public.persons(group_id,display_name,claimed_by_user_id,created_by_user_id,status) select g,display_name,u,u,'claimed' from public.users where id=u returning id into p;
  insert into public.group_members values(g,p,'member',now());
 end if;
 insert into public.invite_redemptions(invite_id,user_id,person_id) values(i.id,u,p);
 update public.invites set use_count=use_count+1,used_at=now() where id=i.id;
 perform private.log('invite_redeemed','invite',i.id); return g;
end $$;
create function public.remove_group_member(p_group uuid,p_person uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 perform private.lock_owner(p_group);
 if not exists(select 1 from public.group_members where group_id=p_group and person_id=p_person and role='member') then raise exception 'unavailable'; end if;
 delete from public.group_members where group_id=p_group and person_id=p_person;
 update public.persons set status='removed' where id=p_person and group_id=p_group;
 perform private.log('member_removed','person',p_person);
end $$;
create function public.transfer_group_owner(p_group uuid,p_person uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 perform private.lock_owner(p_group);
 if not exists(select 1 from public.group_members m join public.persons p on p.id=m.person_id where m.group_id=p_group and m.person_id=p_person and m.role='member' and p.status='claimed' and p.claimed_by_user_id is not null and p.claimed_by_user_id<>auth.uid()) then raise exception 'unavailable'; end if;
 update public.group_members set role='member' where group_id=p_group and role='owner';
 update public.group_members set role='owner' where group_id=p_group and person_id=p_person;
 perform private.log('ownership_transferred','group',p_group);
end $$;
create function public.leave_group(p_group uuid) returns void language plpgsql security definer set search_path='' as $$
declare p uuid;
begin
 perform private.require_user(); perform 1 from public.groups where id=p_group for update;
 if private.owner_of(p_group) then raise exception 'transfer_ownership_first'; end if;
 for p in select m.person_id from public.group_members m join public.persons pp on pp.id=m.person_id where m.group_id=p_group and pp.claimed_by_user_id=auth.uid() loop
 delete from public.group_members where group_id=p_group and person_id=p;
 update public.persons set status='removed' where id=p;
 perform private.log('member_left','person',p);
 end loop;
end $$;

-- Functions default to PUBLIC execution in PostgreSQL; revoke explicitly.
revoke all on all functions in schema private from public,anon,authenticated;
grant execute on function private.member_of(uuid), private.owner_of(uuid) to authenticated;
revoke all on function public.create_group(text), public.rename_group(uuid,text), public.add_friend(uuid,text,jsonb), public.update_profile(text), public.issue_group_invite(uuid,text), public.revoke_group_invite(uuid), public.redeem_group_invite(text), public.remove_group_member(uuid,uuid), public.transfer_group_owner(uuid,uuid), public.leave_group(uuid) from public,anon;
grant execute on function public.create_group(text), public.rename_group(uuid,text), public.add_friend(uuid,text,jsonb), public.update_profile(text), public.issue_group_invite(uuid,text), public.revoke_group_invite(uuid), public.redeem_group_invite(text), public.remove_group_member(uuid,uuid), public.transfer_group_owner(uuid,uuid), public.leave_group(uuid) to authenticated;

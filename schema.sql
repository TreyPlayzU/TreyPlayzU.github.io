-- MANHUNT: run once in Supabase SQL editor. All game logic is server-side; tables are locked, clients only call RPCs.
create table lobbies(id uuid primary key default gen_random_uuid(), code text unique not null, host uuid not null,
 status text not null default 'waiting', -- waiting|active|completed|cancelled
 s jsonb not null default '{"hunters":1,"dur":30,"head":5,"interval":300,"cp_total":3,"cp_reduce":2,"cp_min":100,"cp_max":400,"cp_radius":25,"grace":20,"acc_tol":50}',
 zone jsonb, started_at timestamptz, last_snap timestamptz, end_reason text, ended_at timestamptz, created timestamptz default now());
create table players(id uuid primary key default gen_random_uuid(), lobby uuid not null references lobbies on delete cascade, uid uuid not null,
 name text not null, ready bool default false, loc_ok bool default false, role text, anon text,
 status text default 'active', -- active|caught|eliminated|escaped|left
 reason text, caught_by uuid, lat float8, lng float8, acc float8, loc_at timestamptz, out_since timestamptz,
 snap_lat float8, snap_lng float8, snap_at timestamptz, catches int default 0,
 cp_done int default 0, cp_lat float8, cp_lng float8, cp_hits int default 0, reduce_s int default 0, unique(lobby,uid));
alter table lobbies enable row level security; alter table players enable row level security; -- no policies = no direct access
revoke all on all tables in schema public from anon, authenticated;

create function pip(la float8, ln float8, z jsonb) returns bool language plpgsql immutable as $$
declare n int=jsonb_array_length(z); i int; j int; ins bool=false; yi float8; xi float8; yj float8; xj float8;
begin j:=n-1; for i in 0..n-1 loop
 yi:=(z->i->>0)::float8; xi:=(z->i->>1)::float8; yj:=(z->j->>0)::float8; xj:=(z->j->>1)::float8;
 if ((yi>la)<>(yj>la)) and (ln < (xj-xi)*(la-yi)/(yj-yi)+xi) then ins:=not ins; end if; j:=i; end loop; return ins; end $$;
create function dist(a float8,b float8,c float8,d float8) returns float8 language sql immutable as $$
 select 12742000*asin(sqrt(sin(radians(c-a)/2)^2+cos(radians(a))*cos(radians(c))*sin(radians(d-b)/2)^2)) $$;

-- per-hider random checkpoint, inside the real polygon; shrinks search distance, then falls back to any point in zone
create function gen_cp(pid uuid) returns void language plpgsql security definer set search_path=public as $$
declare p players; l lobbies; mn float8; mx float8; d float8; b float8; la float8; ln float8; k int; a float8; bb float8; c float8; e float8;
begin select * into p from players where id=pid; select * into l from lobbies where id=p.lobby;
 mn:=(l.s->>'cp_min')::float8; mx:=(l.s->>'cp_max')::float8;
 for k in 1..60 loop
  if k%15=0 then mx:=greatest(mn,mx/2); mn:=mn/2; end if;
  d:=mn+random()*(mx-mn); b:=random()*2*pi();
  la:=p.lat+d*cos(b)/111320; ln:=p.lng+d*sin(b)/(111320*cos(radians(p.lat)));
  if pip(la,ln,l.zone) and (p.cp_lat is null or dist(la,ln,p.cp_lat,p.cp_lng)>mn/2) then
   update players set cp_lat=la,cp_lng=ln,cp_hits=0 where id=pid; return; end if;
 end loop;
 select min((x->>0)::float8),max((x->>0)::float8),min((x->>1)::float8),max((x->>1)::float8) into a,bb,c,e from jsonb_array_elements(l.zone) x;
 for k in 1..500 loop la:=a+random()*(bb-a); ln:=c+random()*(e-c);
  if pip(la,ln,l.zone) then update players set cp_lat=la,cp_lng=ln,cp_hits=0 where id=pid; return; end if; end loop;
end $$;

create function _finish(lid uuid, why text) returns void language sql security definer set search_path=public as $$
 update lobbies set status='completed',end_reason=why,ended_at=now() where id=lid;
 update players set lat=null,lng=null,snap_lat=null,snap_lng=null,cp_lat=null,cp_lng=null where lobby=lid; -- drop location data at match end
$$;

-- advances the clock-driven rules: boundary grace, escapes, scheduled snapshots, end conditions. Called by every RPC.
create function tick(lid uuid) returns void language plpgsql security definer set search_path=public as $$
declare l lobbies; hs timestamptz; en timestamptz; iv int;
begin select * into l from lobbies where id=lid for update; if l.status<>'active' then return; end if;
 hs:=l.started_at+((l.s->>'head')::int*60)*interval '1 second'; en:=hs+((l.s->>'dur')::int*60)*interval '1 second'; iv:=(l.s->>'interval')::int;
 update players set status='eliminated',reason='left play zone' where lobby=lid and role='hider' and status='active' and out_since is not null
  and now()-out_since>((l.s->>'grace')::int)*interval '1 second';
 update players set status='escaped',reason='survived' where lobby=lid and role='hider' and status='active' and now()>=hs and now()>=en-reduce_s*interval '1 second';
 if now()>=hs and (l.last_snap is null or now()>=l.last_snap+iv*interval '1 second') then
  update players set snap_lat=lat,snap_lng=lng,snap_at=loc_at where lobby=lid and role='hider' and status='active' and loc_at>now()-interval '90 seconds';
  update lobbies set last_snap=now() where id=lid; end if;
 if not exists(select 1 from players where lobby=lid and role='hider' and status='active') then
  perform _finish(lid, case when now()>=en then 'Time expired' else 'All hiders caught, eliminated or escaped' end); end if;
end $$;

create function create_lobby(p_name text) returns text language plpgsql security definer set search_path=public as $$
declare c text; l uuid;
begin if auth.uid() is null then raise exception 'Sign in required'; end if;
 if length(trim(p_name))<1 then raise exception 'Enter a display name'; end if;
 loop c:=upper(substr(md5(random()::text),1,5)); exit when not exists(select 1 from lobbies where code=c); end loop;
 insert into lobbies(code,host) values(c,auth.uid()) returning id into l;
 insert into players(lobby,uid,name) values(l,auth.uid(),left(trim(p_name),20)); return c; end $$;

create function join_lobby(p_code text, p_name text) returns void language plpgsql security definer set search_path=public as $$
declare l lobbies;
begin select * into l from lobbies where code=upper(trim(p_code)) for update; if l.id is null then raise exception 'Lobby not found'; end if;
 if exists(select 1 from players where lobby=l.id and uid=auth.uid()) then return; end if; -- reconnect / no duplicates
 if l.status<>'waiting' then raise exception 'Match already started'; end if;
 if (select count(*) from players where lobby=l.id)>=10 then raise exception 'Lobby is full (10 players)'; end if;
 if length(trim(p_name))<1 then raise exception 'Enter a display name'; end if;
 insert into players(lobby,uid,name) values(l.id,auth.uid(),left(trim(p_name),20)); end $$;

create function save_settings(p_code text, p_s jsonb, p_zone jsonb) returns void language plpgsql security definer set search_path=public as $$
declare l lobbies; s jsonb;
begin select * into l from lobbies where code=upper(p_code) for update;
 if l.id is null or l.host<>auth.uid() then raise exception 'Host only'; end if;
 if l.status<>'waiting' then raise exception 'Settings are locked'; end if;
 if jsonb_typeof(p_zone)<>'array' or jsonb_array_length(p_zone)<3 or jsonb_array_length(p_zone)>100 then raise exception 'Draw a play zone with at least 3 points'; end if;
 s:=jsonb_build_object('hunters',least(9,greatest(1,(p_s->>'hunters')::int)),'dur',least(240,greatest(5,(p_s->>'dur')::int)),
  'head',least(60,greatest(0,(p_s->>'head')::int)),'interval',least(1800,greatest(30,(p_s->>'interval')::int)),
  'cp_total',least(10,greatest(0,(p_s->>'cp_total')::int)),'cp_reduce',least(60,greatest(0,(p_s->>'cp_reduce')::int)),
  'cp_min',least(2000,greatest(20,(p_s->>'cp_min')::int)),'cp_max',least(5000,greatest((p_s->>'cp_min')::int,(p_s->>'cp_max')::int)),
  'cp_radius',least(100,greatest(10,(p_s->>'cp_radius')::int)),'grace',least(300,greatest(5,(p_s->>'grace')::int)),
  'acc_tol',least(200,greatest(10,(p_s->>'acc_tol')::int)));
 update lobbies set s=s, zone=p_zone where id=l.id; end $$;

create function set_ready(p_code text, p_ready bool, p_loc bool) returns void language sql security definer set search_path=public as $$
 update players set ready=p_ready, loc_ok=p_loc from lobbies l where l.id=players.lobby and l.code=upper(p_code) and l.status='waiting' and players.uid=auth.uid() $$;

create function start_match(p_code text) returns void language plpgsql security definer set search_path=public as $$
declare l lobbies; n int; h int;
begin select * into l from lobbies where code=upper(p_code) for update;
 if l.id is null or l.host<>auth.uid() then raise exception 'Host only'; end if;
 if l.status<>'waiting' then raise exception 'Already started'; end if;
 select count(*) into n from players where lobby=l.id; h:=(l.s->>'hunters')::int;
 if n<2 then raise exception 'Need at least 2 players'; end if;
 if l.zone is null then raise exception 'Save a play zone first'; end if;
 if h>n-1 then raise exception 'Too many hunters for % players (max %)',n,n-1; end if;
 if exists(select 1 from players where lobby=l.id and not loc_ok) then raise exception 'Everyone must enable location first'; end if;
 with r as (select id,row_number() over(order by random()) rn from players where lobby=l.id)
  update players p set role=case when r.rn<=h then 'hunter' else 'hider' end from r where p.id=r.id;
 with r as (select id,role,row_number() over(partition by role order by random()) rn from players where lobby=l.id)
  update players p set anon=case when r.role='hunter' then 'Hunter ' else 'Hider ' end||chr(64+r.rn::int) from r where p.id=r.id;
 update lobbies set status='active',started_at=now(),last_snap=null where id=l.id; end $$;

create function report_loc(p_code text, p_lat float8, p_lng float8, p_acc float8) returns void language plpgsql security definer set search_path=public as $$
declare l lobbies; p players; hits int; rad float8; tot int;
begin select * into l from lobbies where code=upper(p_code); if l.id is null then raise exception 'Lobby not found'; end if;
 select * into p from players where lobby=l.id and uid=auth.uid() for update; if p.id is null then raise exception 'Not in lobby'; end if;
 if l.status<>'active' or p.status<>'active' then return; end if;
 if abs(p_lat)>90 or abs(p_lng)>180 or p_acc is null then raise exception 'Invalid location'; end if;
 if p.loc_at is not null and now()-p.loc_at<interval '2 seconds' then return; end if; -- rate limit
 update players set lat=p_lat,lng=p_lng,acc=p_acc,loc_at=now() where id=p.id;
 if p.role='hider' then
  if p_acc<=(l.s->>'acc_tol')::float8 then -- inaccurate fixes can never start or confirm a violation
   if pip(p_lat,p_lng,l.zone) then update players set out_since=null where id=p.id;
   else update players set out_since=coalesce(out_since,now()) where id=p.id; end if; end if;
  tot:=(l.s->>'cp_total')::int; rad:=(l.s->>'cp_radius')::float8;
  if p.cp_done<tot then
   if p.cp_lat is null then perform gen_cp(p.id);
   elsif p_acc<=30 and dist(p_lat,p_lng,p.cp_lat,p.cp_lng)<=rad then
    update players set cp_hits=cp_hits+1 where id=p.id returning cp_hits into hits;
    if hits>=2 then -- two consistent fixes required
     update players set cp_done=cp_done+1,reduce_s=reduce_s+(l.s->>'cp_reduce')::int*60,cp_hits=0 where id=p.id;
     if p.cp_done+1<tot then perform gen_cp(p.id); else update players set cp_lat=null,cp_lng=null where id=p.id; end if; end if;
   else update players set cp_hits=0 where id=p.id; end if; end if; end if;
 perform tick(l.id); end $$;

create function catch_hider(p_code text, p_anon text) returns void language plpgsql security definer set search_path=public as $$
declare l lobbies; p players;
begin select * into l from lobbies where code=upper(p_code); select * into p from players where lobby=l.id and uid=auth.uid();
 if p.id is null or p.role<>'hunter' then raise exception 'Hunters only'; end if;
 if l.status<>'active' then raise exception 'Match is not active'; end if;
 if now()<l.started_at+((l.s->>'head')::int*60)*interval '1 second' then raise exception 'Hunt has not begun'; end if;
 update players set status='caught',reason='reported caught',caught_by=p.id where lobby=l.id and role='hider' and anon=p_anon and status='active'; -- atomic: only one report can win
 if not found then raise exception 'That hider is already out'; end if;
 update players set catches=catches+1 where id=p.id; perform tick(l.id); end $$;

create function end_match(p_code text) returns void language plpgsql security definer set search_path=public as $$
declare l lobbies;
begin select * into l from lobbies where code=upper(p_code) for update;
 if l.id is null or l.host<>auth.uid() then raise exception 'Host only'; end if;
 if l.status='active' then update players set status='escaped',reason='survived' where lobby=l.id and role='hider' and status='active'; perform _finish(l.id,'Ended by host'); end if; end $$;

create function leave_game(p_code text) returns void language plpgsql security definer set search_path=public as $$
declare l lobbies;
begin select * into l from lobbies where code=upper(p_code); if l.id is null then return; end if;
 if l.status='waiting' then
  if l.host=auth.uid() then update lobbies set status='cancelled' where id=l.id; else delete from players where lobby=l.id and uid=auth.uid(); end if;
 else update players set status='left',reason='left game' where lobby=l.id and uid=auth.uid() and status='active'; perform tick(l.id); end if; end $$;

create function rematch(p_code text) returns void language plpgsql security definer set search_path=public as $$
declare l lobbies;
begin select * into l from lobbies where code=upper(p_code) for update;
 if l.id is null or l.host<>auth.uid() then raise exception 'Host only'; end if;
 if l.status<>'completed' then raise exception 'Match is not finished'; end if;
 delete from players where lobby=l.id and status='left';
 update players set role=null,anon=null,status='active',reason=null,caught_by=null,lat=null,lng=null,acc=null,loc_at=null,out_since=null,snap_lat=null,snap_lng=null,
  snap_at=null,catches=0,cp_done=0,cp_lat=null,cp_lng=null,cp_hits=0,reduce_s=0,ready=false where lobby=l.id;
 update lobbies set status='waiting',started_at=null,last_snap=null,end_reason=null,ended_at=null where id=l.id; end $$;

-- role-filtered view of the game; the only read path clients have
create function state(p_code text) returns jsonb language plpgsql security definer set search_path=public as $$
declare l lobbies; p players; hs timestamptz; en timestamptz; r jsonb;
begin select * into l from lobbies where code=upper(trim(p_code)); if l.id is null then raise exception 'Lobby not found'; end if;
 select * into p from players where lobby=l.id and uid=auth.uid(); if p.id is null then raise exception 'You are not in this lobby'; end if;
 perform tick(l.id); select * into l from lobbies where id=l.id; select * into p from players where id=p.id;
 hs:=l.started_at+((l.s->>'head')::int*60)*interval '1 second'; en:=hs+((l.s->>'dur')::int*60)*interval '1 second';
 r:=jsonb_build_object('now',now(),'status',l.status,'s',l.s,'zone',l.zone,'hs',hs,'en',en,'end_reason',l.end_reason,
  'next_snap',case when l.last_snap is null then hs else l.last_snap+((l.s->>'interval')::int)*interval '1 second' end,
  'me',jsonb_build_object('name',p.name,'host',l.host=auth.uid(),'role',p.role,'status',p.status,'anon',p.anon,'ready',p.ready,'loc_ok',p.loc_ok,
   'cp_done',p.cp_done,'red',p.reduce_s,'cp',case when p.role='hider' and p.status='active' and p.cp_lat is not null then jsonb_build_array(p.cp_lat,p.cp_lng) end));
 if l.status='waiting' then
  r:=r||jsonb_build_object('players',(select coalesce(jsonb_agg(jsonb_build_object('name',name,'ready',ready,'loc_ok',loc_ok,'host',uid=l.host) order by id),'[]') from players where lobby=l.id));
 elsif l.status in('completed','cancelled') then
  r:=r||jsonb_build_object('results',(select coalesce(jsonb_agg(jsonb_build_object('name',name,'role',role,'status',status,'reason',reason,'catches',catches,'cp',cp_done,'red',reduce_s) order by role,catches desc),'[]') from players where lobby=l.id));
 elsif p.role='hunter' then -- anonymous hiders, released snapshots only, never live coordinates or names
  r:=r||jsonb_build_object('hiders',(select coalesce(jsonb_agg(jsonb_build_object('anon',anon,'status',status,'lat',case when status='active' then snap_lat end,
    'lng',case when status='active' then snap_lng end,'at',snap_at) order by anon),'[]') from players where lobby=l.id and role='hider'),
   'board',(select coalesce(jsonb_agg(jsonb_build_object('anon',anon,'catches',catches) order by catches desc,anon),'[]') from players where lobby=l.id and role='hunter'));
 end if;
 return r; end $$;

revoke execute on all functions in schema public from public, anon, authenticated;
grant execute on function create_lobby(text),join_lobby(text,text),save_settings(text,jsonb,jsonb),set_ready(text,bool,bool),start_match(text),
 report_loc(text,float8,float8,float8),catch_hider(text,text),end_match(text),leave_game(text),rematch(text),state(text) to authenticated;
-- optional retention (needs pg_cron): select cron.schedule('purge','0 4 * * *',$$delete from lobbies where created<now()-interval '2 days'$$);

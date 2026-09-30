-- Character identity opens additional branches in the existing regional NPCs.
create table if not exists public.uc_v4_routes(id text primary key,area text not null references public.uc_areas(id),npc text not null references public.uc_npcs(id),required_race text,required_class text,required_faction text,minimum integer not null default 0,label text not null,reply text not null,clue text not null,benefit_faction text,skill text not null,dc integer not null);
alter table public.uc_v4_routes enable row level security;
revoke all on public.uc_v4_routes from public,anon,authenticated;
insert into public.uc_v4_routes values('mara_tiefling','kegs','mara','提夫林',null,null,0,'[提夫林] 先问她为何替外乡证人留房','玛拉把钥匙推来：“我年轻时也被人说过不像这座城的人。楼上的房间不查血统，只问有没有人跟着你。”','玛拉的安全房间','underground','洞悉',12) on conflict(id) do update set reply=excluded.reply,clue=excluded.clue;
insert into public.uc_v4_routes values('mara_bard','kegs','mara',null,'吟游诗人',null,0,'[吟游诗人] 借今晚的歌询问传闻','她敲了三下杯沿：“别唱出证人的名字。停顿在第十三拍，知道旧钟的人会抬头。”','酒馆第十三拍','underground','表演',13) on conflict(id) do update set reply=excluded.reply,clue=excluded.clue;
insert into public.uc_v4_routes values('mara_network','kegs','mara',null,null,'underground',20,'[地下势力] 请她安排证人暗路','玛拉展开后院地板下的旧水道图：“我们的人认得你的名字。带活人走这条路，别带追兵。”','酒馆后院暗路','underground','说服',11) on conflict(id) do update set reply=excluded.reply,clue=excluded.clue;
insert into public.uc_v4_routes values('elric_dwarf','wonders','elric','矮人',null,null,0,'[矮人] 指出第五环的锻痕','艾尔里克停下手中的锉刀：“这不是我们的炉子。石粉来自北段城墙的排水井，铜片却在这里登记入库。”','北段井石粉','gond','调查',12) on conflict(id) do update set reply=excluded.reply,clue=excluded.clue;
insert into public.uc_v4_routes values('elric_wizard','wonders','elric',null,'法师',null,0,'[法师] 解析星盘的残留符文','他允许你靠近封存柜。灼痕组成的是延迟九息的启动式，而不是攻击法阵。','星盘延迟符文','gond','奥秘',14) on conflict(id) do update set reply=excluded.reply,clue=excluded.clue;
insert into public.uc_v4_routes values('elric_gond','wonders','elric',null,null,'gond',20,'[贡德声望] 调出修复记录原件','“你们替药剂师守住过病人。”他打开原簿，失窃当晚的试火时刻比军令早了一刻。','失窃当晚试火记录','gond','调查',11) on conflict(id) do update set reply=excluded.reply,clue=excluded.clue;
insert into public.uc_v4_routes values('vessa_human','hall','vessa','人类',null,null,0,'[人类] 询问居民如何申请旁听','维莎在名单下划线：“入场不需要贵族徽章。把居民的名字交给我，我要他们在记录里有座位。”','公开旁听登记','hall','说服',13) on conflict(id) do update set reply=excluded.reply,clue=excluded.clue;
insert into public.uc_v4_routes values('vessa_elf','hall','vessa','精灵',null,null,0,'[精灵] 比对旧印与早年的纪年法','她把两份卷宗并排铺开。旧印边缘刻着精灵历的月相，证明其中一份“新”军令借用了旧模。','旧印精灵月相','hall','历史',14) on conflict(id) do update set reply=excluded.reply,clue=excluded.clue;
insert into public.uc_v4_routes values('vessa_paladin','hall','vessa',null,'圣武士',null,0,'[圣武士] 以誓言担保证人的安全','“誓言不能替代记录，但能让人敢签下名字。”维莎准许证人在你的护送下进入侧厅。','证人侧厅通行','hall','说服',14) on conflict(id) do update set reply=excluded.reply,clue=excluded.clue;
insert into public.uc_v4_routes values('vessa_hall','hall','vessa',null,null,'hall',20,'[大厅声望] 阅览封存的质询笔录','维莎交出盖有双印的副本：“曾经被你们保护的人现在愿意说出谁改写了钟声。”','封存质询笔录','hall','调查',11) on conflict(id) do update set reply=excluded.reply,clue=excluded.clue;
insert into public.uc_v4_routes values('kevan_dragon','walls','kevan','龙裔',null,null,0,'[龙裔] 观察灯号与风向的冲突','凯文抬头：“你的眼睛看得比我的新兵远。第五盏灯的烟逆风而行，那是有人在塔内点了第二盏。”','逆风的第五灯','guard','察觉',13) on conflict(id) do update set reply=excluded.reply,clue=excluded.clue;
insert into public.uc_v4_routes values('kevan_ranger','walls','kevan',null,'游侠',null,0,'[游侠] 沿排风井寻找第五人的脚印','他让开路。井边的泥只留了四双靴印，第五个人踩着铁梯上了军需仓。','军需仓铁梯脚印','guard','求生',14) on conflict(id) do update set reply=excluded.reply,clue=excluded.clue;
insert into public.uc_v4_routes values('kevan_guard','walls','kevan',null,null,'guard',20,'[守卫声望] 请求北段卫队掩护','“我记得你们带回来的兵。”凯文交出北门钟表，终战时能避开第一轮的侧翼伏兵。','北门掩护钟表','guard','说服',11) on conflict(id) do update set reply=excluded.reply,clue=excluded.clue;

create or replace function public.party_v4_dialogue(p_code text,p_route text)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_code text:=upper(trim(p_code)); v_actor public.players%rowtype; v_route public.uc_v4_routes%rowtype;
 v_state jsonb; v_result jsonb; v_key text; v_log text;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
 perform 1 from public.rooms where code=v_code for update;
 if not found then raise exception 'ROOM_NOT_FOUND'; end if;
 select * into v_actor from public.players where room_code=v_code and user_id=auth.uid() for update;
 if not found or not v_actor.is_online or v_actor.last_seen<now()-interval '90 seconds' then raise exception 'RECONNECT_FIRST'; end if;
 if v_actor.conditions ? 'jailed' then raise exception 'JAILED'; end if;
 select * into v_route from public.uc_v4_routes where id=p_route;
 if not found then raise exception 'INVALID_ROUTE'; end if;
 select state into v_state from public.game_states where room_code=v_code for update;
 if not coalesce((v_state->>'started')::boolean,false) or v_state->>'current_area'<>v_route.area
  or (v_state->>'chapter')::integer<(select unlock_chapter from public.uc_areas where id=v_route.area)
  or coalesce((v_state#>>'{combat,hp}')::integer,0)>0 or coalesce((v_state->>'v4_camp')::boolean,false) then raise exception 'NPC_UNAVAILABLE'; end if;
 if v_route.required_race is not null and v_actor.race<>v_route.required_race
  or v_route.required_class is not null and v_actor.class_name<>v_route.required_class
  or v_route.required_faction is not null and coalesce((v_actor.reputation->>v_route.required_faction)::integer,0)<v_route.minimum then raise exception 'ROUTE_REQUIREMENT'; end if;
 v_key:=v_actor.id::text||':'||v_route.id;
 if coalesce(v_state->'v4_dialogue','{}'::jsonb) ? v_route.id then raise exception 'ROUTE_RESOLVED'; end if;
 if coalesce(v_state->'v4_dialogue_attempts','{}'::jsonb) ? v_key then raise exception 'ROUTE_ATTEMPTED'; end if;
 v_result:=public.campaign_v4_check(v_actor.id,v_route.skill,v_route.dc,'normal',0,false)||jsonb_build_object('at',clock_timestamp(),'actor',v_actor.name);
 v_state:=jsonb_set(v_state,'{last_roll}',v_result,true);
 v_state:=jsonb_set(v_state,'{v4_dialogue_attempts}',coalesce(v_state->'v4_dialogue_attempts','{}'::jsonb)||jsonb_build_object(v_key,true),true);
 if (v_result->>'success')::boolean then
  v_state:=jsonb_set(v_state,'{v4_dialogue}',coalesce(v_state->'v4_dialogue','{}'::jsonb)||jsonb_build_object(v_route.id,true),true);
  if not coalesce(v_state->'clues','[]'::jsonb) ? v_route.clue then
   v_state:=jsonb_set(v_state,'{clues}',coalesce(v_state->'clues','[]'::jsonb)||to_jsonb(v_route.clue),true);
  end if;
  v_state:=jsonb_set(v_state,'{area_attitudes}',jsonb_set(coalesce(v_state->'area_attitudes','{}'::jsonb),array[v_route.npc],to_jsonb(least(5,coalesce((v_state->'area_attitudes'->>v_route.npc)::integer,0)+1)),true),true);
  if v_route.benefit_faction is not null then
   update public.players set reputation=jsonb_set(reputation,array[v_route.benefit_faction],to_jsonb(least(100,coalesce((reputation->>v_route.benefit_faction)::integer,0)+4))) where id=v_actor.id;
  end if;
  v_log:=v_route.reply||' 获得线索：'||v_route.clue;
 else v_log:=v_actor.name||'尝试'||v_route.skill||'（DC '||v_route.dc||'），对方暂时不愿交出这条线索。'; end if;
 update public.game_states set state=jsonb_set(v_state,'{version}',to_jsonb(coalesce((v_state->>'version')::integer,0)+1)),updated_at=now() where room_code=v_code;
 insert into public.messages(room_code,sender,body,kind) values(v_code,(select name from public.uc_npcs where id=v_route.npc),v_log,'v4');
 return public.party_snapshot(v_code);
end $$;
revoke all on function public.party_v4_dialogue(text,text) from public,anon,authenticated;
grant execute on function public.party_v4_dialogue(text,text) to authenticated;

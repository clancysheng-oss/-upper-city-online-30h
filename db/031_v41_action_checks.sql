-- V4.1: durable event checks, authored loot, consequences and scarce Inspiration.
-- The existing engines remain authoritative for chapters, quests and combat.
-- Ledger is part of game_states; Inspiration/award receipts live in build and existing saves.
create or replace function public.campaign_v41_merge_checks() returns trigger language plpgsql set search_path=public,pg_temp as $$
begin
 if old.state ? 'checks' then new.state:=jsonb_set(new.state,'{checks}',coalesce(old.state->'checks','{}')||coalesce(new.state->'checks','{}'),true); end if;
 return new;
end $$;
create trigger campaign_v41_merge_checks before update of state on public.game_states for each row execute function public.campaign_v41_merge_checks();
revoke all on function public.campaign_v41_merge_checks() from public,anon,authenticated;

create or replace function public.campaign_v41_inspiration(p_actor bigint,p_source text) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare p public.players%rowtype; n integer;
begin
 select * into p from public.players where id=p_actor for update;
 if not found or p.is_companion or coalesce(p.build->'inspiration_awards','{}') ? p_source then return; end if;
 n:=coalesce((p.build->>'inspiration')::integer,0);
 update public.players set build=build||jsonb_build_object('inspiration',least(4,n+1),'inspiration_awards',coalesce(build->'inspiration_awards','{}')||jsonb_build_object(p_source,true)) where id=p_actor;
 if n<4 then insert into public.messages(room_code,sender,body,kind) values(p.room_code,p.name,'获得 Inspiration +1 · '||p_source||'（'||(n+1)||'/4）','inspiration'); end if;
end $$;
revoke all on function public.campaign_v41_inspiration(bigint,text) from public,anon,authenticated;

alter function public.campaign_v4_check(bigint,text,integer,text,integer,boolean) rename to campaign_v41_dice_core;
revoke all on function public.campaign_v41_dice_core(bigint,text,integer,text,integer,boolean) from public,anon,authenticated;
create or replace function public.campaign_v4_check(p_player bigint,p_skill text,p_dc integer,p_mode text default 'normal',p_bonus integer default 0,p_save boolean default false)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare ctx jsonb; r jsonb; s jsonb; oldcheck jsonb; p public.players%rowtype; key text; retry boolean;
begin
 ctx:=nullif(current_setting('uc.check_context',true),'')::jsonb;
 if ctx is null then return public.campaign_v41_dice_core(p_player,p_skill,p_dc,p_mode,p_bonus,p_save); end if;
 select * into p from public.players where id=p_player;
 key:=ctx->>'check_id';retry:=coalesce((ctx->>'retry')::boolean,false);
 select state into s from public.game_states where room_code=p.room_code for update;
 oldcheck:=s#>array['checks',key];
 if oldcheck is not null and not retry then raise exception 'CHECK_ALREADY_ATTEMPTED'; end if;
 if retry and (oldcheck is null or (oldcheck->>'attempted_by')::bigint<>p_player or (oldcheck->>'resolved')::boolean or (oldcheck->>'reroll_used')::boolean or (oldcheck#>>'{result,success}')::boolean) then raise exception 'REROLL_UNAVAILABLE'; end if;
 if retry then
  update public.players set build=jsonb_set(build,'{inspiration}',to_jsonb(coalesce((build->>'inspiration')::integer,0)-1),true) where id=p_player and coalesce((build->>'inspiration')::integer,0)>0;
  if not found then raise exception 'NO_INSPIRATION'; end if;
 end if;
 r:=public.campaign_v41_dice_core(p_player,p_skill,p_dc,p_mode,p_bonus,p_save)||jsonb_build_object('actor',p.name,'actor_id',p.id,'at',clock_timestamp(),'check_id',key,'scope',ctx->>'scope','reroll_used',retry);
 oldcheck:=ctx-'retry'||jsonb_build_object('check_id',key,'attempted_by',p.id,'actor',p.name,'result',r,'reroll_used',retry,'resolved',(r->>'success')::boolean or retry,'attempts',case when retry then 2 else 1 end,'history',coalesce(oldcheck->'history','[]')||jsonb_build_array(r));
 update public.game_states set state=jsonb_set(jsonb_set(state,'{checks}',coalesce(state->'checks','{}')||jsonb_build_object(key,oldcheck),true),'{last_roll}',r,true),updated_at=now() where room_code=p.room_code;
 return r;
end $$;
revoke all on function public.campaign_v4_check(bigint,text,integer,text,integer,boolean) from public,anon,authenticated;

-- Replace only non-combat dice calls in the regional/deeper engines with the shared dice.
do $patch$ declare d text; begin
 d:=pg_get_functiondef('public.party_area_v30_core(text,text,jsonb)'::regprocedure);
 if position('v_roll:=floor(random()*20)::int+1;'||chr(10)||'     v_bonus:=floor(((v_actor.stats->>3)' in d)=0 then raise exception 'V41_AREA_ANCHOR_MISSING'; end if;
 -- The roll is overwritten after authoritative DC assignment, leaving combat v_code intact.
 d:=replace(d,'v_dc:=12+v_area.unlock_chapter/5;', 'v_dc:=12+v_area.unlock_chapter/5; v_stage:=public.campaign_v4_check(v_actor.id,''调查'',v_dc); v_roll:=(v_stage->>''d20'')::integer;v_bonus:=(v_stage->>''total'')::integer-v_roll;');
 d:=replace(d,'v_roll:=floor(random()*20)::int+1; v_dc:=(v_stage->>''dc'')::int;', 'v_dc:=(v_stage->>''dc'')::int; v_option:=public.campaign_v4_check(v_actor.id,v_stage->>''skill'',v_dc);v_roll:=(v_option->>''d20'')::integer;v_bonus:=(v_option->>''total'')::integer-v_roll;');
 d:=replace(d,'暂未成功；可以再调查或由其他队员尝试。','本次机会已记录；可使用执行者的激励点重投一次，或寻找其他路线。');
 execute d;
 d:=pg_get_functiondef('public.party_deep_v30_core(text,text,jsonb)'::regprocedure);
 if position('v_success:=v_roll=20 or (v_roll<>1 and v_roll+v_bonus>=v_data.dc);' in d)=0 then raise exception 'V41_DEEP_ANCHOR_MISSING';end if;
 d:=replace(d,'v_success:=v_roll=20 or (v_roll<>1 and v_roll+v_bonus>=v_data.dc);','v_result:=public.campaign_v4_check(v_actor.id,v_data.skill,v_data.dc);v_roll:=(v_result->>''d20'')::integer;v_bonus:=(v_result->>''total'')::integer-v_roll;v_success:=(v_result->>''success'')::boolean;');
 d:=replace(d,'v_success:=v_idx<>1 and (v_roll=20 or', 'if v_idx<>1 then v_result:=public.campaign_v4_check(v_actor.id,case when v_idx=0 then ''说服'' when v_actor.class_name=''法师'' then ''奥秘'' when v_actor.class_name=''游荡者'' then ''潜行'' when v_actor.class_name=''游侠'' then ''求生'' when v_actor.class_name=''牧师'' then ''医药'' when v_actor.class_name in (''吟游诗人'',''圣武士'') then ''说服'' else ''运动'' end,greatest(5,v_data.dc-2-case when coalesce(v_deep#>>array[''explorationFlags'',v_key||''_secret''],''false'')=''true'' then 3 else 0 end));v_roll:=(v_result->>''d20'')::integer;v_bonus:=(v_result->>''total'')::integer-v_roll;end if; v_success:=v_idx<>1 and (v_roll=20 or');
 execute d;
end $patch$;

-- Deterministic area-specific pools: target identity determines value and DC.
create or replace function public.campaign_v41_target(p_area text,p_type text,p_chapter integer) returns jsonb language sql immutable set search_path=public,pg_temp as $$
 select jsonb_build_object('target',case p_area when 'city' then '城门补给商的账箱' when 'kegs' then '酒馆信使的钱袋与客房' when 'wonders' then '高堂修复师的封存柜' when 'hall' then '书记官的双印卷宗柜' else '卫队军需仓' end,
 'dc',case p_area when 'city' then 13 when 'kegs' then 14 when 'wonders' then 17 when 'hall' then 20 else 18 end+case when p_type='theft' then 2 when p_type='lockpick' then 1 when p_type='trespass' then 2 else 0 end,
 'gold',case p_area when 'city' then 8 when 'kegs' then 12 when 'wonders' then 24 when 'hall' then 40 else 30 end,
 'item',case when p_type='lockpick' then case p_area when 'city' then '城门长剑' when 'kegs' then '护盾卷轴' when 'wonders' then '刻度护符' when 'hall' then '审计官胸针' else '夜巡长弓' end
 when p_type='theft' then case p_area when 'city' then '盾牌' when 'kegs' then '银线药水' when 'wonders' then '星火卷轴' when 'hall' then '护盾卷轴' else '军令破咒卷轴' end
 else case p_area when 'city' then '治疗药水' when 'kegs' then '酒馆客房钥匙' when 'wonders' then '高堂封存柜钥匙' when 'hall' then '书记官密信' else '军需仓钥匙' end end,
 'clue',case p_area when 'city' then '补给商隐瞒的第十三车账单' when 'kegs' then '信使暗房中的证人名单' when 'wonders' then '修复师封存柜的试火原簿' when 'hall' then '双印卷宗中的秘密拨款' else '军需仓通往北门的密道' end,
 'risk',case p_area when 'hall' then 3 when 'wonders' then 2 when 'walls' then 2 else 1 end)
$$;
revoke all on function public.campaign_v41_target(text,text,integer) from public,anon,authenticated;

alter function public.party_v4_world(text,text,jsonb) rename to party_world_v41_core;
alter function public.party_v4_identity(text,text,jsonb) rename to party_identity_v41_core;
alter function public.party_command(text,text,jsonb) rename to party_command_v41_core;
alter function public.party_area(text,text,jsonb) rename to party_area_v41_core;
alter function public.party_deep(text,text,jsonb) rename to party_deep_v41_core;
alter function public.party_v4_dialogue(text,text) rename to party_dialogue_v41_core;
revoke all on function public.party_world_v41_core(text,text,jsonb),public.party_identity_v41_core(text,text,jsonb),public.party_command_v41_core(text,text,jsonb),public.party_area_v41_core(text,text,jsonb),public.party_deep_v41_core(text,text,jsonb),public.party_dialogue_v41_core(text,text) from public,anon,authenticated;

-- Failure effects are settled once, on accepting the result or taking another action.
create or replace function public.campaign_v41_failure(p_code text,p_record jsonb) returns text language plpgsql security definer set search_path=public,pg_temp as $$
declare a bigint:=(p_record->>'attempted_by')::bigint; action text:=p_record->>'action'; n integer; msg text;
begin
 if p_record->>'rpc' not in ('world','identity') then return '本次机会已失去；可以寻找其他路线。';end if;
 if action='crime' then
  n:=coalesce((p_record->>'risk')::integer,1);
  update public.players set wanted=least(5,wanted+n),reputation=jsonb_set(reputation,'{guard}',to_jsonb(greatest(-100,coalesce((reputation->>'guard')::integer,0)-5*n))) where id=a;
  msg:='被目击：通缉 +'||n||'，守卫声望 -'||(5*n)||'。';
 elsif action in ('guard','prison','social') then
  update public.players set reputation=jsonb_set(reputation,'{guard}',to_jsonb(greatest(-100,coalesce((reputation->>'guard')::integer,0)-2))) where id=a;
  msg:=case when action='prison' then '守卫提高警惕，仍被关押；可缴费或服刑。' when action='social' then '本次谈判机会失去；仍可按原价购买。' else '守卫不接受解释；可缴费、接受逮捕或拒捕。' end||' 守卫声望 -2。';
 else msg:='未发现额外线索；本次区域调查机会已用尽。';end if;
 return msg;
end $$;
revoke all on function public.campaign_v41_failure(text,jsonb) from public,anon,authenticated;

create or replace function public.campaign_v41_settle(p_code text,p_key text) returns void language plpgsql security definer set search_path=public,pg_temp as $$
declare r jsonb; msg text;
begin
 select state#>array['checks',p_key] into r from public.game_states where room_code=p_code for update;
 if r is null or coalesce((r->>'resolved')::boolean,false) then return;end if;
 msg:=public.campaign_v41_failure(p_code,r);
 r:=r||jsonb_build_object('resolved',true,'consequence',msg);
 update public.game_states set state=jsonb_set(state,array['checks',p_key],r,true) where room_code=p_code;
 insert into public.messages(room_code,sender,body,kind) values(p_code,r->>'actor','接受结果：'||msg,'check');
end $$;
revoke all on function public.campaign_v41_settle(text,text) from public,anon,authenticated;

create or replace function public.campaign_v41_world(p_code text,p_action text,p_payload jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare p public.players%rowtype; s jsonb; r jsonb; t jsonb; typ text; choice text; skill text; dc integer; log text; item text; key text; ctx jsonb; area text; success boolean;
begin
 select * into p from public.players where room_code=p_code and user_id=auth.uid() for update;
 select state into s from public.game_states where room_code=p_code for update;
 area:=coalesce(s->>'current_area','city');typ:=p_payload->>'type';choice:=p_payload->>'choice';
 if not coalesce((s->>'started')::boolean,false) or p.race is null or p.hp<=0 then raise exception 'ACTION_UNAVAILABLE';end if;
 if coalesce((s#>>'{combat,hp}')::integer,0)>0 or coalesce((s->>'v4_unsafe')::boolean,false) or coalesce((s->>'v4_camp')::boolean,false) then raise exception 'ACTION_UNSAFE';end if;
 if p.conditions ? 'jailed' and p_action<>'prison' then raise exception 'JAILED';end if;
 if p_action='crime' then
  if typ is null or typ not in ('pickpocket','theft','lockpick','trespass','vandalism') then raise exception 'INVALID_CRIME';end if;
  t:=public.campaign_v41_target(area,typ,(s->>'chapter')::integer);dc:=(t->>'dc')::integer;
  skill:=case when typ in ('pickpocket','lockpick') then '巧手' when typ='vandalism' then '运动' else '潜行' end;
 elsif p_action='guard' then
  if p.wanted<1 then raise exception 'NO_GUARD_ENCOUNTER';end if;
  skill:=case choice when '逃跑' then '运动' else choice end;dc:=11+2*p.wanted;
 elsif p_action='prison' then
  if not p.conditions ? 'jailed' then raise exception 'NOT_JAILED';end if;
  skill:=case choice when '游说守卫' then '说服' when '欺骗守卫' then '欺骗' when '寻找钥匙' then '察觉' when '撬锁' then '巧手' when '秘密出口' then '调查' end;dc:=case when choice='秘密出口' then 17 else 15 end;
 elsif p_action='social' then
  if choice is null or choice not in ('说服','欺骗','威吓') then raise exception 'INVALID_SOCIAL';end if;
  skill:=choice;dc:=case area when 'hall' then 19 when 'wonders' then 16 when 'walls' then 17 else 14 end;
 else
  skill:=p_payload->>'skill';dc:=14; -- Free actions are actual field investigations, not configurable reward farming.
 end if;
 r:=public.campaign_v4_check(p.id,skill,dc,case when p_action in ('field','social') then coalesce(p_payload->>'mode','normal') else 'normal' end,0,coalesce((p_payload->>'save')::boolean,false));
 success:=(r->>'success')::boolean;key:=r->>'check_id';
 if success then
  if p_action='crime' then
   if typ in ('pickpocket','theft','lockpick') then
    item:=t->>'item';update public.players set gold=gold+(t->>'gold')::integer,inventory=inventory||to_jsonb(item) where id=p.id;
    log:=(t->>'target')||'：获得 '||(t->>'gold')||' 金币、'||item||'。';
   elsif typ='trespass' then log:='进入隐藏房间，发现：'||(t->>'clue')||'；解锁秘密通路。';
   else
    update public.players set reputation=jsonb_set(reputation,'{underground}',to_jsonb(least(100,coalesce((reputation->>'underground')::integer,0)+4))) where id=p.id;
    log:='破坏监视设施，打开暗路；地下势力声望 +4，守卫声望 -3。';
    update public.players set reputation=jsonb_set(reputation,'{guard}',to_jsonb(greatest(-100,coalesce((reputation->>'guard')::integer,0)-3))) where id=p.id;
   end if;
   if typ in ('lockpick','trespass','vandalism') then
    update public.game_states set state=state||jsonb_build_object('clues',coalesce(state->'clues','[]')||to_jsonb(t->>'clue'),'v41_access',coalesce(state->'v41_access','{}')||jsonb_build_object(area,true)) where room_code=p_code;
    log:=log||' 获得线索：'||(t->>'clue');
    if typ='trespass' then perform public.campaign_v41_inspiration(p.id,'hidden_room:'||area);end if;
   end if;
  elsif p_action in ('guard','prison') then
   update public.players set wanted=case when p_action='prison' and choice in ('寻找钥匙','撬锁','秘密出口') then least(5,wanted+1) else greatest(0,wanted-1) end,conditions=case when p_action='prison' then conditions-'jailed' else conditions end where id=p.id;
   if skill='说服' then
    update public.players set reputation=jsonb_set(reputation,'{guard}',to_jsonb(least(100,coalesce((reputation->>'guard')::integer,0)+2))) where id=p.id;
    log:='守卫接受解释，通缉 -1，守卫声望 +2。';
   elsif skill='欺骗' then
    update public.game_states set state=jsonb_set(state,'{v41_lies}',coalesce(state->'v41_lies','{}')||jsonb_build_object(key,jsonb_build_object('actor',p.id,'chapter',(s->>'chapter')::integer,'exposed',false)),true) where room_code=p_code;
    log:='以伪装蒙混过关，通缉 -1；谎言已记录，推进剧情时可能被揭穿。';
   elsif skill='威吓' then
    update public.players set reputation=jsonb_set(reputation,'{guard}',to_jsonb(greatest(-100,coalesce((reputation->>'guard')::integer,0)-6))) where id=p.id;
    log:='迫使守卫退让，通缉 -1；守卫声望 -6。';
   else log:=case when p_action='prison' then '发现越狱路线并离开监狱，通缉 +1。' else '甩开追兵；本次盘问已避开，通缉 -1。' end;end if;
   if p_action='prison' then log:=log||' 已离开监狱。';end if;
   if choice='秘密出口' then perform public.campaign_v41_inspiration(p.id,'prison_secret');end if;
  elsif p_action='social' then
   if choice='说服' then
    update public.game_states set state=jsonb_set(state,'{v41_discounts}',coalesce(state->'v41_discounts','{}')||jsonb_build_object(p.id::text||':'||area,15),true) where room_code=p_code;
    log:='商人接受互利条件，本区域商品折扣 15%。';
   elsif choice='欺骗' then
    update public.players set inventory=inventory||'"护盾卷轴"'::jsonb where id=p.id;
    update public.game_states set state=state||jsonb_build_object('v41_lies',coalesce(state->'v41_lies','{}')||jsonb_build_object(key,jsonb_build_object('actor',p.id,'chapter',(s->>'chapter')::integer,'exposed',false)),'v41_access',coalesce(state->'v41_access','{}')||jsonb_build_object(area,true)) where room_code=p_code;
    log:='冒充取货代理人，获得护盾卷轴并进入后室；留下待核实的谎言。';
   else
    update public.players set gold=gold+12,reputation=jsonb_set(reputation,'{merchant}',to_jsonb(greatest(-100,coalesce((reputation->>'merchant')::integer,0)-8))) where id=p.id;
    log:='迫使对方交出 12 金币封口费；商人声望 -8。';
   end if;
  else
   log:='发现区域情报：'||area||'·第'||((s->>'chapter')::integer+1)||'章·'||skill||'行动；获得 3 金币调查补助。';
   update public.players set gold=gold+3 where id=p.id;
   update public.game_states set state=jsonb_set(state,'{clues}',coalesce(state->'clues','[]')||to_jsonb(log),true) where room_code=p_code;
  end if;
 else
  log:='检定失败，本次机会已锁定。'||case when (r->>'reroll_used')::boolean then public.campaign_v41_failure(p_code,(select state#>array['checks',key] from public.game_states where room_code=p_code)) else '使用执行者的 1 点 Inspiration 重投一次，或接受后果。' end;
 end if;
 update public.game_states set state=jsonb_set(state,array['checks',key],(state#>array['checks',key])||jsonb_build_object('consequence',log,'risk',coalesce((t->>'risk')::integer,1)),true) where room_code=p_code;
 insert into public.messages(room_code,sender,body,kind) values(p_code,p.name,log,'check');
 return public.party_snapshot(p_code);
end $$;
revoke all on function public.campaign_v41_world(text,text,jsonb) from public,anon,authenticated;

create or replace function public.campaign_v41_merge_checks() returns trigger language plpgsql set search_path=public,pg_temp as $$
declare e record; merged jsonb;
begin
 merged:=coalesce(old.state->'checks','{}')||coalesce(new.state->'checks','{}');
 for e in select key,value from jsonb_each(coalesce(old.state->'checks','{}')) loop
  if coalesce((e.value->>'attempts')::integer,0)>coalesce((merged->e.key->>'attempts')::integer,0)
   or coalesce((e.value->>'resolved')::boolean,false) and not coalesce((merged->e.key->>'resolved')::boolean,false) then merged:=jsonb_set(merged,array[e.key],e.value,true);end if;
 end loop;
 if merged<>'{}'::jsonb then new.state:=jsonb_set(new.state,'{checks}',merged,true);end if;
 return new;
end $$;

create or replace function public.campaign_v41_dispatch(p_code text,p_rpc text,p_action text,p_payload jsonb default '{}',p_retry text default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_code text:=upper(trim(coalesce(p_code,''))); p public.players%rowtype; s jsonb; before_state jsonb; ctx jsonb; r jsonb; e record; k text; scope text:='party'; area text; chapter text; oldrecord jsonb; msg text; item public.campaign_items%rowtype; discounted integer; original_gold integer; method text; n integer;
begin
 if p_rpc='command' and p_action in ('create','join','heartbeat','leave') and p_retry is null then return public.party_command_v41_core(p_code,p_action,p_payload);end if;
 perform public.party_v31_assert_online(v_code);
 perform 1 from public.rooms where rooms.code=v_code for update;
 select * into p from public.players where room_code=v_code and user_id=auth.uid() for update;
 select state into s from public.game_states where room_code=v_code for update;
 before_state:=s;area:=coalesce(s->>'current_area','city');chapter:=coalesce(s->>'chapter','0');
 if p_retry is not null then
  oldrecord:=s#>array['checks',p_retry];
  if oldrecord is null or (oldrecord->>'attempted_by')::bigint<>p.id or coalesce((oldrecord->>'resolved')::boolean,false) or coalesce((oldrecord->>'reroll_used')::boolean,false) then raise exception 'REROLL_UNAVAILABLE';end if;
  if oldrecord->>'chapter'<>chapter or oldrecord->>'area'<>area then raise exception 'CHECK_CONTEXT_CHANGED';end if;
  p_rpc:=oldrecord->>'rpc';p_action:=oldrecord->>'action';p_payload:=oldrecord->'payload';k:=p_retry;scope:=oldrecord->>'scope';
  -- Clear only this failed engine marker; every unrelated flag and check stays intact.
  if p_rpc='command' and p_action='explore' then
   update public.game_states set state=jsonb_set(state,'{explored}',public.campaign_remove_one(coalesce(state->'explored','[]'),chapter||':'||(p_payload->>'index')),true) where room_code=v_code;
  elsif p_rpc='area' and p_action='area_inspect' then
   update public.game_states set state=jsonb_set(state,'{area_inspected}',public.campaign_remove_one(coalesce(state->'area_inspected','[]'),area||':'||(p_payload->>'place')),true) where room_code=v_code;
  elsif p_rpc='deep' and p_action='inspect' then
   update public.game_states set state=state#-array['deep','inspected',chapter] where room_code=v_code;
  elsif p_rpc='deep' and p_action='route' then
   update public.game_states set state=state#-array['deep','route',chapter] where room_code=v_code;
  elsif p_rpc='dialogue' then
   update public.game_states set state=jsonb_set(state,'{v4_dialogue_attempts}',coalesce(state->'v4_dialogue_attempts','{}')-(p.id::text||':'||(p_payload->>'route')),true) where room_code=v_code;
  end if;
 else
  if p_rpc='command' and p_action='roll' then p_rpc:='identity';p_action:='check';end if;
  if p_rpc='identity' and p_action='check' and p_payload->>'skill' in ('说服','欺骗','威吓') and not coalesce((p_payload->>'save')::boolean,false) then p_rpc:='world';p_action:='social';p_payload:=p_payload||jsonb_build_object('choice',p_payload->>'skill');end if;
  if p_rpc='world' then
   if p_action='crime' then k:='crime:'||area||':'||(p_payload->>'type');
   elsif p_action='social' then k:='social:'||area; -- The same negotiation cannot be rerolled by changing social skill.
   elsif p_action='guard' and p_payload->>'choice' in ('说服','欺骗','威吓','逃跑') then k:='guard:'||chapter||':'||p.id;scope:='personal';
   elsif p_action='prison' and p_payload->>'choice' in ('游说守卫','欺骗守卫','寻找钥匙','撬锁','秘密出口') then k:='prison:'||p.id||':'||coalesce(p.conditions->>'prison_visit','0')||':'||(p_payload->>'choice');scope:='personal';end if;
  elsif p_rpc='identity' and p_action='check' then k:='field:'||chapter||':'||area||':'||p.id;scope:='personal';
  elsif p_rpc='dialogue' then k:='identity:'||(p_payload->>'route');
  elsif p_rpc='command' and p_action='explore' then k:='chapter:'||chapter||':explore:'||(p_payload->>'index');
  elsif p_rpc='area' and p_action='area_inspect' then k:='area:'||area||':inspect:'||(p_payload->>'place');
  elsif p_rpc='area' and p_action='area_quest' then k:='quest:'||(p_payload->>'quest')||':'||coalesce(s#>>array['side_quests',p_payload->>'quest','step'],'0')||':'||coalesce(p_payload->>'option','continue');
  elsif p_rpc='deep' and p_action in ('inspect','route') and not (p_action='route' and p_payload->>'choice'='1') then k:='deep:'||chapter||':'||p_action;end if;
  if k is not null and s#>array['checks',k] is not null then raise exception 'CHECK_ALREADY_ATTEMPTED';end if;
  if p_rpc='world' and p_action='crime' and exists(select 1 from jsonb_each(coalesce(s->'v4_crimes','{}')) x where x.key like '%:'||area||':'||(p_payload->>'type')) then raise exception 'CHECK_ALREADY_ATTEMPTED';end if;
  if p_rpc='dialogue' and exists(select 1 from jsonb_each(coalesce(s->'v4_dialogue_attempts','{}')) x where x.key like '%:'||(p_payload->>'route')) then raise exception 'CHECK_ALREADY_ATTEMPTED';end if;
  -- Heartbeats/snapshots do not accept a failure. Any deliberate new action does.
  if p_action not in ('heartbeat','leave','race','ready','build','camp_talk') then
   for e in select key,value from jsonb_each(coalesce(s->'checks','{}')) where not coalesce((value->>'resolved')::boolean,false) loop perform public.campaign_v41_settle(v_code,e.key);end loop;
  end if;
 end if;
 if k is not null and (p.race is null or p.hp<=0) then raise exception 'ACTION_UNAVAILABLE';end if;
 ctx:=jsonb_build_object('check_id',k,'scope',scope,'rpc',p_rpc,'action',p_action,'payload',p_payload,'chapter',chapter,'area',area,'retry',p_retry is not null);
 if p_rpc='world' and p_action='crime' then ctx:=ctx||jsonb_build_object('risk',public.campaign_v41_target(area,p_payload->>'type',chapter::integer)->'risk');end if;
 perform set_config('uc.check_context',case when k is null then '' else ctx::text end,true);
 if p_rpc='world' and k is not null then r:=public.campaign_v41_world(v_code,p_action,p_payload);
 elsif p_rpc='identity' and p_action='check' then r:=public.campaign_v41_world(v_code,'field',p_payload);
 elsif p_rpc='world' and p_action='use_secret' then
  perform public.campaign_v4_assert_free(v_code,false);
  if not p.is_host or chapter='28' or s->'combat' is null or coalesce((s#>>'{combat,hp}')::integer,0)<=0 or coalesce((s#>>'{combat,round}')::integer,1)>1 or s->'combat' ? 'side_quest' then raise exception 'SECRET_ROUTE_UNAVAILABLE';end if;
  select x.key into method from jsonb_each(coalesce(s->'v41_access','{}')) x where x.value='true'::jsonb and not coalesce(s->'v41_access_used','{}') ? x.key order by x.key limit 1;
  if method is null then raise exception 'SECRET_ROUTE_UNAVAILABLE';end if;
  update public.game_states set state=jsonb_set(state,'{combat}','null'::jsonb,true)||jsonb_build_object('v41_access_used',coalesce(state->'v41_access_used','{}')||jsonb_build_object(method,true),'deep',jsonb_set(coalesce(state->'deep','{}')||jsonb_build_object('combat',coalesce(state#>'{deep,combat}','{}')),array['combat',chapter],jsonb_build_object('combat_required',false,'combat_resolved',true,'combat_skipped',true),true)) where room_code=v_code;
  insert into public.messages(room_code,sender,body,kind) values(v_code,p.name,'利用 '||method||' 的秘密通路绕过本场守备冲突；此通路的战斗捷径已消耗。','check');
  r:=public.party_snapshot(v_code);
 elsif p_rpc='world' and p_action='use_key' then
  perform public.campaign_v4_assert_free(v_code,false);
  item.name:=case area when 'kegs' then '酒馆客房钥匙' when 'wonders' then '高堂封存柜钥匙' when 'walls' then '军需仓钥匙' end;
  if item.name is null or not p.inventory ? item.name or coalesce((s#>>array['v41_access',area])::boolean,false) then raise exception 'KEY_UNAVAILABLE';end if;
  update public.players set inventory=public.campaign_remove_one(inventory,item.name) where id=p.id;
  update public.game_states set state=state||jsonb_build_object('v41_access',coalesce(state->'v41_access','{}')||jsonb_build_object(area,true),'clues',coalesce(state->'clues','[]')||to_jsonb(public.campaign_v41_target(area,'trespass',chapter::integer)->>'clue')) where room_code=v_code;
  perform public.campaign_v41_inspiration(p.id,'hidden_room:'||area);
  insert into public.messages(room_code,sender,body,kind) values(v_code,p.name,'使用'||item.name||'打开隐藏房间，获得秘密路线与线索。','check');
  r:=public.party_snapshot(v_code);
 elsif p_rpc='world' then
  r:=public.party_world_v41_core(v_code,p_action,p_payload);
  if p_action='guard' and p_payload->>'choice'='接受逮捕' then update public.players set conditions=jsonb_set(conditions,'{prison_visit}',to_jsonb(coalesce((conditions->>'prison_visit')::integer,0)+1),true) where id=p.id;end if;
 elsif p_rpc='identity' then r:=public.party_identity_v41_core(v_code,p_action,p_payload);
 elsif p_rpc='dialogue' then r:=public.party_dialogue_v41_core(v_code,p_payload->>'route');
 elsif p_rpc='area' then r:=public.party_area_v41_core(v_code,p_action,p_payload);
 elsif p_rpc='deep' then r:=public.party_deep_v41_core(v_code,p_action,p_payload);
 elsif p_rpc='command' then
  if p_action='buy' then
   select * into item from public.campaign_items where name=p_payload->>'item';
   discounted:=coalesce((s#>>array['v41_discounts',p.id::text||':'||area])::integer,0);
   if item.merchant='wonders' and area<>'wonders' then discounted:=0;end if;
   if item.name is not null then
    original_gold:=p.gold;
    n:=case when coalesce(s->'flags','[]') ? ('support_'||chapter||'_stay') then ceil(item.price*.9)::integer else item.price end;
    if coalesce((p.reputation->>'merchant')::integer,0)>=25 or item.merchant='wonders' and coalesce((p.reputation->>'gond')::integer,0)>=25 then n:=n-ceil(item.price*.1)::integer;
    elsif coalesce((p.reputation->>'merchant')::integer,0)<=-25 then n:=n+ceil(item.price*.1)::integer;end if;
    if discounted>0 then n:=least(n,item.price-ceil(item.price*discounted/100.0)::integer);end if;
    if p.gold<n then raise exception 'NOT_ENOUGH_GOLD';end if;
    update public.players set gold=greatest(gold,item.price+ceil(item.price*.1)::integer) where id=p.id;
   end if;
  end if;
  r:=public.party_command_v41_core(v_code,p_action,p_payload);
  if p_action='buy' and original_gold is not null then update public.players set gold=original_gold-n where id=p.id;insert into public.messages(room_code,sender,body,kind) values(v_code,p.name,'实际支付 '||n||' 金币购买 '||item.name||'（已应用剧情、声望或谈判折扣）。','buy');end if;
 else raise exception 'INVALID_CHECK_RPC';end if;
 perform set_config('uc.check_context','',true);
 select state into s from public.game_states where room_code=v_code;
 oldrecord:=s#>array['checks',k];
 if oldrecord is not null then
  if p_rpc not in ('world','identity') then
   select body into msg from public.messages where room_code=v_code and kind<>'inspiration' order by id desc limit 1;
   update public.game_states set state=jsonb_set(state,array['checks',k,'consequence'],to_jsonb(coalesce(msg,'已记录调查结果')),true) where room_code=v_code;
  end if;
  update public.game_states set state=jsonb_set(state,'{last_roll}',state#>array['checks',k,'result'],true) where room_code=v_code;
  if (oldrecord#>>'{result,success}')::boolean then
   if p_rpc='dialogue' then perform public.campaign_v41_inspiration(p.id,'identity:'||(p_payload->>'route'));
   elsif p_rpc='deep' and p_action='inspect' then perform public.campaign_v41_inspiration(p.id,'discovery:'||chapter);
   elsif p_rpc='deep' and p_action='route' and p_payload->>'choice'='2' then perform public.campaign_v41_inspiration(p.id,'class_route:'||chapter);end if;
  end if;
 end if;
 -- Important side-quest rewards belong to each present character and are receipted once.
 for e in select key,value from jsonb_each(coalesce(s->'side_quests','{}')) where value->>'status'='已完成' and coalesce(before_state#>>array['side_quests',key,'status'],'')<>'已完成' loop
  perform public.campaign_v41_inspiration(id,'side_quest:'||e.key) from public.players where room_code=v_code and user_id is not null and is_online;
 end loop;
 if p_rpc='command' and p_action='choice' and chapter::integer in (4,9,14,19,24,29) and coalesce(before_state->>'chosen_chapter','-1')<>chapter and s->>'chosen_chapter'=chapter then perform public.campaign_v41_inspiration(p.id,'story:'||chapter);end if;
 -- Lies are audited on the next chapter transition: this is a lasting cost, not flavour text.
 if p_rpc='command' and p_action='advance' and s->>'chapter'<>chapter then
  for e in select key,value from jsonb_each(coalesce(s->'v41_lies','{}')) where not coalesce((value->>'exposed')::boolean,false) loop
   update public.players set wanted=least(5,wanted+1),reputation=jsonb_set(reputation,'{guard}',to_jsonb(greatest(-100,coalesce((reputation->>'guard')::integer,0)-5))) where id=(e.value->>'actor')::bigint and room_code=v_code;
   update public.game_states set state=jsonb_set(state,array['v41_lies',e.key,'exposed'],'true',true) where room_code=v_code;
   insert into public.messages(room_code,sender,body,kind) values(v_code,'城市守卫','核对原簿后识破谎言：通缉 +1，守卫声望 -5。','check');
  end loop;
 end if;
 if p_action='leave' then return r;end if;
 return public.party_snapshot(v_code);
end $$;
revoke all on function public.campaign_v41_dispatch(text,text,text,jsonb,text) from public,anon,authenticated;

create or replace function public.party_v4_world(p_code text,p_action text,p_payload jsonb default '{}') returns jsonb language sql security definer set search_path=public,pg_temp as $$ select public.campaign_v41_dispatch(p_code,'world',p_action,p_payload) $$;
create or replace function public.party_v4_identity(p_code text,p_action text,p_payload jsonb default '{}') returns jsonb language sql security definer set search_path=public,pg_temp as $$ select public.campaign_v41_dispatch(p_code,'identity',p_action,p_payload) $$;
create or replace function public.party_command(p_code text,p_action text,p_payload jsonb default '{}') returns jsonb language sql security definer set search_path=public,pg_temp as $$ select public.campaign_v41_dispatch(p_code,'command',p_action,p_payload) $$;
create or replace function public.party_area(p_code text,p_action text,p_payload jsonb default '{}') returns jsonb language sql security definer set search_path=public,pg_temp as $$ select public.campaign_v41_dispatch(p_code,'area',p_action,p_payload) $$;
create or replace function public.party_deep(p_code text,p_action text,p_payload jsonb default '{}') returns jsonb language sql security definer set search_path=public,pg_temp as $$ select public.campaign_v41_dispatch(p_code,'deep',p_action,p_payload) $$;
create or replace function public.party_v4_dialogue(p_code text,p_route text) returns jsonb language sql security definer set search_path=public,pg_temp as $$ select public.campaign_v41_dispatch(p_code,'dialogue','route',jsonb_build_object('route',p_route)) $$;
revoke all on function public.party_v4_world(text,text,jsonb),public.party_v4_identity(text,text,jsonb),public.party_command(text,text,jsonb),public.party_area(text,text,jsonb),public.party_deep(text,text,jsonb),public.party_v4_dialogue(text,text) from public,anon,authenticated;
grant execute on function public.party_v4_world(text,text,jsonb),public.party_v4_identity(text,text,jsonb),public.party_command(text,text,jsonb),public.party_area(text,text,jsonb),public.party_deep(text,text,jsonb),public.party_v4_dialogue(text,text) to authenticated;

create or replace function public.party_v41_check(p_code text,p_check text,p_action text) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_code text:=upper(trim(coalesce(p_code,''))); r jsonb; actor bigint;
begin
 perform public.party_v31_assert_online(v_code);
 perform 1 from public.rooms where rooms.code=v_code for update;
 select id into actor from public.players where room_code=v_code and user_id=auth.uid();
 select state#>array['checks',p_check] into r from public.game_states where room_code=v_code for update;
 if r is null or (r->>'attempted_by')::bigint<>actor then raise exception 'CHECK_OWNER_ONLY';end if;
 if p_action='reroll' then return public.campaign_v41_dispatch(v_code,r->>'rpc',r->>'action',r->'payload',p_check);
 elsif p_action='accept' then perform public.campaign_v41_settle(v_code,p_check);return public.party_snapshot(v_code);
 else raise exception 'INVALID_CHECK_ACTION';end if;
end $$;
revoke all on function public.party_v41_check(text,text,text) from public,anon,authenticated;
grant execute on function public.party_v41_check(text,text,text) to authenticated;

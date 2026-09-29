-- v2.2: each owner has three durable room-backed saves; only authenticated owner can checkpoint.
create table if not exists public.save_slots (
 owner_id uuid not null references auth.users(id) on delete cascade,
 slot smallint not null check(slot between 1 and 3),
 room_code text not null unique references public.rooms(code) on delete cascade,
 saved_state jsonb not null default '{}'::jsonb,
 saved_players jsonb not null default '[]'::jsonb,
 saved_at timestamptz,
 play_seconds bigint not null default 0,
 last_active_at timestamptz not null default now(),
 primary key(owner_id,slot)
);
alter table public.save_slots enable row level security;
revoke all on public.save_slots from public,anon,authenticated;

create or replace function public.party_command(p_code text, p_action text, p_payload jsonb default '{}'::jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_code text:=upper(trim(coalesce(p_code,''))); v_uid uuid:=auth.uid(); v_name text; v_class text; v_id bigint; v_host boolean; v_state jsonb; v_players int; v_unready int; v_target bigint; v_roll int; v_bonus int; v_dc int; v_dmg int; v_hp int; v_ac int; v_idx int; v_flags jsonb; v_clues jsonb; v_combat jsonb; v_turn bigint; v_next bigint; v_enemy_hp int; v_log text; v_chars text:='ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; v_rand bytea; v_try int; v_newcode text; v_stats jsonb; v_max int; v_init jsonb; v_ord bigint; v_scene jsonb; v_key text; v_skill text; v_enemy jsonb; v_aid boolean; v_choice jsonb; v_beat jsonb; v_step int; v_dialogue jsonb; v_item public.campaign_items%rowtype; v_old public.campaign_items%rowtype; v_equipped text; v_foe jsonb; v_enemies jsonb; v_result jsonb; v_chapter int; v_price int;
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_action='create' then
  v_name:=left(trim(coalesce(p_payload->>'name','')),32); v_class:=p_payload->>'class';
  if length(v_name)<2 or v_class not in ('战士','游荡者','法师','牧师','游侠','吟游诗人','圣武士') then raise exception 'INVALID_CHARACTER'; end if;
  for v_try in 1..10 loop
   v_rand:=decode(replace(gen_random_uuid()::text,'-',''),'hex'); v_newcode:='';
   for v_idx in 0..4 loop v_newcode:=v_newcode||substr(v_chars,1+get_byte(v_rand,v_idx)%length(v_chars),1); end loop;
   insert into public.rooms(code) values(v_newcode) on conflict do nothing;
   exit when found;
  end loop;
  if v_try=10 and not found then raise exception 'CODE_EXHAUSTED'; end if;
  v_code:=v_newcode;
  perform public.party_character(v_code,v_uid,v_name,v_class,true);
  insert into public.game_states(room_code,state) values(v_code,jsonb_build_object('started',false,'chapter',0,'flags','[]'::jsonb,'clues','[]'::jsonb,'quest','追查消失的议员','completed_quests','[]'::jsonb,'combat',null,'version',1,'ending',null));
  return public.party_snapshot(v_code);
 end if;
 if p_action='join' then
  v_name:=left(trim(coalesce(p_payload->>'name','')),32); v_class:=p_payload->>'class';
  if length(v_name)<2 or v_class not in ('战士','游荡者','法师','牧师','游侠','吟游诗人','圣武士') then raise exception 'INVALID_CHARACTER'; end if;
  perform 1 from public.rooms where code=v_code for update;
  if not found then raise exception 'ROOM_NOT_FOUND'; end if;
  if exists(select 1 from public.game_states where room_code=v_code and (state->>'started')::boolean) and not exists(select 1 from public.save_slots where room_code=v_code) then raise exception 'GAME_STARTED'; end if;
  if exists(select 1 from public.players where room_code=v_code and user_id=v_uid) then return public.party_snapshot(v_code); end if;
  select count(*) into v_players from public.players where room_code=v_code and user_id is not null;
  if v_players>=5 then raise exception 'ROOM_FULL'; end if;
  perform public.party_character(v_code,v_uid,v_name,v_class,false);
  return public.party_snapshot(v_code);
 end if;
 perform 1 from public.rooms where code=v_code for update;
 if not found then raise exception 'ROOM_NOT_FOUND'; end if;
 select id,name,is_host,hp,ac into v_id,v_name,v_host,v_hp,v_ac from public.players where room_code=v_code and user_id=v_uid;
 if v_id is null then raise exception 'NOT_MEMBER'; end if;
 select state into v_state from public.game_states where room_code=v_code for update;
 if p_action='heartbeat' then
  update public.players set last_seen=now() where id=v_id;
  update public.save_slots set play_seconds=play_seconds+least(60,greatest(0,extract(epoch from now()-last_active_at)::integer)),last_active_at=now() where room_code=v_code and owner_id=v_uid;
  return public.party_snapshot(v_code);
 end if;
 if p_action='leave' then
  if exists(select 1 from public.save_slots where room_code=v_code) then update public.players set last_seen=now()-interval '6 minutes',is_ready=false where id=v_id; return jsonb_build_object('left',true); end if;
  delete from public.players where id=v_id;
  if v_host then update public.players set is_host=true,is_ready=false where id=(select id from public.players where room_code=v_code and user_id is not null order by created_at,id limit 1); end if;
  return jsonb_build_object('left',true);
 end if;
 if p_action='claim_host' then
  if exists(select 1 from public.save_slots where room_code=v_code) then raise exception 'SAVE_OWNER_ONLY'; end if;
  if not exists(select 1 from public.players where room_code=v_code and is_host and user_id is not null and last_seen>now()-interval '5 minutes') then
   update public.players set is_host=false where room_code=v_code;
   update public.players set is_host=true where id=(select id from public.players where room_code=v_code and user_id is not null order by created_at,id limit 1);
  end if;
  return public.party_snapshot(v_code);
 end if;
 if p_action='ready' then
  if (v_state->>'started')::boolean then raise exception 'ALREADY_STARTED'; end if;
  update public.players set is_ready=not is_ready where id=v_id;
 elsif p_action='start' then
  if not v_host then raise exception 'HOST_ONLY'; end if;
  select count(*),count(*) filter(where not is_ready) into v_players,v_unready from public.players where room_code=v_code and user_id is not null;
  if v_players<(case when exists(select 1 from public.save_slots where room_code=v_code) then 1 else 2 end) or v_players>5 or v_unready>0 then raise exception 'PARTY_NOT_READY'; end if;
  v_state:=jsonb_set(v_state,'{started}','true'::jsonb);
  v_log:='冒险开始。';
 elsif p_action='chat' then
  v_log:=left(trim(coalesce(p_payload->>'body','')),500);
  if length(v_log)<1 then raise exception 'EMPTY_MESSAGE'; end if;
 elsif p_action='roll' then
  if not (v_state->>'started')::boolean then raise exception 'NOT_STARTED'; end if;
  -- The browser chooses a skill and DC; the modifier comes from the authenticated character.
  if p_payload->>'skill' not in ('调查','洞悉','说服','潜行','运动','奥秘','求生') then raise exception 'INVALID_SKILL'; end if;
  select floor(((stats->>case p_payload->>'skill' when '运动' then 0 when '潜行' then 1 when '调查' then 3 when '奥秘' then 3 when '洞悉' then 4 when '求生' then 4 else 5 end)::int-10)/2.0)::int
    + case when (class_name='战士' and p_payload->>'skill'='运动') or (class_name='游荡者' and p_payload->>'skill' in ('调查','潜行')) or (class_name='法师' and p_payload->>'skill'='奥秘') or (class_name='牧师' and p_payload->>'skill'='洞悉') or (class_name='游侠' and p_payload->>'skill'='求生') or (class_name='吟游诗人' and p_payload->>'skill'='说服') or (class_name='圣武士' and p_payload->>'skill' in ('运动','说服')) then 2 else 0 end into v_bonus from public.players where id=v_id;
  v_dc:=greatest(5,least(30,coalesce((p_payload->>'dc')::int,15)));
  v_roll:=floor(random()*20)::int+1;
  v_log:=left(coalesce(p_payload->>'skill','技能'),30)||'检定 D20='||v_roll||'，加值 '||v_bonus||'，DC '||v_dc||'：'||case when v_roll=20 then '大成功' when v_roll=1 then '大失败' when v_roll+v_bonus>=v_dc then '成功' else '失败' end;
 elsif p_action='dialogue' then
  if not (v_state->>'started')::boolean then raise exception 'NOT_STARTED'; end if;
  v_chapter:=(v_state->>'chapter')::int;
  v_step:=case when (v_state#>>'{dialogue,chapter}')::int=v_chapter then coalesce((v_state#>>'{dialogue,step}')::int,0) else 0 end;
  select beats->v_step into v_beat from public.campaign_dialogues where chapter_id=v_chapter;
  if v_beat is null then raise exception 'DIALOGUE_COMPLETE'; end if;
  v_idx:=coalesce((p_payload->>'choice')::int,-1);
  if v_idx not in (0,1) then raise exception 'INVALID_DIALOGUE_CHOICE'; end if;
  v_choice:=v_beat->'options'->v_idx;
  v_flags:=coalesce(v_state->'flags','[]'::jsonb);
  if not v_flags ? (v_choice->>'flag') then v_flags:=v_flags||to_jsonb(v_choice->>'flag'); end if;
  v_state:=jsonb_set(v_state,'{flags}',v_flags);
  v_dialogue:=case when v_step=0 then jsonb_build_object('chapter',v_chapter,'step',1,'history',jsonb_build_array(jsonb_build_object('choice',v_choice->>'label','reply',v_choice->>'reply'))) else jsonb_set(jsonb_set(v_state->'dialogue','{step}',to_jsonb(v_step+1)),'{history}',coalesce(v_state#>'{dialogue,history}','[]'::jsonb)||jsonb_build_array(jsonb_build_object('choice',v_choice->>'label','reply',v_choice->>'reply'))) end;
  v_state:=jsonb_set(v_state,'{dialogue}',v_dialogue);
  v_log:=(v_choice->>'label')||' — '||(v_choice->>'reply');
 elsif p_action='explore' then
  if coalesce((v_state#>>'{dialogue,chapter}')::int,-1)<>(v_state->>'chapter')::int or coalesce((v_state#>>'{dialogue,step}')::int,0)<3 then raise exception 'DIALOGUE_FIRST'; end if;
  if not (v_state->>'started')::boolean then raise exception 'NOT_STARTED'; end if;
  v_idx:=coalesce((p_payload->>'index')::int,-1);
  if v_idx<0 or v_idx>1 then raise exception 'INVALID_ENCOUNTER'; end if;
  v_key:=(v_state->>'chapter')||':'||v_idx;
  if coalesce(v_state->'explored','[]'::jsonb) ? v_key then raise exception 'ALREADY_EXPLORED'; end if;
  select scenes->v_idx into v_scene from public.campaign_chapters where id=(v_state->>'chapter')::int;
  if v_scene is null then raise exception 'ENCOUNTER_UNAVAILABLE'; end if;
  v_skill:=v_scene->>'skill'; v_dc:=(v_scene->>'dc')::int;
  select floor(((stats->>case v_skill when '运动' then 0 when '潜行' then 1 when '调查' then 3 when '奥秘' then 3 when '洞悉' then 4 when '求生' then 4 else 5 end)::int-10)/2.0)::int
   + case when (class_name='战士' and v_skill='运动') or (class_name='游荡者' and v_skill in ('调查','潜行')) or (class_name='法师' and v_skill='奥秘') or (class_name='牧师' and v_skill='洞悉') or (class_name='游侠' and v_skill='求生') or (class_name='吟游诗人' and v_skill='说服') or (class_name='圣武士' and v_skill in ('运动','说服')) then 2 else 0 end into v_bonus from public.players where id=v_id;
  v_roll:=floor(random()*20)::int+1;
  v_state:=jsonb_set(v_state,'{explored}',coalesce(v_state->'explored','[]'::jsonb)||to_jsonb(v_key));
  if v_roll=20 or (v_roll<>1 and v_roll+v_bonus>=v_dc) then
   v_clues:=coalesce(v_state->'clues','[]'::jsonb); v_flags:=coalesce(v_state->'flags','[]'::jsonb);
   if not v_clues ? (v_scene->>'clue') then v_clues:=v_clues||to_jsonb(v_scene->>'clue'); end if;
   if not v_flags ? (v_scene->>'flag') then v_flags:=v_flags||to_jsonb(v_scene->>'flag'); end if;
   v_state:=jsonb_set(jsonb_set(v_state,'{clues}',v_clues),'{flags}',v_flags);
   v_log:=v_scene->>'success';
  else v_log:=v_scene->>'failure'; end if;
  v_state:=jsonb_set(v_state,'{exploration_history}',coalesce(v_state->'exploration_history','[]'::jsonb)||jsonb_build_array(jsonb_build_object('chapter',(v_state->>'chapter')::int,'label',v_scene->>'label','result',v_log,'clue',case when v_roll=20 or (v_roll<>1 and v_roll+v_bonus>=v_dc) then v_scene->>'clue' else null end)));
  v_log:=(v_scene->>'label')||' · '||v_skill||' D20='||v_roll||'+'||v_bonus||' / DC '||v_dc||case when v_roll=20 then ' 大成功' when v_roll=1 then ' 大失败' else '' end||'：'||v_log;
 elsif p_action='choice' then
  if not (v_state->>'started')::boolean then raise exception 'NOT_STARTED'; end if;
  if coalesce((v_state->>'chosen_chapter')::int,-1)=(v_state->>'chapter')::int then raise exception 'CHOICE_ALREADY_MADE'; end if;
  if not (coalesce(v_state->'explored','[]'::jsonb) ? ((v_state->>'chapter')||':0')) or not (coalesce(v_state->'explored','[]'::jsonb) ? ((v_state->>'chapter')||':1')) then raise exception 'EXPLORE_BEFORE_CHOICE'; end if;
  v_idx:=coalesce((p_payload->>'index')::int,-1);
  if v_idx<0 or v_idx>1 then raise exception 'INVALID_CHOICE'; end if;
  select choices->v_idx into p_payload from public.campaign_chapters where id=(v_state->>'chapter')::int;
  if p_payload is null then raise exception 'INVALID_CHOICE'; end if;
  v_flags:=coalesce(v_state->'flags','[]'::jsonb); v_clues:=coalesce(v_state->'clues','[]'::jsonb);
  if length(coalesce(p_payload->>'flag',''))>0 and not v_flags ? (p_payload->>'flag') then v_flags:=v_flags||to_jsonb(left(p_payload->>'flag',40)); end if;
  if length(coalesce(p_payload->>'clue',''))>0 and not v_clues ? (p_payload->>'clue') then v_clues:=v_clues||to_jsonb(left(p_payload->>'clue',60)); end if;
  v_state:=jsonb_set(jsonb_set(v_state,'{flags}',v_flags),'{clues}',v_clues);
  v_state:=jsonb_set(v_state,'{chosen_chapter}',to_jsonb((v_state->>'chapter')::int));
  if (v_state->>'chapter')::int=29 then v_state:=jsonb_set(v_state,'{ending}',to_jsonb(case when (v_state->'flags') ? 'council' then '公民议会重建' when (v_state->'flags') ? 'autonomy' then '地下自治联盟' when (select count(*) from jsonb_array_elements_text(v_state->'flags') f where f not like 'voice_%' and f not like 'approach_%' and f not like 'support_%')>=18 then '城市共同体' else '艰难的黎明' end)); end if;
  v_log:='选择：'||left(coalesce(p_payload->>'label',''),80);
 elsif p_action='advance' then
  if not v_host then raise exception 'HOST_ONLY'; end if;
  if not (v_state->>'started')::boolean then raise exception 'NOT_STARTED'; end if;
  if (v_state->>'chapter')::int>=29 then raise exception 'CAMPAIGN_COMPLETE'; end if;
  if coalesce((v_state->>'chosen_chapter')::int,-1)<>coalesce((v_state->>'chapter')::int,0) then raise exception 'CHOOSE_BEFORE_ADVANCE'; end if;
  if v_state->'combat' is not null and v_state->'combat'<>'null'::jsonb and coalesce((v_state#>>'{combat,hp}')::int,0)>0 then raise exception 'COMBAT_ACTIVE'; end if;
  v_idx:=least(29,coalesce((v_state->>'chapter')::int,0)+1);
  v_state:=jsonb_set(jsonb_set(v_state,'{chapter}',to_jsonb(v_idx)),'{completed_quests}',coalesce(v_state->'completed_quests','[]'::jsonb)||to_jsonb(v_idx-1));
  -- Story milestones grant levels and spell circles to every member atomically.
  update public.players set max_hp=max_hp+(public.campaign_level(v_idx)-level)*case class_name when '战士' then 6 when '圣武士' then 6 when '法师' then 4 else 5 end,
    hp=hp+(public.campaign_level(v_idx)-level)*case class_name when '战士' then 6 when '圣武士' then 6 when '法师' then 4 else 5 end,
    level=public.campaign_level(v_idx),spell_slots=public.campaign_slots(public.campaign_level(v_idx)),ability_charges=2
    where room_code=v_code and (user_id is not null or is_companion) and level<public.campaign_level(v_idx);
  -- A completed fight grants a camp rest before the next scene. Downed allies need healing first.
  if coalesce((v_state#>>'{combat,hp}')::int,-1)=0 then
   update public.players set hp=max_hp,spell_slots=public.campaign_slots(level),ability_charges=2 where room_code=v_code and (user_id is not null or is_companion) and hp>0;
  end if;
  select details into v_enemy from public.campaign_battles where chapter_id=v_idx;
  if v_enemy is not null then
   select count(*) into v_players from public.players where room_code=v_code and user_id is not null;
   v_aid:=coalesce(v_state->'flags','[]'::jsonb) ? (v_enemy->>'aid');
   v_enemy_hp:=(v_enemy->>'hp')::int+greatest(0,v_players-2)*7-case when v_aid then 5 else 0 end;
   select jsonb_agg(jsonb_build_object('id',id,'roll',roll) order by roll desc,id),(array_agg(id order by roll desc,id))[1] into v_init,v_turn from (select id,floor(random()*20)::int+1 as roll from public.players where room_code=v_code and (user_id is not null or is_companion) and hp>0) i;
   v_enemies:='[]'::jsonb;
   for v_foe in select value from jsonb_array_elements(coalesce(v_enemy->'foes',jsonb_build_array(v_enemy))) loop
     v_enemy_hp:=(v_foe->>'hp')::int+greatest(0,v_players-2)*6-case when v_aid then 3 else 0 end;
     v_enemies:=v_enemies||jsonb_build_array(jsonb_build_object('name',v_foe->>'name','hp',v_enemy_hp,'max_hp',v_enemy_hp,'ac',(v_foe->>'ac')::int-case when v_aid then 1 else 0 end,'attack_bonus',(v_foe->>'attack')::int,'damage_min',(v_foe->>'min')::int,'damage_die',(v_foe->>'die')::int));
   end loop;
   v_state:=jsonb_set(v_state,'{combat}',jsonb_build_object('name',v_enemy->>'name','enemies',v_enemies,'hp',public.campaign_enemy_hp(v_enemies),'max_hp',public.campaign_enemy_hp(v_enemies),'turn',v_turn,'initiative',v_init,'round',1,'wards','{}'::jsonb));
  else v_state:=jsonb_set(v_state,'{combat}','null'::jsonb); end if;
  if v_idx=10 then v_log:='新区域已解锁：至高大厅。'; elsif v_idx=15 then v_log:='新区域已解锁：上城区城墙。'; end if;
  if v_idx%5=0 then update public.players set gold=gold+10 where room_code=v_code and user_id is not null; end if;
  v_log:=coalesce(v_log,'')||' 推进至第 '||(v_idx+1)||' 章。'||case when v_idx%5=0 then ' 队员各获 10 金币。' else '' end||case when v_enemy is not null then ' 遭遇：'||(v_enemy->>'name')||'。'||case when v_aid then v_enemy->>'aidText' else '' end else '' end;
 elsif p_action='retry' then
  if not v_host then raise exception 'HOST_ONLY'; end if;
  v_combat:=v_state->'combat';
  if v_combat is null or v_combat='null'::jsonb or coalesce((v_combat->>'hp')::int,0)<=0 or v_combat->>'turn' is not null then raise exception 'NOT_DEFEATED'; end if;
  if exists(select 1 from public.players where room_code=v_code and (user_id is not null or is_companion) and hp>0) then raise exception 'PARTY_STILL_STANDING'; end if;
  update public.players set hp=greatest(1,ceil(max_hp/2.0)::int),death_failures=0,death_successes=0,
    spell_slots=public.campaign_slots(level),ability_charges=2,gold=greatest(0,gold-10)
    where room_code=v_code and (user_id is not null or is_companion);
  select jsonb_agg(jsonb_set(e.value,'{hp}',e.value->'max_hp') order by e.ord) into v_enemies
    from jsonb_array_elements(v_combat->'enemies') with ordinality e(value,ord);
  v_combat:=jsonb_set(jsonb_set(v_combat,'{enemies}',v_enemies),'{hp}',to_jsonb(public.campaign_enemy_hp(v_enemies)));
  select jsonb_agg(jsonb_build_object('id',id,'roll',roll) order by roll desc,id),(array_agg(id order by roll desc,id))[1]
    into v_init,v_turn from (select id,floor(random()*20)::int+1 as roll from public.players where room_code=v_code and (user_id is not null or is_companion) and hp>0) i;
  v_combat:=jsonb_set(jsonb_set(jsonb_set(v_combat,'{initiative}',v_init),'{turn}',to_jsonb(v_turn)),'{round}','1'::jsonb);
  v_state:=jsonb_set(v_state,'{combat}',v_combat);
  v_log:='队伍败退并重整：全员恢复半数生命与战斗资源，每名玩家最多损失 10 金币；本场战斗重新开始。';
 elsif p_action='attack' then
  v_combat:=v_state->'combat';
  if v_combat is null or v_combat='null'::jsonb or (v_combat->>'hp')::int<=0 then raise exception 'NO_COMBAT'; end if;
  if (v_combat->>'turn')::bigint<>v_id then raise exception 'NOT_YOUR_TURN'; end if;
  if v_hp<=0 then raise exception 'DOWNED'; end if;
  v_idx:=coalesce((p_payload->>'enemy')::int,-1);
  if v_idx<0 or v_idx>=jsonb_array_length(v_combat->'enemies') then raise exception 'INVALID_ENEMY'; end if;
  v_foe:=v_combat->'enemies'->v_idx;
  if (v_foe->>'hp')::int<=0 then raise exception 'ENEMY_DOWN'; end if;
  select case class_name when '战士' then 5 when '游荡者' then 5 when '法师' then 5 when '游侠' then 5 when '圣武士' then 5 else 4 end+(level-1)/4 into v_bonus from public.players where id=v_id;
  select coalesce(max(i.attack),0),coalesce(max(i.damage),0) into v_dc,v_max from public.players p cross join lateral jsonb_array_elements_text(p.equipment) e(name) join public.campaign_items i on i.name=e.name and i.slot='weapon' where p.id=v_id;
  v_bonus:=v_bonus+v_dc;
  v_roll:=floor(random()*20)::int+1;
  v_dmg:=case when v_roll=1 or (v_roll<>20 and v_roll+v_bonus<(v_foe->>'ac')::int) then 0 else floor(random()*8)::int+1+v_bonus+v_max+case when v_roll=20 then floor(random()*8)::int+1 else 0 end end;
  v_enemy_hp:=greatest(0,(v_foe->>'hp')::int-v_dmg);
  v_combat:=jsonb_set(v_combat,array['enemies',v_idx::text,'hp'],to_jsonb(v_enemy_hp));
  v_combat:=jsonb_set(v_combat,'{hp}',to_jsonb(public.campaign_enemy_hp(v_combat->'enemies')));
  v_log:='攻击 '||(v_foe->>'name')||' D20='||v_roll||case when v_roll=20 then ' 大成功' when v_roll=1 then ' 大失败' else '' end||'，伤害 '||v_dmg;
  v_result:=public.campaign_finish_turn(v_code,v_combat,v_id);
  v_state:=jsonb_set(v_state,'{combat}',v_result->'combat');
  v_log:=v_log||coalesce(v_result->>'log','');
 elsif p_action='heal' then
  if not (v_state->>'started')::boolean then raise exception 'NOT_STARTED'; end if;
  v_target:=coalesce((p_payload->>'target')::bigint,v_id);
  if not exists(select 1 from public.players where id=v_target and room_code=v_code and (user_id is not null or is_companion)) then raise exception 'INVALID_TARGET'; end if;
  if not (select inventory ? '治疗药水' from public.players where id=v_id) then raise exception 'NO_POTION'; end if;
  update public.players set inventory=public.campaign_remove_one(inventory,'治疗药水') where id=v_id;
  update public.players set hp=least(max_hp,hp+8),death_failures=0,death_successes=0 where id=v_target and hp>=0;
  if v_state->'combat' is not null and v_state->'combat'<>'null'::jsonb and v_state#>'{combat,turn}'='null'::jsonb then v_state:=jsonb_set(v_state,'{combat,turn}',to_jsonb(v_target)); end if;
  v_log:='使用治疗药水，恢复 8 HP。';
 elsif p_action='buy' then
  if not (v_state->>'started')::boolean then raise exception 'NOT_STARTED'; end if;
  if coalesce((v_state#>>'{combat,hp}')::int,0)>0 then raise exception 'COMBAT_ACTIVE'; end if;
  select * into v_item from public.campaign_items where name=p_payload->>'item' and unlock_chapter<=(v_state->>'chapter')::int;
  if not found then raise exception 'ITEM_LOCKED'; end if;
  if v_item.slot<>'consumable' and (select inventory ? v_item.name or equipment ? v_item.name from public.players where id=v_id) then raise exception 'ALREADY_OWNED'; end if;
  v_price:=case when coalesce(v_state->'flags','[]'::jsonb) ? ('support_'||(v_state->>'chapter')||'_stay') then ceil(v_item.price*0.9)::int else v_item.price end;
  update public.players set gold=gold-v_price,inventory=inventory||to_jsonb(v_item.name) where id=v_id and gold>=v_price;
  if not found then raise exception 'NOT_ENOUGH_GOLD'; end if;
  v_log:='从'||v_item.merchant||'购买'||v_item.name||'，花费 '||v_price||' 金币。';
 elsif p_action='equip' then
  if coalesce((v_state#>>'{combat,hp}')::int,0)>0 then raise exception 'COMBAT_ACTIVE'; end if;
  select * into v_item from public.campaign_items where name=p_payload->>'item' and slot<>'consumable';
  if not found or not (select inventory ? v_item.name from public.players where id=v_id) then raise exception 'ITEM_NOT_IN_BAG'; end if;
  select e.name into v_equipped from public.players p cross join lateral jsonb_array_elements_text(p.equipment) e(name) left join public.campaign_items old_item on old_item.name=e.name where p.id=v_id and (old_item.slot=v_item.slot or (e.name='基础武器' and v_item.slot='weapon')) limit 1;
  select * into v_old from public.campaign_items where name=v_equipped;
  update public.players set inventory=(inventory-v_item.name)||case when v_equipped is not null and v_equipped<>'基础武器' then to_jsonb(v_equipped) else '[]'::jsonb end,
    equipment=(equipment-coalesce(v_equipped,''))||to_jsonb(v_item.name),ac=ac-coalesce(v_old.ac,0)+v_item.ac where id=v_id;
  v_log:='装备'||v_item.name||case when v_item.ac>0 then '，AC +'||v_item.ac else '，攻击 +'||v_item.attack||'、伤害 +'||v_item.damage end;
 elsif p_action='death_save' then
  if v_hp<>0 then raise exception 'NOT_DOWNED'; end if;
  v_roll:=floor(random()*20)::int+1;
  if v_roll=20 then update public.players set hp=1,death_failures=0,death_successes=0 where id=v_id;
   if v_state->'combat' is not null and v_state->'combat'<>'null'::jsonb and v_state#>'{combat,turn}'='null'::jsonb and exists(select 1 from public.players where room_code=v_code and hp>0 and id<>v_id) then v_state:=jsonb_set(v_state,'{combat,turn}',to_jsonb(v_id)); end if;
  elsif v_roll=1 then update public.players set death_failures=least(3,death_failures+2) where id=v_id;
  elsif v_roll>=10 then update public.players set death_successes=least(3,death_successes+1) where id=v_id;
  else update public.players set death_failures=least(3,death_failures+1) where id=v_id; end if;
  v_log:='死亡豁免 D20='||v_roll||case when v_roll=20 then '，恢复 1 HP' else '' end;
 else raise exception 'UNKNOWN_ACTION'; end if;
 update public.game_states set state=jsonb_set(v_state,'{version}',to_jsonb(coalesce((v_state->>'version')::int,0)+1)),updated_at=now() where room_code=v_code;
 if v_log is not null then insert into public.messages(room_code,sender,body,kind) values(v_code,v_name,v_log,p_action); end if;
 return public.party_snapshot(v_code);
end $$;

create or replace function public.party_save_slot(p_action text,p_slot integer default null,p_room text default null,p_name text default null,p_class text default null)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_uid uuid:=auth.uid(); v_code text; v_data jsonb; v_record public.save_slots%rowtype;
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_action='list' then
  return coalesce((select jsonb_agg(jsonb_build_object('slot',s.slot,'room',s.room_code,'saved_at',s.saved_at,'play_seconds',s.play_seconds,'chapter',coalesce((g.state->>'chapter')::int,0),'area',coalesce((select a.name from public.uc_areas a where a.id=g.state->>'current_area'),'上城区'),'name',p.name,'class_name',p.class_name,'level',p.level) order by s.slot)
   from public.save_slots s join public.game_states g on g.room_code=s.room_code join public.players p on p.room_code=s.room_code and p.user_id=v_uid where s.owner_id=v_uid and p.is_companion=false),'[]'::jsonb);
 end if;
 if p_slot not between 1 and 3 then raise exception 'INVALID_SLOT'; end if;
 -- Serialize each owner's operations so concurrent tabs cannot allocate one slot twice.
 perform pg_advisory_xact_lock(hashtextextended(v_uid::text,22));
 select * into v_record from public.save_slots where owner_id=v_uid and slot=p_slot for update;
 if p_action='create' then
  if found then raise exception 'SLOT_OCCUPIED'; end if;
  v_data:=public.party_command('','create',jsonb_build_object('name',p_name,'class',p_class));
  v_code:=v_data->>'room';
  insert into public.save_slots(owner_id,slot,room_code,saved_state,saved_players,saved_at)
   select v_uid,p_slot,v_code,g.state,coalesce((select jsonb_agg(to_jsonb(p)) from public.players p where p.room_code=v_code),'[]'::jsonb),now() from public.game_states g where g.room_code=v_code;
  return v_data;
 end if;
 if p_action='adopt' then
  if found then raise exception 'SLOT_OCCUPIED'; end if;
  v_code:=upper(trim(coalesce(p_room,'')));
  if exists(select 1 from public.save_slots where room_code=v_code) then raise exception 'ROOM_ALREADY_SAVED'; end if;
  if not exists(select 1 from public.players where room_code=v_code and user_id=v_uid and is_host and not is_companion) then raise exception 'HOST_ONLY'; end if;
  insert into public.save_slots(owner_id,slot,room_code,saved_state,saved_players,saved_at)
   select v_uid,p_slot,v_code,g.state,coalesce((select jsonb_agg(to_jsonb(p)) from public.players p where p.room_code=v_code),'[]'::jsonb),now() from public.game_states g where g.room_code=v_code;
  return public.party_snapshot(v_code);
 end if;
 if not found then raise exception 'EMPTY_SLOT'; end if;
 v_code:=v_record.room_code;
 perform 1 from public.rooms where code=v_code for update;
 if not exists(select 1 from public.players where room_code=v_code and user_id=v_uid and not is_companion) then raise exception 'OWNER_CHARACTER_MISSING'; end if;
 if p_action='enter' then
  update public.players set is_host=(user_id=v_uid),last_seen=case when user_id=v_uid then now() else last_seen end where room_code=v_code and not is_companion;
  update public.save_slots set last_active_at=now() where owner_id=v_uid and slot=p_slot;
  return public.party_snapshot(v_code);
 end if;
 if p_action='save' then
  -- Locking the room serializes this checkpoint against all gameplay commands.
  update public.save_slots set saved_state=g.state,
   saved_players=coalesce((select jsonb_agg(to_jsonb(p)) from public.players p where p.room_code=v_code),'[]'::jsonb),
   saved_at=now(),play_seconds=play_seconds+least(60,greatest(0,extract(epoch from now()-last_active_at)::integer)),last_active_at=now()
   from public.game_states g where owner_id=v_uid and slot=p_slot and g.room_code=v_code;
  return jsonb_build_object('saved_at',(select saved_at from public.save_slots where owner_id=v_uid and slot=p_slot),'room',v_code);
 end if;
 raise exception 'UNKNOWN_SLOT_ACTION';
end $$;
revoke all on function public.party_save_slot(text,integer,text,text,text),public.party_command(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.party_save_slot(text,integer,text,text,text),public.party_command(text,text,jsonb) to authenticated;

create or replace function public.party_region(p_code text,p_area text) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_code text:=upper(trim(coalesce(p_code,''))); v_state jsonb; v_unlock integer;
begin
 if auth.uid() is null or not exists(select 1 from public.players where room_code=v_code and user_id=auth.uid() and not is_companion) then raise exception 'NOT_MEMBER'; end if;
 perform 1 from public.rooms where code=v_code for update;
 if not found then raise exception 'ROOM_NOT_FOUND'; end if;
 select state into v_state from public.game_states where room_code=v_code for update;
 if p_area<>'city' then
  select unlock_chapter into v_unlock from public.uc_areas where id=p_area;
  if v_unlock is null or coalesce((v_state->>'chapter')::integer,0)<v_unlock then raise exception 'AREA_LOCKED'; end if;
 end if;
 update public.game_states set state=jsonb_set(v_state,'{current_area}',to_jsonb(p_area)),updated_at=now() where room_code=v_code;
 return public.party_snapshot(v_code);
end $$;
revoke all on function public.party_region(text,text) from public,anon,authenticated;
grant execute on function public.party_region(text,text) to authenticated;

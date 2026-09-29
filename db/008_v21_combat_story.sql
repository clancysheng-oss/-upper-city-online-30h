-- Upper City 2.1: shared combat resolution, wipe recovery and authored chapter dialogue.
create or replace function public.campaign_finish_turn(p_code text,p_combat jsonb,p_actor bigint) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_combat jsonb:=p_combat; v_ord bigint; v_next bigint; v_foe jsonb; v_target public.players%rowtype; v_roll int; v_dmg int; v_log text:=''; v_ward int;
begin
 if public.campaign_enemy_hp(v_combat->'enemies')=0 then
   update public.players set gold=gold+12+coalesce((select (state->>'chapter')::int/5 from public.game_states where room_code=p_code),0)*3 where room_code=p_code and user_id is not null;
   return jsonb_build_object('combat',v_combat,'log','；敌方全灭，队员获得战利品金币');
 end if;
 select ord into v_ord from jsonb_array_elements(v_combat->'initiative') with ordinality e(item,ord) where (item->>'id')::bigint=p_actor;
 select p.id into v_next from jsonb_array_elements(v_combat->'initiative') with ordinality e(item,ord) join public.players p on p.id=(item->>'id')::bigint where e.ord>v_ord and p.hp>0 and p.death_failures<3 order by e.ord limit 1;
 if v_next is null then
   for v_foe in select value from jsonb_array_elements(v_combat->'enemies') where (value->>'hp')::int>0 loop
     select * into v_target from public.players where room_code=p_code and (user_id is not null or is_companion) and hp>0 and death_failures<3 order by case when (v_foe->>'special') like '齐射%' then ac else floor(random()*20)::int end limit 1;
     exit when not found;
     v_roll:=floor(random()*20)::int+1;
     v_ward:=coalesce((v_combat->'wards'->>v_target.id::text)::int,0);
     if v_roll=20 or (v_roll<>1 and v_roll+(v_foe->>'attack_bonus')::int>=v_target.ac+v_ward) then
       v_dmg:=floor(random()*(v_foe->>'damage_die')::int)::int+(v_foe->>'damage_min')::int+case when (v_foe->>'special') like '火油%' or (v_foe->>'special') like '投火%' then 2 else 0 end;
       update public.players set hp=greatest(0,hp-v_dmg) where id=v_target.id;
       v_log:=v_log||'；'||(v_foe->>'name')||case when v_foe ? 'special' then '〔'||(v_foe->>'special')||'〕' else '' end||'攻击'||v_target.name||'，伤害 '||v_dmg;
     else v_log:=v_log||'；'||(v_foe->>'name')||'未命中'; end if;
     v_combat:=jsonb_set(v_combat,'{wards}',coalesce(v_combat->'wards','{}'::jsonb)-v_target.id::text);
   end loop;
   select p.id into v_next from jsonb_array_elements(v_combat->'initiative') with ordinality e(item,ord) join public.players p on p.id=(item->>'id')::bigint where p.hp>0 and p.death_failures<3 order by e.ord limit 1;
   v_combat:=jsonb_set(v_combat,'{round}',to_jsonb((v_combat->>'round')::int+1));
 end if;
 v_combat:=jsonb_set(v_combat,'{turn}',coalesce(to_jsonb(v_next),'null'::jsonb));
 if v_next is null then v_log:=v_log||'；队伍全员倒地。房主可以重整队伍并重试本场战斗'; end if;
 return jsonb_build_object('combat',v_combat,'log',v_log);
end $$;
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
  if exists(select 1 from public.game_states where room_code=v_code and (state->>'started')::boolean) then raise exception 'GAME_STARTED'; end if;
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
 if p_action='heartbeat' then update public.players set last_seen=now() where id=v_id; return public.party_snapshot(v_code); end if;
 if p_action='leave' then
  delete from public.players where id=v_id;
  if v_host then update public.players set is_host=true,is_ready=false where id=(select id from public.players where room_code=v_code and user_id is not null order by created_at,id limit 1); end if;
  return jsonb_build_object('left',true);
 end if;
 if p_action='claim_host' then
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
  if v_players<2 or v_players>5 or v_unready>0 then raise exception 'PARTY_NOT_READY'; end if;
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
create or replace function public.party_power(p_code text,p_id text,p_target bigint default null,p_slot integer default 0)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_code text:=upper(trim(coalesce(p_code,''))); v_uid uuid:=auth.uid(); v_actor public.players%rowtype; v_target public.players%rowtype;
 v_state jsonb; v_combat jsonb; v_power public.campaign_powers%rowtype; v_slots jsonb; v_slot integer:=coalesce(p_slot,0); v_roll integer; v_bonus integer; v_amount integer;
 v_hp integer; v_next bigint; v_ord bigint; v_dmg integer; v_log text; v_stat integer; v_warr integer; v_idx integer; v_foe jsonb; v_result jsonb;
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
 perform 1 from public.rooms where code=v_code for update;
 if not found then raise exception 'ROOM_NOT_FOUND'; end if;
 select * into v_actor from public.players where room_code=v_code and user_id=v_uid;
 if not found then raise exception 'NOT_MEMBER'; end if;
 select state into v_state from public.game_states where room_code=v_code for update;
 if not coalesce((v_state->>'started')::boolean,false) then raise exception 'NOT_STARTED'; end if;
 v_combat:=v_state->'combat';
 if p_id='rest' then
   if not v_actor.is_host then raise exception 'HOST_ONLY'; end if;
   if v_combat is not null and v_combat<>'null'::jsonb and (v_combat->>'hp')::int>0 then raise exception 'COMBAT_ACTIVE'; end if;
   if coalesce((v_state->>'rested_chapter')::int,-1)=(v_state->>'chapter')::int then raise exception 'ALREADY_RESTED'; end if;
   update public.players set hp=max_hp,death_failures=0,death_successes=0,spell_slots=public.campaign_slots(level),ability_charges=2
    where room_code=v_code and user_id is not null and death_failures<3;
   v_state:=jsonb_set(v_state,'{rested_chapter}',to_jsonb((v_state->>'chapter')::int));
   v_log:='队伍长休：恢复生命、职业技能和法术位（本章限一次）。';
 else
   select * into v_power from public.campaign_powers where id=p_id and profession=v_actor.class_name;
   if not found then raise exception 'POWER_NOT_KNOWN'; end if;
   if v_actor.hp<=0 or v_actor.death_failures>=3 then raise exception 'DOWNED'; end if;
   if v_power.ring=0 then
     if v_slot<>0 or v_actor.ability_charges<=0 then raise exception 'NO_ABILITY_CHARGES'; end if;
     update public.players set ability_charges=ability_charges-1 where id=v_actor.id;
   else
     if v_slot<v_power.ring or v_slot>6 or v_actor.level<2*v_power.ring-1 then raise exception 'SPELL_CIRCLE_LOCKED'; end if;
     v_slots:=v_actor.spell_slots;
     if coalesce((v_slots->>v_slot)::int,0)<=0 then raise exception 'NO_SPELL_SLOT'; end if;
     update public.players set spell_slots=jsonb_set(spell_slots,array[v_slot::text],to_jsonb((v_slots->>v_slot)::int-1)) where id=v_actor.id;
   end if;
   if v_combat is not null and v_combat<>'null'::jsonb and (v_combat->>'hp')::int>0 then
     if (v_combat->>'turn')::bigint<>v_actor.id then raise exception 'NOT_YOUR_TURN'; end if;
   elsif v_power.kind<>'heal' then raise exception 'NO_COMBAT'; end if;
   v_amount:=v_power.amount+greatest(0,v_slot-v_power.ring)*2;
   if v_power.kind in ('heal','ward') then
     select * into v_target from public.players where id=coalesce(p_target,v_actor.id) and room_code=v_code and (user_id is not null or is_companion);
     if not found then raise exception 'INVALID_TARGET'; end if;
     if v_target.death_failures>=3 then raise exception 'TARGET_DEAD'; end if;
   end if;
   if v_power.kind='heal' then
     v_amount:=v_amount+floor(random()*6)::int+1;
     update public.players set hp=least(max_hp,hp+v_amount),death_failures=0,death_successes=0 where id=v_target.id;
     v_log:=v_power.name||'：'||v_target.name||' 恢复 '||least(v_amount,v_target.max_hp-v_target.hp)||' HP';
   elsif v_power.kind='ward' then
     v_combat:=jsonb_set(v_combat,'{wards}',jsonb_set(coalesce(v_combat->'wards','{}'::jsonb),array[v_target.id::text],to_jsonb(greatest(v_amount,coalesce((v_combat->'wards'->>v_target.id::text)::int,0))),true));
     v_log:=v_power.name||'：'||v_target.name||' 下一次受攻击时 AC +'||v_amount;
   elsif v_power.kind='weaken' then
     v_idx:=public.campaign_enemy_index(v_combat->'enemies',p_target);
     v_foe:=v_combat->'enemies'->v_idx;
     v_combat:=jsonb_set(jsonb_set(v_combat,array['enemies',v_idx::text,'ac'],to_jsonb(greatest(8,(v_foe->>'ac')::int-v_amount))),array['enemies',v_idx::text,'attack_bonus'],to_jsonb(greatest(0,(v_foe->>'attack_bonus')::int-1)));
     v_log:=v_power.name||'：'||(v_foe->>'name')||' AC -'||v_amount||'、攻击 -1';
   elsif v_power.kind='damage' then
     v_idx:=public.campaign_enemy_index(v_combat->'enemies',p_target);
     v_foe:=v_combat->'enemies'->v_idx;
     v_stat:=case v_actor.class_name when '法师' then 3 when '牧师' then 4 when '游侠' then 4 when '吟游诗人' then 5 when '游荡者' then 1 when '圣武士' then 5 else 0 end;
     v_bonus:=floor(((v_actor.stats->>v_stat)::int-10)/2.0)::int+2+(v_actor.level-1)/4;
     v_roll:=floor(random()*20)::int+1;
     v_dmg:=case when v_roll=1 or (v_roll<>20 and v_roll+v_bonus<(v_foe->>'ac')::int) then 0 else v_amount+floor(random()*6)::int+1+case when v_roll=20 then v_amount else 0 end end;
     v_hp:=greatest(0,(v_foe->>'hp')::int-v_dmg);
     v_combat:=jsonb_set(v_combat,array['enemies',v_idx::text,'hp'],to_jsonb(v_hp));
     v_combat:=jsonb_set(v_combat,'{hp}',to_jsonb(public.campaign_enemy_hp(v_combat->'enemies')));
     v_log:=v_power.name||' → '||(v_foe->>'name')||' D20='||v_roll||'+'||v_bonus||case when v_roll=20 then ' 大成功' when v_roll=1 then ' 大失败' else '' end||'，伤害 '||v_dmg;
   else raise exception 'UNKNOWN_EFFECT'; end if;

   if v_combat is not null and v_combat<>'null'::jsonb and (v_combat->>'hp')::int>0 then
     v_result:=public.campaign_finish_turn(v_code,v_combat,v_actor.id);
     v_combat:=v_result->'combat';
     v_log:=v_log||coalesce(v_result->>'log','');
   elsif v_combat is not null and v_combat<>'null'::jsonb and (v_combat->>'hp')::int=0 and v_power.kind='damage' then
     update public.players set gold=gold+12+coalesce((v_state->>'chapter')::int/5,0)*3 where room_code=v_code and user_id is not null;
     v_log:=v_log||'；敌方全灭，队员获得战利品金币';
   end if;
   if v_combat is not null and v_combat<>'null'::jsonb then v_state:=jsonb_set(v_state,'{combat}',v_combat); end if;
 end if;
 update public.game_states set state=jsonb_set(v_state,'{version}',to_jsonb(coalesce((v_state->>'version')::int,0)+1)),updated_at=now() where room_code=v_code;
 insert into public.messages(room_code,sender,body,kind) values(v_code,v_actor.name,v_log,'power');
 return public.party_snapshot(v_code);
end $$;
insert into public.campaign_dialogues(chapter_id,speaker,role,beats) values
(0,'守门人哈罗','守住城门的老兵','[{"text":"哈罗用靴尖挡住车册：“我数了十二辆。第十三辆的车夫没有脸，只有一顶帽子。”","options":[{"label":"追问：核对夜间车册","reply":"雨水将墨迹晕开，只有第十三栏的纸面仍干燥。 你们发现这一栏是事后用另一种墨水添上的。","flag":"voice_0_inquiry"},{"label":"问起：问守门人最后一件小事","reply":"老守门人不敢说马车，却记得马蹄踏过桥石的节奏。 他承认听见过一声不属于马车的钟响。","flag":"voice_0_trust"}]},{"text":"“车册是湿的，那一栏却干。有人等雨停后才补上名字；我放他进城，罪算我的。”","options":[{"label":"核实「伪造的放行记录」的来历","reply":"守卫收走车册，却漏下一张沾灰的副页。 你们发现这一栏是事后用另一种墨水添上的。","flag":"approach_0_aid"},{"label":"先保护「第十三声钟」的证人","reply":"他闭口不谈，但你们知道有人在看着他。 他承认听见过一声不属于马车的钟响。","flag":"approach_0_caution"}]},{"text":"“你们要追那辆车，还是先保住知道钟声的人？城门在日出前会换班。”","options":[{"label":"争取守门人哈罗支持「调查灰烬」","reply":"“你们发现这一栏是事后用另一种墨水添上的。”守门人哈罗决定留下，帮助核验伪造的放行记录。","flag":"support_0_stay"},{"label":"请守门人哈罗协助「混入马车队」","reply":"“他承认听见过一声不属于马车的钟响。”守门人哈罗带走第十三声钟的线索，约定安全地点再见。","flag":"support_0_protect"}]}]'::jsonb),
(1,'寄存铺掌柜艾尔','保管铜匣的人','[{"text":"艾尔把铜匣推过柜台：“我没写你们的名字。十九年的寄存费倒是一天没欠。”","options":[{"label":"追问：查看铜匣封蜡","reply":"蜡上有三代前的工匠印，新的刀痕却划开了边缘。 你们找到藏在封口里的第二把钥匙。","flag":"voice_1_inquiry"},{"label":"问起：与寄存铺掌柜对账","reply":"账簿里每年都有人替这只匣子续费，署名各不相同。 掌柜交出最近一次付款的收据。","flag":"voice_1_trust"}]},{"text":"“封蜡旧，刀痕新。若钥匙是今天塞进去的，付钱的人就在城里。”","options":[{"label":"核实「匣中钥匙」的来历","reply":"刀痕割断了纸条，地址只剩半截。 你们找到藏在封口里的第二把钥匙。","flag":"approach_1_aid"},{"label":"先保护「匿名收据」的证人","reply":"掌柜要求你们先证明自己不是来灭口的。 掌柜交出最近一次付款的收据。","flag":"approach_1_caution"}]},{"text":"“我会锁铺子到天亮。开匣的人要承担里面那张名单的后果。”","options":[{"label":"争取寄存铺掌柜艾尔支持「打开铜匣」","reply":"“你们找到藏在封口里的第二把钥匙。”寄存铺掌柜艾尔决定留下，帮助核验匣中钥匙。","flag":"support_1_stay"},{"label":"请寄存铺掌柜艾尔协助「保护掌柜」","reply":"“掌柜交出最近一次付款的收据。”寄存铺掌柜艾尔带走匿名收据的线索，约定安全地点再见。","flag":"support_1_protect"}]}]'::jsonb),
(2,'信使诺娅','熟悉屋顶灯语','[{"text":"诺娅擦掉镜片上的雨：“第三座塔早废了，可昨夜它回答了我的灯。”","options":[{"label":"追问：记录灯光顺序","reply":"两座塔一明一暗，第三座塔总迟一拍。 灯语指向一处明日才会发生的会面。","flag":"voice_2_inquiry"},{"label":"问起：攀上废塔屋顶","reply":"瓦片松动，下面有人刚铺过防雨的绳索。 你们在塔顶找到一枚新的议会铜扣。","flag":"voice_2_trust"}]},{"text":"“有人抢先布好屋顶绳索。他们知道信号会指向明天的会面。”","options":[{"label":"核实「明日会面」的来历","reply":"你们只能辨认出钟楼与河岸两个词。 灯语指向一处明日才会发生的会面。","flag":"approach_2_aid"},{"label":"先保护「议会铜扣」的证人","reply":"巡夜人注意到塔顶有动静，搜查加紧。 你们在塔顶找到一枚新的议会铜扣。","flag":"approach_2_caution"}]},{"text":"“灯语可以破译，信使也能追。但屋脊只容一队人先走。”","options":[{"label":"争取信使诺娅支持「破译灯语」","reply":"“灯语指向一处明日才会发生的会面。”信使诺娅决定留下，帮助核验明日会面。","flag":"support_2_stay"},{"label":"请信使诺娅协助「追上信使」","reply":"“你们在塔顶找到一枚新的议会铜扣。”信使诺娅带走议会铜扣的线索，约定安全地点再见。","flag":"support_2_protect"}]}]'::jsonb),
(3,'伊莱娅·维恩','失踪议员的档案员','[{"text":"伊莱娅把空杯摆在主位：“他演讲时，我正在档案室给他登记失踪。”","options":[{"label":"追问：比对宴会座次","reply":"每张请柬都有签名，主人那一席的墨水却没有干。 缺席者在宴会开始后仍有人替他签过名。","flag":"voice_3_inquiry"},{"label":"问起：和档案员伊莱娅交谈","reply":"她将一个空酒杯摆到主人座前，等待你们先说出怀疑。 她说出今晚收到过第二份请柬。","flag":"voice_3_trust"}]},{"text":"“座次卡的墨水还没干。冒名者连他的习惯都学会了，唯独忘记左手写字。”","options":[{"label":"核实「主人代签」的来历","reply":"一名宾客拿走了关键的席位卡。 缺席者在宴会开始后仍有人替他签过名。","flag":"approach_3_aid"},{"label":"先保护「第二份请柬」的证人","reply":"她只肯留下自己的地址，明日再谈。 她说出今晚收到过第二份请柬。","flag":"approach_3_caution"}]},{"text":"“把请柬拿走会惊动宾客；留下来问他们，又可能让冒名者先逃。”","options":[{"label":"争取伊莱娅·维恩支持「核对座次」","reply":"“缺席者在宴会开始后仍有人替他签过名。”伊莱娅·维恩决定留下，帮助核验主人代签。","flag":"support_3_stay"},{"label":"请伊莱娅·维恩协助「安抚宾客」","reply":"“她说出今晚收到过第二份请柬。”伊莱娅·维恩带走第二份请柬的线索，约定安全地点再见。","flag":"support_3_protect"}]}]'::jsonb),
(4,'管家赛芙','宅邸暗室的看守','[{"text":"赛芙关上暗室门：“我替这家人守了三十年，第一次看见他们按街区给活人标价。”","options":[{"label":"追问：测绘暗室","reply":"地砖下的暗槽沿整条街延伸，图纸刻意避开了井。 你们定位了运输契约的隐蔽通道。","flag":"voice_4_inquiry"},{"label":"问起：检查售地地图","reply":"地块编号与现有房屋不符，仿佛整条街已经搬走。 你们发现仍有人居住的街区被标作空地。","flag":"voice_4_trust"}]},{"text":"“暗槽通向井口。那张售地地图上，你们住过的街道已经被擦成空白。”","options":[{"label":"核实「暗槽路线」的来历","reply":"机械锁响起，来人已知道暗室有人。 你们定位了运输契约的隐蔽通道。","flag":"approach_4_aid"},{"label":"先保护「被抹去的住户」的证人","reply":"地图背面的出资人名字被刮去。 你们发现仍有人居住的街区被标作空地。","flag":"approach_4_caution"}]},{"text":"“真地图只有一份。带走它，或者留下假的骗过接货人，由你们定。”","options":[{"label":"争取管家赛芙支持「带走地图」","reply":"“你们定位了运输契约的隐蔽通道。”管家赛芙决定留下，帮助核验暗槽路线。","flag":"support_4_stay"},{"label":"请管家赛芙协助「留下假地图」","reply":"“你们发现仍有人居住的街区被标作空地。”管家赛芙带走被抹去的住户的线索，约定安全地点再见。","flag":"support_4_protect"}]}]'::jsonb),
(5,'穆雷','灰市修表匠','[{"text":"穆雷拿起停摆的怀表：“我故意把钟拨慢，你们只有这一刻钟看缺页。”","options":[{"label":"追问：追查账本缺页","reply":"修表匠穆雷故意把钟拨慢，给你们留了一刻钟。 缺页对应一笔付给夜巡队的护送费。","flag":"voice_5_inquiry"},{"label":"问起：安抚搬运工","reply":"他们担心说出名字后失去工作。 一名工人指出马车的秘密卸货处。","flag":"voice_5_trust"}]},{"text":"“账上那笔夜巡护送费，收钱的人今晚要来拆我的铺子。”","options":[{"label":"核实「护送费」的来历","reply":"巡逻队先一步带走账本，你们记下了日期。 缺页对应一笔付给夜巡队的护送费。","flag":"approach_5_aid"},{"label":"先保护「灰市卸货点」的证人","reply":"他们拒绝作证，但愿意在暗处放哨。 一名工人指出马车的秘密卸货处。","flag":"approach_5_caution"}]},{"text":"“搬运工可以证明卸货点，但他们的名字一旦上纸就会丢工作。”","options":[{"label":"争取穆雷支持「抄录账本」","reply":"“缺页对应一笔付给夜巡队的护送费。”穆雷决定留下，帮助核验护送费。","flag":"support_5_stay"},{"label":"请穆雷协助「答应保护工人」","reply":"“一名工人指出马车的秘密卸货处。”穆雷带走灰市卸货点的线索，约定安全地点再见。","flag":"support_5_protect"}]}]'::jsonb),
(6,'园丁塔姆','花房的照料者','[{"text":"塔姆揉碎白蕨：“这花喝的是矿水，不是贵族花园的雨。”","options":[{"label":"追问：鉴别白蕨孢子","reply":"温室最底层的花盆里留有矿水的苦味。 孢子证明矿坑废液被运进贵族宅邸。","flag":"voice_6_inquiry"},{"label":"问起：询问园丁","reply":"园丁手上的灼伤与花房的浇灌工具一致。 他承认每周有人送来封口的银桶。","flag":"voice_6_trust"}]},{"text":"“每周来的银桶烫伤我的手。送桶的人把井里的毒带进了宴会。”","options":[{"label":"核实「矿水白蕨」的来历","reply":"你们只带走了破碎的叶片。 孢子证明矿坑废液被运进贵族宅邸。","flag":"approach_6_aid"},{"label":"先保护「银桶印记」的证人","reply":"他不肯出卖雇主，但指给你们桶上的印记。 他承认每周有人送来封口的银桶。","flag":"approach_6_caution"}]},{"text":"“我能作证，花也能作证；只是雇主知道我家住在哪里。”","options":[{"label":"争取园丁塔姆支持「分析蕨叶」","reply":"“孢子证明矿坑废液被运进贵族宅邸。”园丁塔姆决定留下，帮助核验矿水白蕨。","flag":"support_6_stay"},{"label":"请园丁塔姆协助「向园丁许诺帮助」","reply":"“他承认每周有人送来封口的银桶。”园丁塔姆带走银桶印记的线索，约定安全地点再见。","flag":"support_6_protect"}]}]'::jsonb),
(7,'报社编辑莉缇','收过遗言的人','[{"text":"莉缇把三封遗言排成一行：“死人可以留下不同的秘密，不会同时写错同一个日期。”","options":[{"label":"追问：比对三封遗言","reply":"同一个词在三封信里拼写各异。 报社那封信的最后一句是伪造的。","flag":"voice_7_inquiry"},{"label":"问起：寻找送信人","reply":"年轻信使从来没见过收信的议员。 信使愿意带你们去真正的交接地点。","flag":"voice_7_trust"}]},{"text":"“报社收到的尾句是后来加的。年轻信使从没见过信里那个议员。”","options":[{"label":"核实「伪造的尾句」的来历","reply":"纸被雨打湿，你们仍记住了共同的落款。 报社那封信的最后一句是伪造的。","flag":"approach_7_aid"},{"label":"先保护「交接地点」的证人","reply":"他逃进人群，掉下一枚旧城区车票。 信使愿意带你们去真正的交接地点。","flag":"approach_7_caution"}]},{"text":"“找到交接处才能知道谁改信；公开遗言会让家属先受到追问。”","options":[{"label":"争取报社编辑莉缇支持「比对笔迹」","reply":"“报社那封信的最后一句是伪造的。”报社编辑莉缇决定留下，帮助核验伪造的尾句。","flag":"support_7_stay"},{"label":"请报社编辑莉缇协助「公开其中一封」","reply":"“信使愿意带你们去真正的交接地点。”报社编辑莉缇带走交接地点的线索，约定安全地点再见。","flag":"support_7_protect"}]}]'::jsonb),
(8,'夜巡队长维斯','被调离的小队长','[{"text":"维斯摊开巡逻图：“这条小巷不是忘了巡，是有人命令我们绕过去。”","options":[{"label":"追问：重走夜巡路线","reply":"地图上的巡逻点间隔不合理，恰好绕开一条小巷。 失踪的巡逻记录指向运货的夜晚。","flag":"voice_8_inquiry"},{"label":"问起：为被诬陷者找证人","reply":"卖茶人看到了两套制服在换班后相互交换。 证人愿意在安全地点出面。","flag":"voice_8_trust"}]},{"text":"“两套制服在换班时交换过。我的队员被当成他们的替罪羊。”","options":[{"label":"核实「缺失巡逻段」的来历","reply":"队长警惕你们，但放行了对小巷的调查。 失踪的巡逻记录指向运货的夜晚。","flag":"approach_8_aid"},{"label":"先保护「换班证词」的证人","reply":"证人只肯匿名写下所见。 证人愿意在安全地点出面。","flag":"approach_8_caution"}]},{"text":"“我想先救人。你们若先查伪令，我会留一道门给证人。”","options":[{"label":"争取夜巡队长维斯支持「接受调查」","reply":"“失踪的巡逻记录指向运货的夜晚。”夜巡队长维斯决定留下，帮助核验缺失巡逻段。","flag":"support_8_stay"},{"label":"请夜巡队长维斯协助「以金币换消息」","reply":"“证人愿意在安全地点出面。”夜巡队长维斯带走换班证词的线索，约定安全地点再见。","flag":"support_8_protect"}]}]'::jsonb),
(9,'街坊代表阿黛','旧印章的见证人','[{"text":"阿黛攥着拓印纸：“街坊认得旧章，认不得把他们划成空地的理由。”","options":[{"label":"追问：拓下地契印记","reply":"印章的缺口与旧议会纪念碑上的缺口完全吻合。 地契沿用的确是真正的旧章。","flag":"voice_9_inquiry"},{"label":"问起：在街坊会议发言","reply":"人们关心的不是文书，而是明早会不会被赶走。 街坊选出三名代表与你们同行。","flag":"voice_9_trust"}]},{"text":"“真章落在假地契上。三户人明早就要被赶走。”","options":[{"label":"核实「旧议会真章」的来历","reply":"拓印不完整，但年代没有错。 地契沿用的确是真正的旧章。","flag":"approach_9_aid"},{"label":"先保护「街坊代表」的证人","reply":"众人保持观望，仍借给你们一间议事屋。 街坊选出三名代表与你们同行。","flag":"approach_9_caution"}]},{"text":"“代表愿意同行，但他们要听见你们亲口说谁能继续住在这里。”","options":[{"label":"争取街坊代表阿黛支持「拓印印章」","reply":"“地契沿用的确是真正的旧章。”街坊代表阿黛决定留下，帮助核验旧议会真章。","flag":"support_9_stay"},{"label":"请街坊代表阿黛协助「向街坊说明」","reply":"“街坊选出三名代表与你们同行。”街坊代表阿黛带走街坊代表的线索，约定安全地点再见。","flag":"support_9_protect"}]}]'::jsonb),
(10,'拍卖师兰恩','地下拍卖的主持者','[{"text":"兰恩在帘后递来拍卖目录：“有人用你们的队名登记，钱却不在你们口袋里。”","options":[{"label":"追问：潜入拍卖后台","reply":"买家名单有一栏以你们的队名登记。 你们抄到了幕后担保人的名字。","flag":"voice_10_inquiry"},{"label":"问起：试探戴面具的买家","reply":"买家愿意谈价，却先问你们有没有原始契约。 她是受命试探所有寻找档案的人。","flag":"voice_10_trust"}]},{"text":"“面具买家只问原始契约。她在找一份比拍品更值钱的证据。”","options":[{"label":"核实「幕后担保人」的来历","reply":"保安发现脚印，你们只能记下拍卖地点。 你们抄到了幕后担保人的名字。","flag":"approach_10_aid"},{"label":"先保护「试探者」的证人","reply":"她留下半张写着会面时间的卡片。 她是受命试探所有寻找档案的人。","flag":"approach_10_caution"}]},{"text":"“后台的担保人和席上的买家互不信任；利用这点，才有机会把名单带出去。”","options":[{"label":"争取拍卖师兰恩支持「潜入拍卖」","reply":"“你们抄到了幕后担保人的名字。”拍卖师兰恩决定留下，帮助核验幕后担保人。","flag":"support_10_stay"},{"label":"请拍卖师兰恩协助「与买家交涉」","reply":"“她是受命试探所有寻找档案的人。”拍卖师兰恩带走试探者的线索，约定安全地点再见。","flag":"support_10_protect"}]}]'::jsonb),
(11,'守塔人格雷','钟楼最后的维护者','[{"text":"格雷按住轰鸣的齿轮：“每十三转，影子会指向一个不在钟里的暗格。”","options":[{"label":"追问：拆开钟楼传动轴","reply":"齿轮每十三次转动会露出一条刻字。 刻字告诉你们暗格不在钟里，而在钟声投影处。","flag":"voice_11_inquiry"},{"label":"问起：与守塔人交换故事","reply":"守塔人反复询问谁有资格为城市敲钟。 他交给你们一枚旧议会通行牌。","flag":"voice_11_trust"}]},{"text":"“守塔机械只认通行牌。它们醒来，连我也会被当作闯入者。”","options":[{"label":"核实「投影暗格」的来历","reply":"齿轮卡住，惊醒了守塔机械。 刻字告诉你们暗格不在钟里，而在钟声投影处。","flag":"approach_11_aid"},{"label":"先保护「通行牌」的证人","reply":"他仍让你们在塔内过夜以躲开搜捕。 他交给你们一枚旧议会通行牌。","flag":"approach_11_caution"}]},{"text":"“先解机关还是先找牌子？一声钟响之后，塔里就没有藏身处了。”","options":[{"label":"争取守塔人格雷支持「拆解齿轮」","reply":"“刻字告诉你们暗格不在钟里，而在钟声投影处。”守塔人格雷决定留下，帮助核验投影暗格。","flag":"support_11_stay"},{"label":"请守塔人格雷协助「安抚守塔人」","reply":"“他交给你们一枚旧议会通行牌。”守塔人格雷带走通行牌的线索，约定安全地点再见。","flag":"support_11_protect"}]}]'::jsonb),
(12,'赛洛','雨水图书馆馆长','[{"text":"赛洛把湿目录摊在灯下：“这些街名被刮掉，不代表那里的人没投过票。”","options":[{"label":"追问：修补浸水目录","reply":"字迹在灯火下显出被刮去的街道名称。 你们找到了被删除的选区名单。","flag":"voice_12_inquiry"},{"label":"问起：说服馆长开放密柜","reply":"赛洛要你们承诺让档案对所有居民开放。 密柜里保存了原始投票记录。","flag":"voice_12_trust"}]},{"text":"“密柜中的原件能推翻改写的名单；我只把它交给愿意公开档案的人。”","options":[{"label":"核实「旧选区名单」的来历","reply":"墨水再次晕开，但馆长记得页码。 你们找到了被删除的选区名单。","flag":"approach_12_aid"},{"label":"先保护「投票原件」的证人","reply":"她只交给你们一份可公开的抄本。 密柜里保存了原始投票记录。","flag":"approach_12_caution"}]},{"text":"“拿走原件会置图书馆于险地。你们可以带抄本，也可以承担守护原件的责任。”","options":[{"label":"争取赛洛支持「修复目录」","reply":"“你们找到了被删除的选区名单。”赛洛决定留下，帮助核验旧选区名单。","flag":"support_12_stay"},{"label":"请赛洛协助「承诺开放档案」","reply":"“密柜里保存了原始投票记录。”赛洛带走投票原件的线索，约定安全地点再见。","flag":"support_12_protect"}]}]'::jsonb),
(13,'驯养人菲恩','白鸦的伙伴','[{"text":"菲恩对着窗沿吹哨：“白鸦不落最亮的灯。它知道哪扇窗还安全。”","options":[{"label":"追问：跟随白鸦","reply":"白鸦在三处窗台停留，却从不靠近最亮的灯。 你们找到它与失踪议员往来的暗窗。","flag":"voice_13_inquiry"},{"label":"问起：营救驯养人","reply":"驯养人被关在没有锁的房间，门外却有人看守。 你们带出他和一枚刻有收件地址的脚环。","flag":"voice_13_trust"}]},{"text":"“我被关在没锁的屋里，因为脚环上的收件地址比锁更能困住我。”","options":[{"label":"核实「暗窗」的来历","reply":"它飞走前落下一根沾着印泥的羽毛。 你们找到它与失踪议员往来的暗窗。","flag":"approach_13_aid"},{"label":"先保护「收件脚环」的证人","reply":"他趁守卫换班自行逃出，约你们河边见。 你们带出他和一枚刻有收件地址的脚环。","flag":"approach_13_caution"}]},{"text":"“追鸦能找到暗窗；先带我离开，才能知道脚环原来送给谁。”","options":[{"label":"争取驯养人菲恩支持「追踪白鸦」","reply":"“你们找到它与失踪议员往来的暗窗。”驯养人菲恩决定留下，帮助核验暗窗。","flag":"support_13_stay"},{"label":"请驯养人菲恩协助「营救驯养人」","reply":"“你们带出他和一枚刻有收件地址的脚环。”驯养人菲恩带走收件脚环的线索，约定安全地点再见。","flag":"support_13_protect"}]}]'::jsonb),
(14,'登记官莫罗','保管年代记录的人','[{"text":"莫罗把两份文书折在一起：“同一张纸上，有个死了三十年的人签了昨天的职务。”","options":[{"label":"追问：校验两份文书年代","reply":"纸张同样古老，签名的职务却隔了三十年。 你们证明后来者借用死者的印章。","flag":"voice_14_inquiry"},{"label":"问起：质问登记官","reply":"登记官只愿公开一份不完整的收件簿。 他在被问及缺页时看向了执政官的办公室。","flag":"voice_14_trust"}]},{"text":"“缺页的收件簿最后一次送进执政官办公室，我没有签收它回来。”","options":[{"label":"核实「借章者」的来历","reply":"日期问题仍无法解释，你们标出需要追问的人。 你们证明后来者借用死者的印章。","flag":"approach_14_aid"},{"label":"先保护「执政官线索」的证人","reply":"他销毁了自己的便条，但你们记住他的迟疑。 他在被问及缺页时看向了执政官的办公室。","flag":"approach_14_caution"}]},{"text":"“我敢说年代，不敢猜命令者。你们把证据放在桌上，我才会作证。”","options":[{"label":"争取登记官莫罗支持「核对年代」","reply":"“你们证明后来者借用死者的印章。”登记官莫罗决定留下，帮助核验借章者。","flag":"support_14_stay"},{"label":"请登记官莫罗协助「公布矛盾」","reply":"“他在被问及缺页时看向了执政官的办公室。”登记官莫罗带走执政官线索的线索，约定安全地点再见。","flag":"support_14_protect"}]}]'::jsonb),
(15,'摆渡人萨雅','地下水道的居民','[{"text":"萨雅把船桨横在渡口：“地下的人不问姓氏。先说说你们为进城失去了什么。”","options":[{"label":"追问：用故事换过桥权","reply":"水道居民不问出身，只问你们失去过什么。 他们为你们指认能避开巡逻的地下路。","flag":"voice_15_inquiry"},{"label":"问起：辨认面具图案","reply":"每张面具的空白处藏着一笔家族旧名。 你们发现至少三个被驱逐家族仍在这里。","flag":"voice_15_trust"}]},{"text":"“面具上的空白不是装饰，藏的是被驱逐家族的旧名。”","options":[{"label":"核实「地下渡口」的来历","reply":"他们收下故事，仍要求你们走公开的渡口。 他们为你们指认能避开巡逻的地下路。","flag":"approach_15_aid"},{"label":"先保护「旧家徽」的证人","reply":"面具的主人不愿暴露姓名，但留下家徽。 你们发现至少三个被驱逐家族仍在这里。","flag":"approach_15_caution"}]},{"text":"“有暗路，也有公开渡口。走哪条，会决定他们是否相信你们敢被看见。”","options":[{"label":"争取摆渡人萨雅支持「分享经历」","reply":"“他们为你们指认能避开巡逻的地下路。”摆渡人萨雅决定留下，帮助核验地下渡口。","flag":"support_15_stay"},{"label":"请摆渡人萨雅协助「带药给居民」","reply":"“你们发现至少三个被驱逐家族仍在这里。”摆渡人萨雅带走旧家徽的线索，约定安全地点再见。","flag":"support_15_protect"}]}]'::jsonb),
(16,'医师奥里','盐井哨站的救护者','[{"text":"奥里拆下伤兵的护甲：“同一个工坊编号刻在三个人的甲里，伤口却来自井水。”","options":[{"label":"追问：检查盐井护甲","reply":"守卫铠甲内侧有相同的炼金工坊编号。 编号将废液与上城区的工坊联系起来。","flag":"voice_16_inquiry"},{"label":"问起：救助受伤守卫","reply":"他在清醒时只记得有人命令把井水倒进下水道。 他愿意说出命令者的声音和口音。","flag":"voice_16_trust"}]},{"text":"“他醒来只记得命令者的口音。让他活着，线索才有证人。”","options":[{"label":"核实「工坊编号」的来历","reply":"锈迹遮住了编号，只剩半枚工坊徽章。 编号将废液与上城区的工坊联系起来。","flag":"approach_16_aid"},{"label":"先保护「命令者口音」的证人","reply":"他无法记起名字，但指向废井的北侧。 他愿意说出命令者的声音和口音。","flag":"approach_16_caution"}]},{"text":"“我守哨站，你们查工坊；若去井边，先避开流向下水道的绿水。”","options":[{"label":"争取医师奥里支持「搜查哨站」","reply":"“编号将废液与上城区的工坊联系起来。”医师奥里决定留下，帮助核验工坊编号。","flag":"support_16_stay"},{"label":"请医师奥里协助「救助伤者」","reply":"“他愿意说出命令者的声音和口音。”医师奥里带走命令者口音的线索，约定安全地点再见。","flag":"support_16_protect"}]}]'::jsonb),
(17,'矿工乌伦','目击甲壳兽的人','[{"text":"乌伦敲了一下甲壳碎片：“钟响时左边会张开，像一扇讨厌光的门。”","options":[{"label":"追问：寻找甲壳兽弱点","reply":"巨兽的左侧甲壳会在钟响时张开。 你们把弱点标记在战斗记录里。","flag":"voice_17_inquiry"},{"label":"问起：避开腐蚀的水面","reply":"井边残留着足以灼伤皮肤的绿色液体。 你们找到一处高台，准备从那里迎敌。","flag":"voice_17_trust"}]},{"text":"“那东西不该在盐井长大。有人把废液倾进来，才养出这一身壳。”","options":[{"label":"核实「甲壳缝隙」的来历","reply":"灰尘遮蔽视线，但它惧怕明亮的灯。 你们把弱点标记在战斗记录里。","flag":"approach_17_aid"},{"label":"先保护「井边高台」的证人","reply":"靴底被腐蚀，下一段路要放慢脚步。 你们找到一处高台，准备从那里迎敌。","flag":"approach_17_caution"}]},{"text":"“上高台可以看清弱点；在井底硬拼，就得先承受腐蚀。”","options":[{"label":"争取矿工乌伦支持「备战」","reply":"“你们把弱点标记在战斗记录里。”矿工乌伦决定留下，帮助核验甲壳缝隙。","flag":"support_17_stay"},{"label":"请矿工乌伦协助「寻找绕行路线」","reply":"“你们找到一处高台，准备从那里迎敌。”矿工乌伦带走井边高台的线索，约定安全地点再见。","flag":"support_17_protect"}]}]'::jsonb),
(18,'无名法官','地下证人守护者','[{"text":"无名法官把两份口供并排：“一个证人不能在同一天说出两种相反的话，除非有人逼他。”","options":[{"label":"追问：核对驱逐案卷","reply":"卷宗里有同一个人的两份互相冲突的证词。 你们找出证人曾被迫改变口供的日期。","flag":"voice_18_inquiry"},{"label":"问起：保证证人安全","reply":"无名法官把证人的名字写在纸上，等你们提出保护办法。 他答应在听证会上亲自作证。","flag":"voice_18_trust"}]},{"text":"“我保护的不是卷宗，是能活到听证会的人。先把撤离路线告诉我。”","options":[{"label":"核实「被迫改口日期」的来历","reply":"法官允许你们带走副本，但保留原卷。 你们找出证人曾被迫改变口供的日期。","flag":"approach_18_aid"},{"label":"先保护「法官承诺」的证人","reply":"他只派一名信使与你们同行。 他答应在听证会上亲自作证。","flag":"approach_18_caution"}]},{"text":"“我可以亲自作证。但若证人的姓名泄露，胜诉也没有意义。”","options":[{"label":"争取无名法官支持「保护证人」","reply":"“你们找出证人曾被迫改变口供的日期。”无名法官决定留下，帮助核验被迫改口日期。","flag":"support_18_stay"},{"label":"请无名法官协助「交换护卫承诺」","reply":"“他答应在听证会上亲自作证。”无名法官带走法官承诺的线索，约定安全地点再见。","flag":"support_18_protect"}]}]'::jsonb),
(19,'议员埃弗','归来的失踪者','[{"text":"埃弗看着旧演讲台：“我烧掉过一页证词，为了让写它的人活下去。”","options":[{"label":"追问：询问归来的议员","reply":"议员承认销毁过证词，却说那是为了保护活着的人。 他隐瞒了谁下令，但没有隐瞒动机。","flag":"voice_19_inquiry"},{"label":"问起：找回议员藏信","reply":"他把真正的信放在昔日演讲台的底座里。 信中有一份尚未公开的证人名单。","flag":"voice_19_trust"}]},{"text":"“信藏在台座里，名单不在我手中。你们可以骂我懦弱，却别再把证人交回去。”","options":[{"label":"核实「隐瞒的命令」的来历","reply":"他避开了你们的问题，留下旧会议时间。 他隐瞒了谁下令，但没有隐瞒动机。","flag":"approach_19_aid"},{"label":"先保护「证人名单」的证人","reply":"你们找到信封，内文已被人拿走。 信中有一份尚未公开的证人名单。","flag":"approach_19_caution"}]},{"text":"“公开我的过去，或者让我带你们找那封信。两条路都会有人不原谅。”","options":[{"label":"争取议员埃弗支持「质询议员」","reply":"“他隐瞒了谁下令，但没有隐瞒动机。”议员埃弗决定留下，帮助核验隐瞒的命令。","flag":"support_19_stay"},{"label":"请议员埃弗协助「给予作证机会」","reply":"“信中有一份尚未公开的证人名单。”议员埃弗带走证人名单的线索，约定安全地点再见。","flag":"support_19_protect"}]}]'::jsonb),
(20,'镜厅侍者菲娅','熟悉镜中暗门','[{"text":"菲娅熄掉一盏镜灯：“刺客逆着人群走；镜里的人走得比他快。”","options":[{"label":"追问：复原镜厅脚印","reply":"几十道影子中只有一双鞋在熄灯时逆着人群走。 你们确定刺客并非证人的随行者。","flag":"voice_20_inquiry"},{"label":"问起：保护证人离场","reply":"一面镜子后的暗门正通向楼梯。 你们带证人避开了追击。","flag":"voice_20_trust"}]},{"text":"“暗门通向楼梯，证人可以走。军械库泥却留在刺客鞋跟上。”","options":[{"label":"核实「逆行脚印」的来历","reply":"脚印被踩乱，但鞋跟上留有军械库的泥。 你们确定刺客并非证人的随行者。","flag":"approach_20_aid"},{"label":"先保护「镜后暗门」的证人","reply":"证人安全离场，但刺客看清了你们的脸。 你们带证人避开了追击。","flag":"approach_20_caution"}]},{"text":"“我能把证人送走一次。你们要留下来认出刺客，还是陪证人撤离？”","options":[{"label":"争取镜厅侍者菲娅支持「封锁长廊」","reply":"“你们确定刺客并非证人的随行者。”镜厅侍者菲娅决定留下，帮助核验逆行脚印。","flag":"support_20_stay"},{"label":"请镜厅侍者菲娅协助「保护证人」","reply":"“你们带证人避开了追击。”镜厅侍者菲娅带走镜后暗门的线索，约定安全地点再见。","flag":"support_20_protect"}]}]'::jsonb),
(21,'钟匠杜伦','维护城市总钟','[{"text":"杜伦指向停住的总钟：“线从执政官办公室来。行会没权把全城的时间按停。”","options":[{"label":"追问：找出停钟机关","reply":"钟楼的总控线来自执政官办公室，而非工匠行会。 你们恢复了一座钟，留下机关上的指纹。","flag":"voice_21_inquiry"},{"label":"问起：与改革派谈条件","reply":"改革派承诺公开证据，却要求你们先放弃地下居民的席位。 你们发现他们内部也有人反对这个条件。","flag":"voice_21_trust"}]},{"text":"“改革派愿公开证据，却想先拿掉地下人的席位。这不是修钟，是换主人。”","options":[{"label":"核实「停钟机关」的来历","reply":"机关被锁死，你们记录了控制方向。 你们恢复了一座钟，留下机关上的指纹。","flag":"approach_21_aid"},{"label":"先保护「改革派分歧」的证人","reply":"他们暂不让步，但愿意参加下一场公开会议。 你们发现他们内部也有人反对这个条件。","flag":"approach_21_caution"}]},{"text":"“恢复钟声能召来居民；先谈条件，可能保住投票的秩序。”","options":[{"label":"争取钟匠杜伦支持「潜入办公室」","reply":"“你们恢复了一座钟，留下机关上的指纹。”钟匠杜伦决定留下，帮助核验停钟机关。","flag":"support_21_stay"},{"label":"请钟匠杜伦协助「接触改革派」","reply":"“你们发现他们内部也有人反对这个条件。”钟匠杜伦带走改革派分歧的线索，约定安全地点再见。","flag":"support_21_protect"}]}]'::jsonb),
(22,'桥卫雷蒙','接到封锁令的士兵','[{"text":"雷蒙把封桥令倒过来：“没签署人，只有一个我在假地契上见过的印。”","options":[{"label":"追问：寻找断桥的替代路","reply":"桥下的旧检修道曾由灰市工人维护。 曾受帮助的工人替你们开了检修门。","flag":"voice_22_inquiry"},{"label":"问起：向卫队出示证据","reply":"他们的命令没有签署人，只有一枚熟悉的假印。 一名守卫放你们通过，并记下文书上的矛盾。","flag":"voice_22_trust"}]},{"text":"“桥下检修道由灰市工人维护。他们若开门，封锁令就只封得住纸。”","options":[{"label":"核实「桥下检修道」的来历","reply":"检修门锈死，你们只能从桥墩攀过去。 曾受帮助的工人替你们开了检修门。","flag":"approach_22_aid"},{"label":"先保护「无签署封桥令」的证人","reply":"卫队不放行，却给你们一刻钟后撤。 一名守卫放你们通过，并记下文书上的矛盾。","flag":"approach_22_caution"}]},{"text":"“我能拖住卫队一刻钟。证据或替代路，总要先拿出一样。”","options":[{"label":"争取桥卫雷蒙支持「尝试谈判」","reply":"“曾受帮助的工人替你们开了检修门。”桥卫雷蒙决定留下，帮助核验桥下检修道。","flag":"support_22_stay"},{"label":"请桥卫雷蒙协助「请求旧盟友」","reply":"“一名守卫放你们通过，并记下文书上的矛盾。”桥卫雷蒙带走无签署封桥令的线索，约定安全地点再见。","flag":"support_22_protect"}]}]'::jsonb),
(23,'馆员梅瑞','抢救档案的人','[{"text":"梅瑞怀抱焦黑的目录：“火先烧到馆员宿舍，纵火者知道我们会救人。”","options":[{"label":"追问：组织救火队","reply":"档案室和馆员宿舍只能先救一处。 馆员同意先疏散，再合力保存原件。","flag":"voice_23_inquiry"},{"label":"问起：追踪纵火者","reply":"煤灰落在同一种皮靴的鞋纹里。 鞋纹通向雇佣兵临时驻地。","flag":"voice_23_trust"}]},{"text":"“皮靴煤灰一路通向雇佣兵营地。原始选票还在档案室里面。”","options":[{"label":"核实「救出的原件」的来历","reply":"火势迫使你们带走部分抄本。 馆员同意先疏散，再合力保存原件。","flag":"approach_23_aid"},{"label":"先保护「雇佣兵鞋纹」的证人","reply":"你们在火场外发现未点燃的油瓶。 鞋纹通向雇佣兵临时驻地。","flag":"approach_23_caution"}]},{"text":"“请先疏散人，或先抢原件；我不能替你们承诺谁能活下来。”","options":[{"label":"争取馆员梅瑞支持「组织守卫」","reply":"“馆员同意先疏散，再合力保存原件。”馆员梅瑞决定留下，帮助核验救出的原件。","flag":"support_23_stay"},{"label":"请馆员梅瑞协助「先救馆员」","reply":"“鞋纹通向雇佣兵临时驻地。”馆员梅瑞带走雇佣兵鞋纹的线索，约定安全地点再见。","flag":"support_23_protect"}]}]'::jsonb),
(24,'工人领袖露佩','街区议事主持者','[{"text":"露佩敲响街区议事铃：“四个派系都说安全第一，四种安全却互相冲突。”","options":[{"label":"追问：主持街区议事","reply":"四个派系各派代表，所有人都要求先保证安全。 居民愿意共同监督下一场表决。","flag":"voice_24_inquiry"},{"label":"问起：统计各派诉求","reply":"相似的要求被不同人用不同措辞提出。 你们提炼出三条所有派系都可接受的底线。","flag":"voice_24_trust"}]},{"text":"“把诉求写成三条共同底线，人们才有机会坐在同一张桌旁。”","options":[{"label":"核实「居民监督」的来历","reply":"争论没有结束，但没人离席。 居民愿意共同监督下一场表决。","flag":"approach_24_aid"},{"label":"先保护「共同底线」的证人","reply":"议事记录仍有分歧，你们留下原稿。 你们提炼出三条所有派系都可接受的底线。","flag":"approach_24_caution"}]},{"text":"“表决需要居民监督。若只让代表们关门谈，街道不会认这个结果。”","options":[{"label":"争取工人领袖露佩支持「收集意见」","reply":"“居民愿意共同监督下一场表决。”工人领袖露佩决定留下，帮助核验居民监督。","flag":"support_24_stay"},{"label":"请工人领袖露佩协助「举行公开集会」","reply":"“你们提炼出三条所有派系都可接受的底线。”工人领袖露佩带走共同底线的线索，约定安全地点再见。","flag":"support_24_protect"}]}]'::jsonb),
(25,'公证人希尔','契约鉴定人','[{"text":"希尔将契约翻到背面：“最旧的墨在这里。公民议会条款比贵族印记还早。”","options":[{"label":"追问：鉴定契约原件","reply":"契约上有四种不同墨水，最旧的一种在纸张背面。 你们证明公民议会条款并非后人添加。","flag":"voice_25_inquiry"},{"label":"问起：邀请地下代表","reply":"代表要求城市里每个无名者都能保有投票权。 他们同意带来历史见证人。","flag":"voice_25_trust"}]},{"text":"“地下代表要的不只是被邀请旁听；他们要被抹掉的人也有票。”","options":[{"label":"核实「契约原始条款」的来历","reply":"你们只证明了纸张年代，仍需更多证人。 你们证明公民议会条款并非后人添加。","flag":"approach_25_aid"},{"label":"先保护「地下代表」的证人","reply":"他们先派观察者，等待你们公开承诺。 他们同意带来历史见证人。","flag":"approach_25_caution"}]},{"text":"“纸张能证明年代，见证人才能证明城市曾答应过什么。”","options":[{"label":"争取公证人希尔支持「鉴定契约」","reply":"“你们证明公民议会条款并非后人添加。”公证人希尔决定留下，帮助核验契约原始条款。","flag":"support_25_stay"},{"label":"请公证人希尔协助「邀请所有派系」","reply":"“他们同意带来历史见证人。”公证人希尔带走地下代表的线索，约定安全地点再见。","flag":"support_25_protect"}]}]'::jsonb),
(26,'凯尔·索恩','执政官的守门人','[{"text":"凯尔的手没离开剑柄：“命令上有两处互相矛盾的日期。我效忠的不是一张错纸。”","options":[{"label":"追问：核对护卫命令","reply":"最后的守门人凯尔拿到的命令有两处日期相互矛盾。 他看出伪造之处，命部下收起武器。","flag":"voice_26_inquiry"},{"label":"问起：争取凯尔的信任","reply":"他曾发誓保护城市，而不是一个办公室。 凯尔允许一名证人通过。","flag":"voice_26_trust"}]},{"text":"“给我原件，再给我一个活着的证人。我可以命人让出通道。”","options":[{"label":"核实「伪造护卫令」的来历","reply":"他仍拦住道路，但愿意听取证词。 他看出伪造之处，命部下收起武器。","flag":"approach_26_aid"},{"label":"先保护「凯尔的条件」的证人","reply":"他要求你们先把证据交给公证人。 凯尔允许一名证人通过。","flag":"approach_26_caution"}]},{"text":"“若你们拿不出证据，我会挡路；若拿得出，我要亲自对上级解释。”","options":[{"label":"争取凯尔·索恩支持「展示证据」","reply":"“他看出伪造之处，命部下收起武器。”凯尔·索恩决定留下，帮助核验伪造护卫令。","flag":"support_26_stay"},{"label":"请凯尔·索恩协助「争取守卫」","reply":"“凯尔允许一名证人通过。”凯尔·索恩带走凯尔的条件的线索，约定安全地点再见。","flag":"support_26_protect"}]}]'::jsonb),
(27,'平民代表娜芙','议会大厅的见证人','[{"text":"娜芙把孩子带到石柱后：“两侧门都有人拿武器。长桌上的档案还没搬。”","options":[{"label":"追问：测量大厅掩体","reply":"雇佣兵从两侧门进入，平民仍在长桌旁。 你们找到可保护档案的石柱。","flag":"voice_27_inquiry"},{"label":"问起：劝平民撤离","reply":"他们担心离开后证据会被销毁。 平民留下见证人，其他人撤到安全处。","flag":"voice_27_trust"}]},{"text":"“平民不愿走，是怕一离开证据就被烧。我可以留下作见证。”","options":[{"label":"核实「大厅石柱」的来历","reply":"桌子挡住了视线，你们先安排疏散。 你们找到可保护档案的石柱。","flag":"approach_27_aid"},{"label":"先保护「撤离见证人」的证人","reply":"人群缓慢退开，留给你们的时间缩短。 平民留下见证人，其他人撤到安全处。","flag":"approach_27_caution"}]},{"text":"“选好掩体，再决定谁留在大厅；一旦火油落下，选择就来不及了。”","options":[{"label":"争取平民代表娜芙支持「迎战」","reply":"“你们找到可保护档案的石柱。”平民代表娜芙决定留下，帮助核验大厅石柱。","flag":"support_27_stay"},{"label":"请平民代表娜芙协助「疏散市民」","reply":"“平民留下见证人，其他人撤到安全处。”平民代表娜芙带走撤离见证人的线索，约定安全地点再见。","flag":"support_27_protect"}]}]'::jsonb),
(28,'书记员罗温','公开判决的记录者','[{"text":"罗温提起笔：“今天的判决会写进城史。空白选区也该有名字。”","options":[{"label":"追问：公开所有证据","reply":"旧贵族、改革派与地下居民都在等待你们先开口。 各派同意让普通居民发言。","flag":"voice_28_inquiry"},{"label":"问起：准备最终表决","reply":"投票册上还有被驱逐者的空白栏。 你们补回遗漏选区的名单。","flag":"voice_28_trust"}]},{"text":"“各派都盯着原件，却没人肯先让普通居民发言。”","options":[{"label":"核实「公开证据」的来历","reply":"会场出现质疑，你们仍有原件可供查验。 各派同意让普通居民发言。","flag":"approach_28_aid"},{"label":"先保护「补回的选区」的证人","reply":"时间不足，你们把名单留给下一届议会。 你们补回遗漏选区的名单。","flag":"approach_28_caution"}]},{"text":"“你们可以恢复旧公民议会，也能提出地下自治。我要记录的是理由，不只是票数。”","options":[{"label":"争取书记员罗温支持「恢复公民议会」","reply":"“各派同意让普通居民发言。”书记员罗温决定留下，帮助核验公开证据。","flag":"support_28_stay"},{"label":"请书记员罗温协助「建立地下自治」","reply":"“你们补回遗漏选区的名单。”书记员罗温带走补回的选区的线索，约定安全地点再见。","flag":"support_28_protect"}]}]'::jsonb),
(29,'伊莱娅·维恩','保存队伍编年史','[{"text":"伊莱娅翻开第一张请柬：“那晚你们为什么进城？现在还有同样的答案吗？”","options":[{"label":"追问：回访旧盟友","reply":"你们沿着一路走过的街道，听见不同人讲述同一夜。 旧盟友愿意为你们的选择留下证言。","flag":"voice_29_inquiry"},{"label":"问起：整理队伍编年史","reply":"每个人在第一页写下最初来到城门的理由。 你们保存了所有人的名字与选择。","flag":"voice_29_trust"}]},{"text":"“有人原谅了你们，有人没有。编年史要写两边的名字。”","options":[{"label":"核实「盟友后日谈」的来历","reply":"有人仍不赞成结果，却愿意继续对话。 旧盟友愿意为你们的选择留下证言。","flag":"approach_29_aid"},{"label":"先保护「队伍编年史」的证人","reply":"几页笔记遗失，但队伍记录仍在。 你们保存了所有人的名字与选择。","flag":"approach_29_caution"}]},{"text":"“街道不会替我们收尾。把旧盟友的证言和遗失的页补上，然后继续走。”","options":[{"label":"争取伊莱娅·维恩支持「记录后日谈」","reply":"“旧盟友愿意为你们的选择留下证言。”伊莱娅·维恩决定留下，帮助核验盟友后日谈。","flag":"support_29_stay"},{"label":"请伊莱娅·维恩协助「继续探索」","reply":"“你们保存了所有人的名字与选择。”伊莱娅·维恩带走队伍编年史的线索，约定安全地点再见。","flag":"support_29_protect"}]}]'::jsonb)
on conflict(chapter_id) do update set speaker=excluded.speaker,role=excluded.role,beats=excluded.beats;
revoke all on function public.campaign_finish_turn(text,jsonb,bigint),public.party_command(text,text,jsonb),public.party_power(text,text,bigint,integer) from public,anon,authenticated;
grant execute on function public.party_command(text,text,jsonb),public.party_power(text,text,bigint,integer) to authenticated;

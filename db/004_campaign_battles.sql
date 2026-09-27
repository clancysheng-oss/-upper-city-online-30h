-- Authored combat catalog. Existing rooms retain their active fight; later chapters use this catalog.
create table if not exists public.campaign_battles (chapter_id integer primary key references public.campaign_chapters(id), details jsonb not null);
alter table public.campaign_battles enable row level security;
revoke all on public.campaign_battles from public,anon,authenticated;
insert into public.campaign_battles(chapter_id,details) values
(2,'{"chapter":2,"name":"雨瓦追猎者","intro":"灯语被截获后，披着油布的追猎者沿湿滑屋脊围住信使。","hp":19,"ac":12,"attack":2,"min":1,"die":4,"aid":"ash","aidText":"灰烬路线让队伍先占高处。"}'),
(5,'{"chapter":5,"name":"灰市收账人","intro":"收账人带着没收工具闯进修表铺，要求交出所有账页。","hp":24,"ac":13,"attack":3,"min":2,"die":4,"aid":"map","aidText":"地图标出的后门让工人及时撤离。"}'),
(8,'{"chapter":8,"name":"冒名夜巡兵","intro":"假冒夜巡队的人试图逮捕证人，真正的队长被困在街口。","hp":26,"ac":13,"attack":3,"min":2,"die":5,"aid":"workers","aidText":"受保护的工人指出了伪造的巡逻口令。"}'),
(11,'{"chapter":11,"name":"失控的钟楼机械","intro":"守塔机械在齿轮间醒来，用铜臂封住藏有契约残页的暗格。","hp":29,"ac":14,"attack":3,"min":2,"die":5,"aid":"auction","aidText":"拍卖名单标出了机械的制造商和停机记号。"}'),
(14,'{"chapter":14,"name":"契约猎手","intro":"一名受雇猎手赶在你们核对日期前来毁掉原件。","hp":31,"ac":14,"attack":4,"min":2,"die":5,"aid":"archive","aidText":"馆长留下的索引揭示了猎手的退路。"}'),
(17,'{"chapter":17,"name":"盐井甲壳兽","intro":"废液变异的甲壳兽守住取证的深井，钟声响起时甲片张开。","hp":35,"ac":13,"attack":4,"min":3,"die":6,"aid":"rescued","aidText":"获救的守卫指出巨兽甲片的薄弱处。"}'),
(20,'{"chapter":20,"name":"镜厅刺客","intro":"证人在镜厅遭到伏击，刺客借镜像隐藏行动路线。","hp":32,"ac":14,"attack":4,"min":2,"die":6,"aid":"witness","aidText":"无名法官的护卫预先掩护了证人。"}'),
(23,'{"chapter":23,"name":"档案纵火队","intro":"纵火者破窗闯入雨水图书馆，火星已经落在原始选票旁。","hp":34,"ac":14,"attack":4,"min":3,"die":5,"aid":"archive","aidText":"保存好的目录指引馆员抢出证据。"}'),
(26,'{"chapter":26,"name":"执政官铁卫","intro":"守门人的上级奉命截住契约原件，在议事厅入口布下铁卫。","hp":38,"ac":15,"attack":5,"min":3,"die":6,"aid":"unity","aidText":"受邀的各派代表要求铁卫公开命令。"}'),
(28,'{"chapter":28,"name":"议会雇佣兵首领","intro":"雇佣兵冲入大厅，试图烧毁证据并驱散参与公开判决的人。","hp":42,"ac":15,"attack":5,"min":3,"die":6,"aid":"defector","aidText":"倒戈守卫挡住了首领的第一轮冲锋。"}')
on conflict(chapter_id) do update set details=excluded.details;

create or replace function public.party_command(p_code text, p_action text, p_payload jsonb default '{}'::jsonb) returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_code text:=upper(trim(coalesce(p_code,''))); v_uid uuid:=auth.uid(); v_name text; v_class text; v_id bigint; v_host boolean; v_state jsonb; v_players int; v_unready int; v_target bigint; v_roll int; v_bonus int; v_dc int; v_dmg int; v_hp int; v_ac int; v_idx int; v_flags jsonb; v_clues jsonb; v_combat jsonb; v_turn bigint; v_next bigint; v_enemy_hp int; v_log text; v_chars text:='ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; v_rand bytea; v_try int; v_newcode text; v_stats jsonb; v_max int; v_init jsonb; v_ord bigint; v_scene jsonb; v_key text; v_skill text; v_enemy jsonb; v_aid boolean;
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
 if p_action='create' then
  v_name:=left(trim(coalesce(p_payload->>'name','')),32); v_class:=p_payload->>'class';
  if length(v_name)<2 or v_class not in ('战士','游荡者','法师','牧师','游侠','吟游诗人') then raise exception 'INVALID_CHARACTER'; end if;
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
  if length(v_name)<2 or v_class not in ('战士','游荡者','法师','牧师','游侠','吟游诗人') then raise exception 'INVALID_CHARACTER'; end if;
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
    + case when (class_name='战士' and p_payload->>'skill'='运动') or (class_name='游荡者' and p_payload->>'skill' in ('调查','潜行')) or (class_name='法师' and p_payload->>'skill'='奥秘') or (class_name='牧师' and p_payload->>'skill'='洞悉') or (class_name='游侠' and p_payload->>'skill'='求生') or (class_name='吟游诗人' and p_payload->>'skill'='说服') then 2 else 0 end into v_bonus from public.players where id=v_id;
  v_dc:=greatest(5,least(30,coalesce((p_payload->>'dc')::int,15)));
  v_roll:=floor(random()*20)::int+1;
  v_log:=left(coalesce(p_payload->>'skill','技能'),30)||'检定 D20='||v_roll||'，加值 '||v_bonus||'，DC '||v_dc||'：'||case when v_roll=20 then '大成功' when v_roll=1 then '大失败' when v_roll+v_bonus>=v_dc then '成功' else '失败' end;
 elsif p_action='explore' then
  if not (v_state->>'started')::boolean then raise exception 'NOT_STARTED'; end if;
  v_idx:=coalesce((p_payload->>'index')::int,-1);
  if v_idx<0 or v_idx>1 then raise exception 'INVALID_ENCOUNTER'; end if;
  v_key:=(v_state->>'chapter')||':'||v_idx;
  if coalesce(v_state->'explored','[]'::jsonb) ? v_key then raise exception 'ALREADY_EXPLORED'; end if;
  select scenes->v_idx into v_scene from public.campaign_chapters where id=(v_state->>'chapter')::int;
  if v_scene is null then raise exception 'ENCOUNTER_UNAVAILABLE'; end if;
  v_skill:=v_scene->>'skill'; v_dc:=(v_scene->>'dc')::int;
  select floor(((stats->>case v_skill when '运动' then 0 when '潜行' then 1 when '调查' then 3 when '奥秘' then 3 when '洞悉' then 4 when '求生' then 4 else 5 end)::int-10)/2.0)::int
   + case when (class_name='战士' and v_skill='运动') or (class_name='游荡者' and v_skill in ('调查','潜行')) or (class_name='法师' and v_skill='奥秘') or (class_name='牧师' and v_skill='洞悉') or (class_name='游侠' and v_skill='求生') or (class_name='吟游诗人' and v_skill='说服') then 2 else 0 end into v_bonus from public.players where id=v_id;
  v_roll:=floor(random()*20)::int+1;
  v_state:=jsonb_set(v_state,'{explored}',coalesce(v_state->'explored','[]'::jsonb)||to_jsonb(v_key));
  if v_roll=20 or (v_roll<>1 and v_roll+v_bonus>=v_dc) then
   v_clues:=coalesce(v_state->'clues','[]'::jsonb); v_flags:=coalesce(v_state->'flags','[]'::jsonb);
   if not v_clues ? (v_scene->>'clue') then v_clues:=v_clues||to_jsonb(v_scene->>'clue'); end if;
   if not v_flags ? (v_scene->>'flag') then v_flags:=v_flags||to_jsonb(v_scene->>'flag'); end if;
   v_state:=jsonb_set(jsonb_set(v_state,'{clues}',v_clues),'{flags}',v_flags);
   v_log:=v_scene->>'success';
  else v_log:=v_scene->>'failure'; end if;
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
  v_log:='选择：'||left(coalesce(p_payload->>'label',''),80);
 elsif p_action='advance' then
  if not v_host then raise exception 'HOST_ONLY'; end if;
  if not (v_state->>'started')::boolean then raise exception 'NOT_STARTED'; end if;
  if (v_state->>'chapter')::int>=29 then raise exception 'CAMPAIGN_COMPLETE'; end if;
  if coalesce((v_state->>'chosen_chapter')::int,-1)<>coalesce((v_state->>'chapter')::int,0) then raise exception 'CHOOSE_BEFORE_ADVANCE'; end if;
  if v_state->'combat' is not null and v_state->'combat'<>'null'::jsonb and coalesce((v_state#>>'{combat,hp}')::int,0)>0 then raise exception 'COMBAT_ACTIVE'; end if;
  v_idx:=least(29,coalesce((v_state->>'chapter')::int,0)+1);
  v_state:=jsonb_set(jsonb_set(v_state,'{chapter}',to_jsonb(v_idx)),'{completed_quests}',coalesce(v_state->'completed_quests','[]'::jsonb)||to_jsonb(v_idx-1));
  -- A completed fight grants a camp rest before the next scene. Downed allies need healing first.
  if coalesce((v_state#>>'{combat,hp}')::int,-1)=0 then
   update public.players set hp=max_hp where room_code=v_code and user_id is not null and hp>0;
  end if;
  select details into v_enemy from public.campaign_battles where chapter_id=v_idx;
  if v_enemy is not null then
   select count(*) into v_players from public.players where room_code=v_code and user_id is not null;
   v_aid:=coalesce(v_state->'flags','[]'::jsonb) ? (v_enemy->>'aid');
   v_enemy_hp:=(v_enemy->>'hp')::int+greatest(0,v_players-2)*7-case when v_aid then 5 else 0 end;
   select jsonb_agg(jsonb_build_object('id',id,'roll',roll) order by roll desc,id),(array_agg(id order by roll desc,id))[1] into v_init,v_turn from (select id,floor(random()*20)::int+1 as roll from public.players where room_code=v_code and user_id is not null and hp>0) i;
   v_state:=jsonb_set(v_state,'{combat}',jsonb_build_object('name',v_enemy->>'name','hp',v_enemy_hp,'max_hp',v_enemy_hp,'ac',(v_enemy->>'ac')::int-case when v_aid then 1 else 0 end,'attack_bonus',(v_enemy->>'attack')::int,'damage_min',(v_enemy->>'min')::int,'damage_die',(v_enemy->>'die')::int,'turn',v_turn,'initiative',v_init,'round',1));
  else v_state:=jsonb_set(v_state,'{combat}','null'::jsonb); end if;
  if v_idx=29 then v_state:=jsonb_set(v_state,'{ending}',to_jsonb(case when (v_state->'flags') ? 'council' then '公民议会重建' when (v_state->'flags') ? 'autonomy' then '地下自治联盟' when jsonb_array_length(v_state->'flags')>=18 then '城市共同体' else '艰难的黎明' end)); end if;
  if v_idx%5=0 then update public.players set gold=gold+10 where room_code=v_code and user_id is not null; end if;
  v_log:='推进至第 '||(v_idx+1)||' 章。'||case when v_idx%5=0 then ' 队员各获 10 金币。' else '' end||case when v_enemy is not null then ' 遭遇：'||(v_enemy->>'name')||'。'||case when v_aid then v_enemy->>'aidText' else '' end else '' end;
 elsif p_action='attack' then
  v_combat:=v_state->'combat';
  if v_combat is null or v_combat='null'::jsonb or (v_combat->>'hp')::int<=0 then raise exception 'NO_COMBAT'; end if;
  if (v_combat->>'turn')::bigint<>v_id then raise exception 'NOT_YOUR_TURN'; end if;
  if v_hp<=0 then raise exception 'DOWNED'; end if;
  select case class_name when '战士' then 5 when '游荡者' then 5 when '法师' then 5 when '游侠' then 5 else 4 end into v_bonus from public.players where id=v_id;
  v_roll:=floor(random()*20)::int+1; v_dmg:=case when v_roll=1 or (v_roll<>20 and v_roll+v_bonus<(v_combat->>'ac')::int) then 0 else (floor(random()*8)::int+1)+v_bonus+case when v_roll=20 then (floor(random()*8)::int+1) else 0 end end;
  v_enemy_hp:=greatest(0,(v_combat->>'hp')::int-v_dmg); v_combat:=jsonb_set(v_combat,'{hp}',to_jsonb(v_enemy_hp));
  v_log:='攻击 D20='||v_roll||case when v_roll=20 then ' 大成功' when v_roll=1 then ' 大失败' else '' end||'，伤害 '||v_dmg;
  if v_enemy_hp>0 then
   select ord into v_ord from jsonb_array_elements(v_combat->'initiative') with ordinality as e(item,ord) where (item->>'id')::bigint=v_id;
   select p.id into v_next from jsonb_array_elements(v_combat->'initiative') with ordinality as e(item,ord) join public.players p on p.id=(item->>'id')::bigint where e.ord>v_ord and p.hp>0 order by e.ord limit 1;
   if v_next is null then
    -- The enemy acts once after the party round.
    v_roll:=floor(random()*20)::int+1;
    if v_roll=20 or (v_roll<>1 and v_roll+coalesce((v_combat->>'attack_bonus')::int,4)>=v_ac) then
     v_dmg:=floor(random()*coalesce((v_combat->>'damage_die')::int,6))::int+coalesce((v_combat->>'damage_min')::int,3);
     update public.players set hp=greatest(0,hp-v_dmg) where id=v_id;
     v_log:=v_log||'；敌人反击 '||v_name||'，伤害 '||v_dmg;
    else v_log:=v_log||'；敌人反击未命中'; end if;
    select p.id into v_next from jsonb_array_elements(v_combat->'initiative') with ordinality as e(item,ord) join public.players p on p.id=(item->>'id')::bigint where p.hp>0 order by e.ord limit 1;
    v_combat:=jsonb_set(v_combat,'{round}',to_jsonb((v_combat->>'round')::int+1));
   end if;
   if v_next is null then v_log:=v_log||'；队伍全员倒地'; end if;
   v_combat:=jsonb_set(v_combat,'{turn}',coalesce(to_jsonb(v_next),'null'::jsonb));
  else update public.players set gold=gold+5 where room_code=v_code and user_id is not null; v_log:=v_log||'；敌人倒下，队员各获得 5 金币'; end if;
  v_state:=jsonb_set(v_state,'{combat}',v_combat);
 elsif p_action='heal' then
  if not (v_state->>'started')::boolean then raise exception 'NOT_STARTED'; end if;
  v_target:=coalesce((p_payload->>'target')::bigint,v_id);
  if not exists(select 1 from public.players where id=v_target and room_code=v_code and user_id is not null) then raise exception 'INVALID_TARGET'; end if;
  if not (select inventory ? '治疗药水' from public.players where id=v_id) then raise exception 'NO_POTION'; end if;
  update public.players set inventory=inventory-'治疗药水' where id=v_id;
  update public.players set hp=least(max_hp,hp+8),death_failures=0,death_successes=0 where id=v_target and hp>=0;
  if v_state->'combat' is not null and v_state->'combat'<>'null'::jsonb and v_state#>'{combat,turn}'='null'::jsonb then v_state:=jsonb_set(v_state,'{combat,turn}',to_jsonb(v_target)); end if;
  v_log:='使用治疗药水，恢复 8 HP。';
 elsif p_action='buy' then
  if not (v_state->>'started')::boolean then raise exception 'NOT_STARTED'; end if;
  if p_payload->>'item'='治疗药水' then
   update public.players set gold=gold-10,inventory=inventory||'"治疗药水"'::jsonb where id=v_id and gold>=10;
   if not found then raise exception 'NOT_ENOUGH_GOLD'; end if;
   v_log:='购买治疗药水，花费 10 金币。';
  elsif p_payload->>'item'='盾牌' then
   if (select inventory ? '盾牌' or equipment ? '盾牌' from public.players where id=v_id) then raise exception 'ALREADY_OWNED'; end if;
   update public.players set gold=gold-30,inventory=inventory||'"盾牌"'::jsonb where id=v_id and gold>=30;
   if not found then raise exception 'NOT_ENOUGH_GOLD'; end if;
   v_log:='购买盾牌，花费 30 金币。';
  else raise exception 'UNKNOWN_ITEM'; end if;
 elsif p_action='equip' then
  if p_payload->>'item'<>'盾牌' or not (select inventory ? '盾牌' from public.players where id=v_id) then raise exception 'ITEM_NOT_IN_BAG'; end if;
  update public.players set inventory=inventory-'盾牌',equipment=equipment||'"盾牌"'::jsonb,ac=ac+1 where id=v_id;
  v_log:='装备盾牌，AC +1。';
 elsif p_action='death_save' then
  if v_hp<>0 then raise exception 'NOT_DOWNED'; end if;
  v_roll:=floor(random()*20)::int+1;
  if v_roll=20 then update public.players set hp=1,death_failures=0,death_successes=0 where id=v_id;
   if v_state->'combat' is not null and v_state->'combat'<>'null'::jsonb and v_state#>'{combat,turn}'='null'::jsonb then v_state:=jsonb_set(v_state,'{combat,turn}',to_jsonb(v_id)); end if;
  elsif v_roll=1 then update public.players set death_failures=least(3,death_failures+2) where id=v_id;
  elsif v_roll>=10 then update public.players set death_successes=least(3,death_successes+1) where id=v_id;
  else update public.players set death_failures=least(3,death_failures+1) where id=v_id; end if;
  v_log:='死亡豁免 D20='||v_roll||case when v_roll=20 then '，恢复 1 HP' else '' end;
 else raise exception 'UNKNOWN_ACTION'; end if;
 update public.game_states set state=jsonb_set(v_state,'{version}',to_jsonb(coalesce((v_state->>'version')::int,0)+1)),updated_at=now() where room_code=v_code;
 if v_log is not null then insert into public.messages(room_code,sender,body,kind) values(v_code,v_name,v_log,p_action); end if;
 return public.party_snapshot(v_code);
end $$;
revoke all on function public.party_command(text,text,jsonb) from public,anon;
grant execute on function public.party_command(text,text,jsonb) to authenticated;
revoke all on function public.party_notify() from public,anon,authenticated;

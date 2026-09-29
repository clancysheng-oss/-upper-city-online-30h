create or replace function public.party_area(p_code text,p_action text,p_payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare
 v_code text:=upper(trim(coalesce(p_code,''))); v_uid uuid:=auth.uid(); v_actor public.players%rowtype;
 v_comp public.players%rowtype; v_target public.players%rowtype; v_state jsonb; v_combat jsonb;
 v_area public.uc_areas%rowtype; v_npc public.uc_npcs%rowtype; v_quest public.uc_quests%rowtype;
 v_item public.campaign_items%rowtype; v_battle public.uc_battles%rowtype;
 v_area_id text:=p_payload->>'area'; v_log text; v_record jsonb; v_stage jsonb; v_option jsonb;
 v_index integer; v_step integer; v_roll integer; v_bonus integer; v_dc integer; v_stat integer;
 v_hp integer; v_dmg integer; v_enemy jsonb; v_enemies jsonb; v_initiative jsonb; v_turn bigint;
 v_foe jsonb; v_result jsonb; v_outcome text; v_key text;
begin
 if v_uid is null then raise exception 'AUTH_REQUIRED'; end if;
 perform 1 from public.rooms where code=v_code for update;
 if not found then raise exception 'ROOM_NOT_FOUND'; end if;
 select * into v_actor from public.players where room_code=v_code and user_id=v_uid;
 if not found then raise exception 'NOT_MEMBER'; end if;
 select state into v_state from public.game_states where room_code=v_code for update;
 if not coalesce((v_state->>'started')::boolean,false) then raise exception 'NOT_STARTED'; end if;
 v_combat:=v_state->'combat';
 if p_action in ('companion_attack','companion_skill') then
   select * into v_comp from public.players where room_code=v_code and is_companion and id=coalesce((p_payload->>'companion')::bigint,0);
   if not found then raise exception 'NO_COMPANION'; end if;
   if v_combat is null or v_combat='null'::jsonb or coalesce((v_combat->>'hp')::int,0)<=0 then raise exception 'NO_COMBAT'; end if;
   if (v_combat->>'turn')::bigint<>v_comp.id then raise exception 'NOT_COMPANION_TURN'; end if;
   if v_comp.hp<=0 or v_comp.death_failures>=3 then raise exception 'DOWNED'; end if;
   v_index:=public.campaign_enemy_index(v_combat->'enemies',-coalesce((p_payload->>'enemy')::int,-1)-1);
   v_foe:=v_combat->'enemies'->v_index;
   v_roll:=floor(random()*20)::int+1;
   v_bonus:=4+(v_comp.level-1)/4+case when (v_combat->>'round')::int=1 then 2 else 0 end+case when p_action='companion_skill' then 1 else 0 end;
   if p_action='companion_skill' then
     if v_comp.ability_charges<1 then raise exception 'NO_ABILITY_CHARGES'; end if;
     update public.players set ability_charges=ability_charges-1 where id=v_comp.id;
   end if;
   v_dmg:=case when v_roll=1 or (v_roll<>20 and v_roll+v_bonus<(v_foe->>'ac')::int) then 0 else floor(random()*8)::int+1+v_bonus+case when p_action='companion_skill' then 8 else 3 end+case when v_roll=20 then floor(random()*8)::int+1 else 0 end end;
   v_hp:=greatest(0,(v_foe->>'hp')::int-v_dmg);
   v_combat:=jsonb_set(v_combat,array['enemies',v_index::text,'hp'],to_jsonb(v_hp));
   v_combat:=jsonb_set(v_combat,'{hp}',to_jsonb(public.campaign_enemy_hp(v_combat->'enemies')));
   v_log:=v_comp.name||case when p_action='companion_skill' then '使用主动能力「棱光箭」' else '射击' end||' → '||(v_foe->>'name')||' D20='||v_roll||'，伤害 '||v_dmg;
   v_result:=public.campaign_finish_turn(v_code,v_combat,v_comp.id);
   v_state:=jsonb_set(v_state,'{combat}',v_result->'combat');
   v_log:=v_log||coalesce(v_result->>'log','');
 elsif p_action='area_use' then
   select * into v_item from public.campaign_items where name=p_payload->>'item' and merchant='wonders' and slot='consumable';
   if not found or not (v_actor.inventory ? v_item.name) then raise exception 'ITEM_NOT_IN_BAG'; end if;
   if v_item.effect in ('heal','heal20') then
     select * into v_target from public.players where room_code=v_code and id=coalesce((p_payload->>'target')::bigint,v_actor.id) and (user_id is not null or is_companion);
     if not found or v_target.death_failures>=3 then raise exception 'INVALID_TARGET'; end if;
     update public.players set hp=least(max_hp,hp+case when v_item.effect='heal20' then 20 else 14 end),death_failures=0,death_successes=0 where id=v_target.id;
     v_log:=v_actor.name||'给'||v_target.name||'使用'||v_item.name||'，恢复生命。';
   elsif v_item.effect in ('ward','damage','damage20') then
     if v_combat is null or v_combat='null'::jsonb or (v_combat->>'hp')::int<=0 then raise exception 'NO_COMBAT'; end if;
     if (v_combat->>'turn')::bigint<>v_actor.id then raise exception 'NOT_YOUR_TURN'; end if;
     if v_actor.hp<=0 then raise exception 'DOWNED'; end if;
     if v_item.effect='ward' then
       select * into v_target from public.players where room_code=v_code and id=coalesce((p_payload->>'target')::bigint,v_actor.id) and (user_id is not null or is_companion);
       if not found then raise exception 'INVALID_TARGET'; end if;
       v_combat:=jsonb_set(v_combat,'{wards}',jsonb_set(coalesce(v_combat->'wards','{}'::jsonb),array[v_target.id::text],'4'::jsonb,true));
       v_log:=v_actor.name||'为'||v_target.name||'展开护盾卷轴，下一次受攻击 AC +4。';
     else
       v_index:=public.campaign_enemy_index(v_combat->'enemies',-coalesce((p_payload->>'enemy')::int,-1)-1);
       v_foe:=v_combat->'enemies'->v_index;
       v_roll:=floor(random()*20)::int+1; v_bonus:=floor(((v_actor.stats->>3)::int-10)/2.0)::int+2;
       v_dmg:=case when v_roll=1 or (v_roll<>20 and v_roll+v_bonus<(v_foe->>'ac')::int) then 0 else (case when v_item.effect='damage20' then 20 else 12 end)+floor(random()*7)::int+case when v_roll=20 then 8 else 0 end end;
       v_combat:=jsonb_set(v_combat,array['enemies',v_index::text,'hp'],to_jsonb(greatest(0,(v_foe->>'hp')::int-v_dmg)));
       v_combat:=jsonb_set(v_combat,'{hp}',to_jsonb(public.campaign_enemy_hp(v_combat->'enemies')));
       v_log:=v_actor.name||'使用'||v_item.name||' → '||(v_foe->>'name')||' D20='||v_roll||'，伤害 '||v_dmg;
     end if;
     v_result:=public.campaign_finish_turn(v_code,v_combat,v_actor.id);
     v_state:=jsonb_set(v_state,'{combat}',v_result->'combat');
     v_log:=v_log||coalesce(v_result->>'log','');
   else raise exception 'UNKNOWN_ITEM_EFFECT'; end if;
   update public.players set inventory=public.campaign_remove_one(inventory,v_item.name) where id=v_actor.id;
 else
   select * into v_area from public.uc_areas where id=v_area_id;
   if not found then raise exception 'UNKNOWN_AREA'; end if;
   if (v_state->>'chapter')::int<v_area.unlock_chapter then raise exception 'AREA_LOCKED'; end if;
   if v_combat is not null and v_combat<>'null'::jsonb and coalesce((v_combat->>'hp')::int,0)>0 then raise exception 'COMBAT_ACTIVE'; end if;
   if p_action='area_talk' then
     select * into v_npc from public.uc_npcs where id=p_payload->>'npc' and area=v_area.id;
     if not found then raise exception 'UNKNOWN_NPC'; end if;
     v_index:=coalesce((p_payload->>'topic')::int,-1);
     if v_index<0 or v_index>=jsonb_array_length(v_npc.topics) then raise exception 'INVALID_TOPIC'; end if;
     v_stage:=v_npc.topics->v_index;
     v_step:=coalesce((p_payload->>'choice')::int,-1);
     if v_step<0 or v_step>=jsonb_array_length(v_stage->'options') then raise exception 'INVALID_DIALOGUE_CHOICE'; end if;
     v_option:=v_stage->'options'->v_step;
     v_key:=v_npc.id||':'||v_index||':'||v_step;
     v_state:=jsonb_set(v_state,'{area_dialogue}',coalesce(v_state->'area_dialogue','[]'::jsonb)||jsonb_build_array(jsonb_build_object('npc',v_npc.id,'topic',v_index,'choice',v_step,'reply',v_option->>'reply','follow',v_option->>'follow')));
     v_state:=jsonb_set(v_state,'{area_attitudes}',jsonb_set(coalesce(v_state->'area_attitudes','{}'::jsonb),array[v_npc.id],to_jsonb(greatest(-5,least(5,coalesce((v_state->'area_attitudes'->>v_npc.id)::int,0)+coalesce((v_option->>'attitude')::int,0)))),true));
     if length(coalesce(v_option->>'flag',''))>0 and not coalesce(v_state->'flags','[]'::jsonb) ? (v_option->>'flag') then
       v_state:=jsonb_set(v_state,'{flags}',coalesce(v_state->'flags','[]'::jsonb)||to_jsonb(v_option->>'flag'));
     end if;
     v_log:=v_npc.name||'：「'||(v_stage->>'prompt')||'」 队伍：「'||(v_option->>'label')||'」 '||(v_option->>'reply')||' '||(v_option->>'follow');
   elsif p_action='area_inspect' then
     v_index:=coalesce((p_payload->>'place')::int,-1);
     if v_index<0 or v_index>=jsonb_array_length(v_area.places) then raise exception 'INVALID_PLACE'; end if;
     v_key:=v_area.id||':'||v_index;
     if coalesce(v_state->'area_inspected','[]'::jsonb) ? v_key then raise exception 'ALREADY_INSPECTED'; end if;
     v_roll:=floor(random()*20)::int+1;
     v_bonus:=floor(((v_actor.stats->>3)::int-10)/2.0)::int+case when v_actor.class_name in ('游荡者','法师') then 2 else 0 end;
     v_dc:=12+v_area.unlock_chapter/5;
     v_state:=jsonb_set(v_state,'{area_inspected}',coalesce(v_state->'area_inspected','[]'::jsonb)||to_jsonb(v_key));
     v_log:=(v_area.places->v_index->>0)||' · 调查 D20='||v_roll||'+'||v_bonus||' / DC '||v_dc||'：'||case when v_roll=20 or (v_roll<>1 and v_roll+v_bonus>=v_dc) then v_area.places->v_index->>1 else '现场有痕迹，但还不足以锁定来源；可以继续找 NPC 核对。' end;
     if v_roll=20 or (v_roll<>1 and v_roll+v_bonus>=v_dc) then
       v_state:=jsonb_set(v_state,'{clues}',coalesce(v_state->'clues','[]'::jsonb)||to_jsonb(v_area.places->v_index->>0));
     end if;
   elsif p_action in ('area_eat','area_drink') then
     if v_area.id<>'kegs' then raise exception 'TAVERN_ONLY'; end if;
     v_dc:=case when p_action='area_eat' then 6 else 4 end;
     update public.players set gold=gold-v_dc,hp=least(max_hp,hp+case when p_action='area_eat' then 10 else 5 end) where id=v_actor.id and gold>=v_dc and hp>0;
     if not found then raise exception 'NOT_ENOUGH_GOLD_OR_DOWNED'; end if;
     v_log:=v_actor.name||case when p_action='area_eat' then '吃了瑟拉的炖菜，支付 6 金币，恢复 10 HP。' else '喝了玛拉的热酒，支付 4 金币，恢复 5 HP。' end;
   elsif p_action='area_quest' then
     select * into v_quest from public.uc_quests where id=p_payload->>'quest';
     if not found then raise exception 'UNKNOWN_QUEST'; end if;
     v_record:=v_state->'side_quests'->v_quest.id;
     if v_record is null then
       if v_quest.area<>v_area.id then raise exception 'WRONG_AREA'; end if;
       v_record:=jsonb_build_object('status','进行中','step',0,'outcome',null);
       v_log:='接取支线：'||v_quest.name||'。'||v_quest.description;
     else
       if v_record->>'status'='已完成' then raise exception 'QUEST_COMPLETE'; end if;
       if v_record->>'status'='失败' then raise exception 'QUEST_FAILED'; end if;
       v_step:=(v_record->>'step')::int;
       v_stage:=v_quest.stages->v_step;
       if v_stage is null or v_stage->>'area'<>v_area.id then raise exception 'WRONG_AREA'; end if;
       if v_stage ? 'npc' and not exists(select 1 from jsonb_array_elements(coalesce(v_state->'area_dialogue','[]'::jsonb)) d where d->>'npc'=v_stage->>'npc') then raise exception 'TALK_TO_NPC_FIRST'; end if;
       if v_stage ? 'battle' then
         select * into v_battle from public.uc_battles where id=v_stage->>'battle';
         if v_battle.id is null then raise exception 'UNKNOWN_BATTLE'; end if;
         if not coalesce((v_record->>'battle_started')::boolean,false) then
           select jsonb_agg(jsonb_build_object('id',id,'roll',roll) order by roll desc,id),(array_agg(id order by roll desc,id))[1] into v_initiative,v_turn from (select id,floor(random()*20)::int+1 roll from public.players where room_code=v_code and (user_id is not null or is_companion) and hp>0 and death_failures<3) i;
           if v_turn is null then raise exception 'PARTY_DOWNED'; end if;
           v_enemies:='[]'::jsonb;
           for v_foe in select value from jsonb_array_elements(v_battle.foes) loop
             v_hp:=(v_foe->>1)::int+greatest(0,(select count(*) from public.players where room_code=v_code and user_id is not null)-2)*5;
             v_enemies:=v_enemies||jsonb_build_array(jsonb_build_object('name',v_foe->>0,'hp',v_hp,'max_hp',v_hp,'ac',(v_foe->>2)::int,'attack_bonus',(v_foe->>3)::int,'damage_min',(v_foe->>4)::int,'damage_die',(v_foe->>5)::int,'special',v_foe->>6));
           end loop;
           v_state:=jsonb_set(v_state,'{combat}',jsonb_build_object('name',v_battle.name,'side_quest',v_quest.id,'enemies',v_enemies,'hp',public.campaign_enemy_hp(v_enemies),'max_hp',public.campaign_enemy_hp(v_enemies),'turn',v_turn,'initiative',v_initiative,'round',1,'wards','{}'::jsonb));
           v_record:=jsonb_set(v_record,'{battle_started}','true'::jsonb);
           v_log:='支线战斗开始：'||v_battle.name||'。'||v_battle.intro;
         elsif v_combat is null or v_combat='null'::jsonb or v_combat->>'side_quest'<>v_quest.id or (v_combat->>'hp')::int>0 then raise exception 'BATTLE_NOT_WON';
         else v_record:=jsonb_set(jsonb_set(v_record,'{step}',to_jsonb(v_step+1)),'{status}',to_jsonb('可交付'::text)); v_log:='已完成战斗：'||v_battle.name||'。返回委托人交付证据。'; end if;
       elsif coalesce((v_stage->>'finish')::boolean,false) then
         if v_record->>'status'<>'可交付' then raise exception 'QUEST_NOT_READY'; end if;
         v_record:=jsonb_set(v_record,'{status}',to_jsonb('已完成'::text));
         update public.players set gold=gold+(v_quest.reward->>'gold')::int,experience=experience+(v_quest.reward->>'xp')::int,inventory=inventory||to_jsonb(v_quest.reward->>'item') where room_code=v_code and user_id is not null;
         v_log:='支线完成：'||v_quest.name||'。全队各获得 '||(v_quest.reward->>'gold')||' 金币、'||(v_quest.reward->>'xp')||' 经验及 '||(v_quest.reward->>'item')||'。';
         if v_quest.id='gate' and v_record->>'outcome'='protect' and not exists(select 1 from public.players where room_code=v_code and is_companion) then
           insert into public.players(room_code,name,class_name,is_companion,hp,max_hp,ac,stats,inventory,equipment,gold,level,ability_charges) values(v_code,'伊莉娅·棱光','游侠',true,28,28,15,'[12,17,14,13,15,12]'::jsonb,'[]'::jsonb,'["夜巡长弓"]'::jsonb,0,public.campaign_level((v_state->>'chapter')::int),2);
           v_log:=v_log||' 新伙伴已加入队伍：伊莉娅·棱光。';
         end if;
       else
         if v_stage ? 'options' then
           v_index:=coalesce((p_payload->>'option')::int,-1);
           if v_index<0 or v_index>=jsonb_array_length(v_stage->'options') then raise exception 'INVALID_QUEST_OPTION'; end if;
           v_option:=v_stage->'options'->v_index;
           v_outcome:=v_option->>2;
           v_log:=v_option->>1;
           if jsonb_array_length(v_option)>3 then v_stage:=jsonb_set(v_stage,'{skill}',to_jsonb(v_option->>3));v_stage:=jsonb_set(v_stage,'{dc}',v_option->4); end if;
         else v_log:=v_stage->>'text'; end if;
         if v_stage ? 'skill' then
           v_stat:=case v_stage->>'skill' when '运动' then 0 when '潜行' then 1 when '调查' then 3 when '奥秘' then 3 when '洞悉' then 4 when '求生' then 4 when '察觉' then 4 else 5 end;
           v_bonus:=floor(((v_actor.stats->>v_stat)::int-10)/2.0)::int+case when (v_actor.class_name='游荡者' and v_stage->>'skill' in ('调查','潜行','欺骗')) or (v_actor.class_name='法师' and v_stage->>'skill'='奥秘') or (v_actor.class_name='牧师' and v_stage->>'skill'='洞悉') or (v_actor.class_name='游侠' and v_stage->>'skill' in ('求生','察觉')) or (v_actor.class_name in ('圣武士','吟游诗人') and v_stage->>'skill'='说服') then 2 else 0 end;
           v_roll:=floor(random()*20)::int+1; v_dc:=(v_stage->>'dc')::int;
           v_log:=(v_stage->>'skill')||' D20='||v_roll||'+'||v_bonus||' / DC '||v_dc||case when v_roll=20 then ' 大成功' when v_roll=1 then ' 大失败' else '' end||'：'||case when v_roll=1 or (v_roll<>20 and v_roll+v_bonus<v_dc) then '暂未成功；可以再调查或由其他队员尝试。' else v_log end;
           if v_roll=1 or (v_roll<>20 and v_roll+v_bonus<v_dc) then
             update public.game_states set state=jsonb_set(v_state,'{version}',to_jsonb(coalesce((v_state->>'version')::int,0)+1)),updated_at=now() where room_code=v_code;
             insert into public.messages(room_code,sender,body,kind) values(v_code,v_actor.name,v_log,'area_quest');
             return public.party_snapshot(v_code);
           end if;
         end if;
         if v_outcome is not null then
           v_record:=jsonb_set(v_record,'{outcome}',to_jsonb(v_outcome));
           if v_outcome in ('bribe','sell') then
             update public.players set gold=gold+8 where id=v_actor.id;
             v_log:=v_log||' 私下收取 8 金币；委托人将记住这个决定。';
           elsif v_outcome in ('protect','guide','escort','patients','anonymous') then
             update public.players set experience=experience+8 where id=v_actor.id;
             v_log:=v_log||' 额外获得 8 经验。';
           end if;
           if v_outcome in ('threat','reveal','sell','bribe') then
             v_state:=jsonb_set(v_state,'{area_attitudes}',jsonb_set(coalesce(v_state->'area_attitudes','{}'::jsonb),array[v_quest.giver],to_jsonb(greatest(-5,coalesce((v_state->'area_attitudes'->>v_quest.giver)::int,0)-2)),true));
           end if;
           if v_quest.id='star' and v_outcome='bribe' then
             v_record:=jsonb_set(v_record,'{status}',to_jsonb('失败'::text));
             v_log:=v_log||' 星盘零件被转卖，委托失败。';
           end if;
         end if;
         if v_record->>'status'='失败' then
           v_state:=jsonb_set(v_state,'{side_quests}',jsonb_set(coalesce(v_state->'side_quests','{}'::jsonb),array[v_quest.id],v_record,true));
           update public.game_states set state=jsonb_set(v_state,'{version}',to_jsonb(coalesce((v_state->>'version')::int,0)+1)),updated_at=now() where room_code=v_code;
           insert into public.messages(room_code,sender,body,kind) values(v_code,v_actor.name,v_log,'area_quest');
           return public.party_snapshot(v_code);
         end if;
         v_step:=v_step+1;
         v_record:=jsonb_set(v_record,'{step}',to_jsonb(v_step));
         if coalesce((v_quest.stages->v_step->>'finish')::boolean,false) then v_record:=jsonb_set(v_record,'{status}',to_jsonb('可交付'::text)); end if;
       end if;
     end if;
     v_state:=jsonb_set(v_state,'{side_quests}',jsonb_set(coalesce(v_state->'side_quests','{}'::jsonb),array[v_quest.id],v_record,true));
   else raise exception 'UNKNOWN_AREA_ACTION'; end if;
 end if;
 update public.game_states set state=jsonb_set(v_state,'{version}',to_jsonb(coalesce((v_state->>'version')::int,0)+1)),updated_at=now() where room_code=v_code;
 insert into public.messages(room_code,sender,body,kind) values(v_code,v_actor.name,left(v_log,1000),p_action);
 return public.party_snapshot(v_code);
end $$;

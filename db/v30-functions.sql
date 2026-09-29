-- Server-owned chapter interactions extend the existing room state and combat.
create table if not exists public.campaign_deep_chapters (
 chapter_id integer primary key references public.campaign_chapters(id),
 scene text not null, focus text not null, npc text not null, role text not null,
 lines jsonb not null, object_name text not null, secret text not null, skill text not null, dc integer not null
);
alter table public.campaign_deep_chapters enable row level security;
revoke all on public.campaign_deep_chapters from public,anon,authenticated;

create or replace function public.party_deep(p_code text,p_action text,p_payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare
 v_code text:=upper(trim(coalesce(p_code,''))); v_actor public.players%rowtype;
 v_state jsonb; v_data public.campaign_deep_chapters%rowtype; v_deep jsonb; v_key text;
 v_done jsonb; v_idx integer; v_roll integer; v_bonus integer; v_dc integer; v_success boolean;
 v_log text; v_combat jsonb; v_foe jsonb; v_enemies jsonb; v_hp integer; v_result jsonb;
 v_comp public.players%rowtype; v_approval integer; v_slot integer;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
 perform 1 from public.rooms where code=v_code for update;
 if not found then raise exception 'ROOM_NOT_FOUND'; end if;
 select * into v_actor from public.players where room_code=v_code and user_id=auth.uid();
 if not found then raise exception 'NOT_MEMBER'; end if;
 select state into v_state from public.game_states where room_code=v_code for update;
 if not coalesce((v_state->>'started')::boolean,false) then raise exception 'NOT_STARTED'; end if;
 v_deep:='{"talk":{},"inspected":{},"storyFlags":{},"companionApproval":{},"route":{},"explorationFlags":{},"combat":{}}'::jsonb||coalesce(v_state->'deep','{}'::jsonb);
 v_key:=coalesce(v_state->>'chapter','0');
 select * into v_data from public.campaign_deep_chapters where chapter_id=v_key::integer;
 if not found then raise exception 'CHAPTER_UNAVAILABLE'; end if;
 v_combat:=v_state->'combat';

 if p_action='talk' then
   v_idx:=coalesce((p_payload->>'choice')::integer,-1);
   if v_idx not between 0 and 2 then raise exception 'INVALID_CHOICE'; end if;
   v_done:=coalesce(v_deep->'talk'->v_key,'[]'::jsonb);
   if v_done ? v_idx::text then raise exception 'ALREADY_DISCUSSSED'; end if;
   v_done:=v_done||to_jsonb(v_idx::text);
   v_deep:=jsonb_set(v_deep,array['talk',v_key],v_done,true);
   v_log:=v_data.npc||'：'||(v_data.lines->>v_idx);
   v_deep:=jsonb_set(v_deep,array['storyFlags',v_key||'_witness_'||v_idx],to_jsonb(true),true);
   -- Persistent, contextual approval. Disapproval never removes a companion.
   select * into v_comp from public.players where room_code=v_code and is_companion order by id limit 1;
   if found then
     v_approval:=coalesce((v_deep#>>array['companionApproval',v_comp.id::text])::integer,0)
       +case v_idx when 0 then 5 when 1 then 0 else -10 end;
     v_deep:=jsonb_set(v_deep,array['companionApproval',v_comp.id::text],to_jsonb(v_approval),true);
     v_log:=v_log||case v_idx when 0 then '；'||v_comp.name||'赞同你倾听证人（态度 +5）'
       when 2 then '；'||v_comp.name||'反对威胁证人（态度 -10）' else '' end;
   end if;
 elsif p_action='inspect' then
   if coalesce(v_deep#>>array['inspected',v_key],'false')='true' then raise exception 'ALREADY_EXPLORED'; end if;
   v_idx:=case v_data.skill when '运动' then 0 when '潜行' then 1 when '调查' then 3 when '奥秘' then 3 when '洞悉' then 4 when '察觉' then 4 when '求生' then 4 else 5 end;
   v_bonus:=floor(((v_actor.stats->>v_idx)::integer-10)/2.0)::integer
     +case when (v_actor.class_name='游荡者' and v_data.skill in ('调查','潜行'))
       or (v_actor.class_name='法师' and v_data.skill='奥秘')
       or (v_actor.class_name='游侠' and v_data.skill in ('求生','察觉'))
       or (v_actor.class_name='战士' and v_data.skill='运动')
       or (v_actor.class_name='牧师' and v_data.skill='洞悉') then 2 else 0 end;
   v_roll:=floor(random()*20)::integer+1;
   v_success:=v_roll=20 or (v_roll<>1 and v_roll+v_bonus>=v_data.dc);
   v_deep:=jsonb_set(v_deep,array['inspected',v_key],'true'::jsonb,true);
   v_log:=v_data.object_name||' · '||v_data.skill||' D20='||v_roll||'+'||v_bonus||' / DC '||v_data.dc||'：';
   if v_success then
     v_deep:=jsonb_set(v_deep,array['explorationFlags',v_key||'_secret'],'true'::jsonb,true);
     v_state:=jsonb_set(v_state,'{clues}',coalesce(v_state->'clues','[]'::jsonb)||to_jsonb(v_data.secret));
     v_log:=v_log||'发现隐藏线索：'||v_data.secret;
     if v_combat is not null and v_combat<>'null'::jsonb and coalesce((v_combat->>'hp')::integer,0)>0 then
       v_enemies:=v_combat->'enemies';
       for v_slot in 0..jsonb_array_length(v_enemies)-1 loop
         v_foe:=v_enemies->v_slot;
         v_enemies:=jsonb_set(v_enemies,array[v_slot::text,'ac'],to_jsonb(greatest(8,(v_foe->>'ac')::integer-1)));
       end loop;
       v_combat:=jsonb_set(v_combat,'{enemies}',v_enemies);
       v_state:=jsonb_set(v_state,'{combat}',v_combat);
       v_log:=v_log||'；提前查明阵地，敌方本场 AC -1。';
     end if;
   else v_log:=v_log||'找到可辨认的痕迹，但更深的秘密仍藏在现场。'; end if;
 elsif p_action='interject' then
   select * into v_comp from public.players where room_code=v_code and is_companion order by id limit 1;
   if not found or v_key::integer not in (3,5,9,12,16,18,20,23,26,28) then raise exception 'NO_INTERJECTION'; end if;
   if coalesce(v_deep#>>array['interjection',v_key],'')<>'' then raise exception 'ALREADY_ANSWERED'; end if;
   v_idx:=coalesce((p_payload->>'choice')::integer,-1);
   if v_idx not between 0 and 2 then raise exception 'INVALID_CHOICE'; end if;
   v_approval:=coalesce((v_deep#>>array['companionApproval',v_comp.id::text])::integer,0)
     +case v_idx when 0 then 5 when 1 then -5 else 0 end;
   v_deep:=jsonb_set(v_deep,'{interjection}',coalesce(v_deep->'interjection','{}'::jsonb));
   v_deep:=jsonb_set(v_deep,array['interjection',v_key],to_jsonb(v_idx),true);
   v_deep:=jsonb_set(v_deep,array['companionApproval',v_comp.id::text],to_jsonb(v_approval),true);
   v_log:=case v_idx when 0 then '你支持了'||v_comp.name||'，伙伴态度 +5。'
    when 1 then '你反驳了'||v_comp.name||'，伙伴态度 -5。'
    else '你保持沉默，'||v_comp.name||'记下了你的迟疑。' end;
 elsif p_action='route' then
   if not v_actor.is_host then raise exception 'HOST_ONLY'; end if;
   if coalesce(v_deep#>>array['route',v_key],'')<>'' then raise exception 'ROUTE_CHOSEN'; end if;
   v_idx:=coalesce((p_payload->>'choice')::integer,-1);
   if v_idx not between 0 and 2 then raise exception 'INVALID_CHOICE'; end if;
   if v_idx=2 and coalesce(p_payload->>'class','')<>v_actor.class_name then raise exception 'CLASS_REQUIRED'; end if;
   v_roll:=floor(random()*20)::integer+1;
   v_bonus:=floor(((v_actor.stats->>case v_actor.class_name when '法师' then 3 when '牧师' then 4 when '游侠' then 4 when '吟游诗人' then 5 when '圣武士' then 5 when '游荡者' then 1 else 0 end)::integer-10)/2.0)::integer+2;
   v_success:=v_idx<>1 and (v_roll=20 or (v_roll<>1 and v_roll+v_bonus>=v_data.dc-2
     -case when coalesce(v_deep#>>array['explorationFlags',v_key||'_secret'],'false')='true' then 3 else 0 end));
   v_deep:=jsonb_set(v_deep,array['route',v_key],to_jsonb(case when v_idx=1 then 'force' when v_success then 'peace' else 'failed' end),true);
   v_log:=case when v_idx=1 then '队伍决定正面交锋；线索与证人仍可留给后续章节。'
    when v_success then 'D20='||v_roll||'+'||v_bonus||'：以证据与交涉解决了冲突。'
    else 'D20='||v_roll||'+'||v_bonus||'：对方未接受条件；仍可通过现有路线继续。' end;
   if v_idx=2 and v_success then
     v_log:=v_log||case v_actor.class_name
       when '游荡者' then ' 你找到避开正门的隐蔽路线。'
       when '法师' then ' 你辨认出可中止敌方机关的符文。'
       when '牧师' then ' 伤者得以稳定，愿意为队伍作证。'
       when '游侠' then ' 脚印让你先一步发现伏击。'
       when '吟游诗人' then ' 互相矛盾的证词让对方放下武器。'
       when '圣武士' then ' 公开誓言换来了证人的信任。'
       else ' 你在守备阵线找到突破口。' end;
     v_deep:=jsonb_set(v_deep,array['storyFlags',v_key||'_class_'||v_actor.class_name],'true'::jsonb,true);
   end if;
   if v_success and v_combat is not null and v_combat<>'null'::jsonb
      and coalesce((v_combat->>'hp')::integer,0)>0 and coalesce((v_combat->>'round')::integer,0)=1
      and v_key::integer not in (17,28) and not (v_combat ? 'side_quest') then
     v_deep:=jsonb_set(v_deep,array['combat',v_key],jsonb_build_object('combat_required',false,'combat_resolved',true,'combat_skipped',true),true);
     v_state:=jsonb_set(v_state,'{combat}','null'::jsonb);
     v_log:=v_log||' 本场守备遭遇已通过非战斗方式解决，不会重新触发。';
   end if;
   if v_idx=1 then v_deep:=jsonb_set(v_deep,array['storyFlags',v_key||'_force'],'true'::jsonb,true); end if;
 elsif p_action='environment' then
   if v_combat is null or v_combat='null'::jsonb or coalesce((v_combat->>'hp')::integer,0)<=0 then raise exception 'NO_COMBAT'; end if;
   if (v_combat->>'turn')::bigint<>v_actor.id or v_actor.hp<=0 then raise exception 'NOT_YOUR_TURN'; end if;
   v_idx:=coalesce((p_payload->>'object')::integer,-1);
   if v_idx not between 0 and 2 or jsonb_array_length(coalesce(v_combat->'environment','[]'::jsonb))<=v_idx then raise exception 'INVALID_OBJECT'; end if;
   if coalesce((v_combat#>>array['environment',v_idx::text,'used'])::boolean,false) then raise exception 'ALREADY_USED'; end if;
   v_foe:=v_combat->'environment'->v_idx;
   v_enemies:=v_combat->'enemies';
   if (v_foe->>'kind')='blast' then
     for v_slot in 0..jsonb_array_length(v_enemies)-1 loop
       if (v_enemies->v_slot->>'hp')::integer>0 then
         v_hp:=greatest(0,(v_enemies->v_slot->>'hp')::integer-(v_foe->>'amount')::integer);
         v_enemies:=jsonb_set(v_enemies,array[v_slot::text,'hp'],to_jsonb(v_hp));
       end if;
     end loop;
     v_log:=(v_foe->>'name')||'爆发，所有敌人各受 '||(v_foe->>'amount')||' 伤害。';
   elsif (v_foe->>'kind')='cover' then
     v_combat:=jsonb_set(v_combat,array['wards',v_actor.id::text],to_jsonb((v_foe->>'amount')::integer),true);
     v_log:='利用'||(v_foe->>'name')||'，下次受攻击 AC +'||(v_foe->>'amount')||'。';
   elsif (v_foe->>'kind')='push' then
     v_slot:=coalesce((p_payload->>'target')::integer,-1);
     if v_slot<0 or v_slot>=jsonb_array_length(v_enemies) or (v_enemies->v_slot->>'hp')::integer<=0 then raise exception 'INVALID_ENEMY'; end if;
     v_roll:=floor(random()*20)::integer+1;
     v_bonus:=floor(((v_actor.stats->>0)::integer-10)/2.0)::integer+case when v_actor.class_name in ('战士','圣武士') then 2 else 0 end;
     v_hp:=case when v_roll=20 or (v_roll<>1 and v_roll+v_bonus>=12) then 0 else (v_enemies->v_slot->>'hp')::integer end;
     v_enemies:=jsonb_set(v_enemies,array[v_slot::text,'hp'],to_jsonb(v_hp));
     v_log:='利用'||(v_foe->>'name')||'推落'||(v_enemies->v_slot->>'name')||' · 运动 D20='||v_roll||'+'||v_bonus||case when v_hp=0 then '：成功，目标退出战斗。' else '：未能推动。' end;
   elsif (v_foe->>'kind')='block' then
     v_slot:=jsonb_array_length(v_enemies)-1;
     v_enemies:=jsonb_set(v_enemies,array[v_slot::text,'hp'],'0'::jsonb);
     v_log:='关闭'||(v_foe->>'name')||'，最后一队敌方援军无法进入。';
   else raise exception 'INVALID_OBJECT'; end if;
   v_combat:=jsonb_set(v_combat,'{enemies}',v_enemies);
   v_combat:=jsonb_set(v_combat,array['environment',v_idx::text,'used'],'true'::jsonb);
   v_combat:=jsonb_set(v_combat,'{hp}',to_jsonb(public.campaign_enemy_hp(v_enemies)));
   if (v_combat->>'hp')::integer>0 then
     v_result:=public.campaign_finish_turn(v_code,v_combat,v_actor.id);
     v_combat:=v_result->'combat'; v_log:=v_log||coalesce(v_result->>'log','');
   else
     update public.players set gold=gold+12+coalesce((v_state->>'chapter')::integer/5,0)*3
       where room_code=v_code and user_id is not null;
     v_log:=v_log||'；敌方全灭，队员获得战利品金币';
   end if;
   v_state:=jsonb_set(v_state,'{combat}',v_combat);
 else raise exception 'UNKNOWN_DEEP_ACTION'; end if;
 v_state:=jsonb_set(v_state,'{deep}',v_deep);
 update public.game_states set state=jsonb_set(v_state,'{version}',to_jsonb(coalesce((v_state->>'version')::integer,0)+1)),updated_at=now() where room_code=v_code;
 insert into public.messages(room_code,sender,body,kind) values(v_code,v_actor.name,v_log,'deep');
 return public.party_snapshot(v_code);
end $$;
revoke all on function public.party_deep(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.party_deep(text,text,jsonb) to authenticated;

-- Only new encounters are scaled. Old combats and saved checkpoints retain their exact HP.
create or replace function public.campaign_v30_combat() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare v_old jsonb; v_new jsonb; v_enemies jsonb; v_foe jsonb; v_ch integer; v_avg numeric; v_rank integer; v_scale integer; v_hp integer; v_idx integer; v_env jsonb; v_refused bigint;
begin
 v_old:=old.state->'combat'; v_new:=new.state->'combat';
 new.state:=jsonb_set(new.state,'{deep}',
   '{"talk":{},"inspected":{},"storyFlags":{},"companionApproval":{},"route":{},"explorationFlags":{},"combat":{}}'::jsonb
     ||coalesce(new.state->'deep','{}'::jsonb));
 if v_old is not null and v_old<>'null'::jsonb and coalesce((v_old->>'hp')::integer,0)>0
    and v_new is not null and v_new<>'null'::jsonb and coalesce((v_new->>'hp')::integer,0)=0 then
   new.state:=jsonb_set(new.state,array['deep','combat',coalesce(v_old->>'side_quest',new.state->>'chapter','0')],
     jsonb_build_object('combat_required',true,'combat_resolved',true,'combat_skipped',false),true);
 end if;
 if v_new is null or v_new='null'::jsonb or coalesce((v_new->>'hp')::integer,0)<=0
    or (v_old is not null and v_old<>'null'::jsonb and coalesce((v_old->>'hp')::integer,0)>0) then return new; end if;
 v_ch:=coalesce((new.state->>'chapter')::integer,0);
 select coalesce(avg(level),1) into v_avg from public.players where room_code=new.room_code and user_id is not null;
 v_enemies:=v_new->'enemies';
 if v_enemies is null then return new; end if;
 for v_idx in 0..jsonb_array_length(v_enemies)-1 loop
   v_foe:=v_enemies->v_idx;
   v_rank:=case when v_idx=0 and v_ch in (17,28) then 3 when v_idx=0 then 2 else 1 end;
   -- Chapter floor + capped party contribution: returning to early areas remains easier.
   v_scale:=least(5,greatest(0,floor(v_avg-(1+floor(v_ch/5.0)))::integer))
     +case when v_ch>=20 then 2 when v_ch>=10 then 1 else 0 end;
   v_hp:=(v_foe->>'hp')::integer+v_scale*(2+2*v_rank);
   v_foe:=jsonb_set(jsonb_set(v_foe,'{hp}',to_jsonb(v_hp)),'{max_hp}',to_jsonb(v_hp));
   v_foe:=jsonb_set(v_foe,'{attack_bonus}',to_jsonb((v_foe->>'attack_bonus')::integer+floor(v_scale*v_rank/3.0)::integer));
   v_foe:=jsonb_set(v_foe,'{damage_min}',to_jsonb((v_foe->>'damage_min')::integer+floor(v_scale*v_rank/4.0)::integer));
   v_foe:=jsonb_set(v_foe,'{ac}',to_jsonb(least(21,(v_foe->>'ac')::integer+floor(v_scale*v_rank/5.0)::integer)));
   v_enemies:=jsonb_set(v_enemies,array[v_idx::text],v_foe);
 end loop;
 v_env:=case when v_ch>=23 then jsonb_build_array(
   jsonb_build_object('name','火油桶','kind','blast','amount',8,'used',false),
   jsonb_build_object('name','石柱掩体','kind','cover','amount',3,'used',false),
   jsonb_build_object('name','城门闸轮','kind','block','amount',1,'used',false))
  when v_ch>=15 then jsonb_build_array(
   jsonb_build_object('name','火药桶','kind','blast','amount',8,'used',false),
   jsonb_build_object('name','城门机关','kind','cover','amount',3,'used',false),
   jsonb_build_object('name','井壁悬崖','kind','push','amount',0,'used',false))
  else jsonb_build_array(
   jsonb_build_object('name','油桶','kind','blast','amount',6,'used',false),
   jsonb_build_object('name','石墙掩体','kind','cover','amount',2,'used',false),
   jsonb_build_object('name','松动支撑','kind','blast','amount',5,'used',false)) end;
 v_new:=jsonb_set(jsonb_set(v_new,'{enemies}',v_enemies),'{environment}',v_env);
 v_new:=jsonb_set(jsonb_set(v_new,'{hp}',to_jsonb(public.campaign_enemy_hp(v_enemies))),'{max_hp}',to_jsonb(public.campaign_enemy_hp(v_enemies)));
 new.state:=jsonb_set(new.state,array['deep','combat',coalesce(v_new->>'side_quest',v_ch::text)],
   jsonb_build_object('combat_required',true,'combat_resolved',false,'combat_skipped',false),true);
 -- A companion can refuse this fight without leaving the party or losing HP.
 if coalesce(new.state#>>array['deep','storyFlags',(v_ch-1)::text||'_force'],'false')='true'
    and v_ch not in (17,28) then
   select p.id into v_refused from public.players p where p.room_code=new.room_code and p.is_companion
     and coalesce((new.state#>>array['deep','companionApproval',p.id::text])::integer,0)<0 order by p.id limit 1;
   if v_refused is not null then
     v_new:=jsonb_set(v_new,'{refusing}',jsonb_build_array(v_refused));
     v_new:=jsonb_set(v_new,'{initiative}',coalesce((select jsonb_agg(e.item order by e.ord) from jsonb_array_elements(v_new->'initiative') with ordinality e(item,ord) where (e.item->>'id')::bigint<>v_refused),'[]'::jsonb));
     if (v_new->>'turn')::bigint=v_refused then v_new:=jsonb_set(v_new,'{turn}',v_new->'initiative'->0->'id'); end if;
   end if;
 end if;
 new.state:=jsonb_set(new.state,'{combat}',v_new);
 return new;
end $$;
drop trigger if exists campaign_v30_combat on public.game_states;
create trigger campaign_v30_combat before update of state on public.game_states for each row execute function public.campaign_v30_combat();

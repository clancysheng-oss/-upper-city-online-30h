-- Build choices are earned at levels 4, 8 and 12, including existing saves.
create or replace function public.campaign_v4_build_points() returns trigger language plpgsql set search_path=public,pg_temp as $$
declare v_delta integer;
begin
 if new.level>old.level then
  v_delta:=new.level/4-old.level/4;
  if v_delta>0 then new.build:=jsonb_set(coalesce(new.build,'{}'::jsonb),'{points}',to_jsonb(coalesce((new.build->>'points')::integer,0)+v_delta),true);end if;
 end if;
 return new;
end $$;
drop trigger if exists campaign_v4_build_points on public.players;
create trigger campaign_v4_build_points before update of level on public.players for each row execute function public.campaign_v4_build_points();
update public.players set build=jsonb_set(build,'{points}',to_jsonb(greatest(0,level/4-coalesce(jsonb_array_length(build->'feats'),0))),true)
where user_id is not null and not build ? 'points';

create or replace function public.party_v4_world(p_code text,p_action text,p_payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare v_code text:=upper(trim(coalesce(p_code,''))); v_actor public.players%rowtype; v_comp public.players%rowtype; v_item public.campaign_items%rowtype; v_old public.campaign_items%rowtype;
 v_state jsonb; v_log text; v_roll jsonb; v_faction text; v_oldname text;
 v_type text; v_area text; v_dc integer; v_reward integer; v_points integer; v_choice text; v_cost integer; v_route text; v_danger boolean;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
 perform 1 from public.rooms where code=v_code for update;
 if not found then raise exception 'ROOM_NOT_FOUND'; end if;
 select * into v_actor from public.players where room_code=v_code and user_id=auth.uid() for update;
 if not found or not v_actor.is_online or v_actor.last_seen<now()-interval '90 seconds' then raise exception 'RECONNECT_FIRST'; end if;
 if v_actor.race is null then raise exception 'CHOOSE_RACE_FIRST'; end if;
 select state into v_state from public.game_states where room_code=v_code for update;
 if not coalesce((v_state->>'started')::boolean,false) and p_action<>'build' then raise exception 'NOT_STARTED'; end if;
 v_area:=coalesce(v_state->>'current_area','city');
 v_danger:=coalesce((v_state#>>'{combat,hp}')::integer,0)>0 or coalesce((v_state->>'v4_unsafe')::boolean,false);
 if p_action='build' then
  v_choice:=p_payload->>'choice'; v_points:=coalesce((v_actor.build->>'points')::integer,0);
  if v_points<1 then raise exception 'NO_BUILD_POINTS'; end if;
  if v_choice not in ('强韧','武器大师','神射手','奥术增幅','专注大师','技能专家','迅捷步伐','属性训练') or v_actor.build->'feats' ? v_choice then raise exception 'INVALID_FEAT'; end if;
  update public.players set build=jsonb_set(jsonb_set(build,'{points}',to_jsonb(v_points-1),true),'{feats}',coalesce(build->'feats','[]'::jsonb)||to_jsonb(v_choice),true),
   max_hp=max_hp+case when v_choice='强韧' then 5 else 0 end,
   hp=hp+case when v_choice='强韧' then 5 else 0 end,
   stats=case when v_choice='属性训练' then jsonb_set(stats,array[case class_name when '法师' then '3' when '牧师' then '4' when '吟游诗人' then '5' when '游荡者' then '1' when '游侠' then '1' else '0' end],to_jsonb(least(20,(stats->>case class_name when '法师' then 3 when '牧师' then 4 when '吟游诗人' then 5 when '游荡者' then 1 when '游侠' then 1 else 0 end)::integer+2))) else stats end where id=v_actor.id;
  v_log:=v_actor.name||'选择专长：'||v_choice;
 elsif p_action='camp_enter' then
  if v_danger or not v_actor.is_host or v_area not in ('city','kegs','wonders','hall','walls') or v_actor.conditions ? 'jailed' then raise exception 'CAMP_UNSAFE'; end if;
  update public.game_states set state=jsonb_set(v_state,'{v4_camp}','true'::jsonb) where room_code=v_code;
  v_log:=v_actor.name||'带领队伍扎营。';
 elsif p_action='camp_leave' then
  if not v_actor.is_host then raise exception 'HOST_ONLY'; end if;
  update public.game_states set state=jsonb_set(v_state,'{v4_camp}','false'::jsonb) where room_code=v_code;
  v_log:='队伍收起营帐，返回上城区。';
 elsif p_action='short_rest' then
  if v_danger or not coalesce((v_state->>'v4_camp')::boolean,false) or not v_actor.is_host then raise exception 'REST_UNAVAILABLE'; end if;
  if coalesce((v_state->>'v4_short_chapter')::integer,-1)=coalesce((v_state->>'chapter')::integer,0) then raise exception 'SHORT_REST_USED'; end if;
  update public.players set hp=least(max_hp,hp+greatest(2,ceil(max_hp/4.0)::integer)),
   ability_charges=least(2,ability_charges+1) where room_code=v_code and (user_id is not null or is_companion) and hp>0;
  update public.game_states set state=jsonb_set(v_state,'{v4_short_chapter}',to_jsonb((v_state->>'chapter')::integer),true) where room_code=v_code;
  v_log:='队伍短休：恢复部分生命和职业资源。';
 elsif p_action='long_rest' then
  if v_danger or not coalesce((v_state->>'v4_camp')::boolean,false) or not v_actor.is_host then raise exception 'REST_UNAVAILABLE'; end if;
  perform public.party_power_v30_core(v_code,'rest',null,0);
  update public.players set hp=max_hp,death_failures=0,death_successes=0,spell_slots=public.campaign_slots(level),ability_charges=2 where room_code=v_code and is_companion and death_failures<3;
  update public.players set conditions=conditions-'poisoned'-'frightened' where room_code=v_code and (user_id is not null or is_companion);
  v_log:='营地长休：恢复生命、法术位、职业资源，并解除部分状态。';
 elsif p_action='crime' then
  if v_danger or v_actor.conditions ? 'jailed' or v_area='city' and (v_state->>'chapter')::integer<0 then raise exception 'ACTION_UNAVAILABLE'; end if;
  v_type:=p_payload->>'type';
  if v_type not in ('pickpocket','theft','lockpick','trespass','vandalism') then raise exception 'INVALID_CRIME'; end if;
  if coalesce(v_state#>>array['v4_crimes',v_actor.id::text||':'||(v_state->>'chapter')||':'||v_area||':'||v_type],'')<>'' then raise exception 'CRIME_ALREADY_ATTEMPTED'; end if;
  v_dc:=case v_area when 'hall' then 18 when 'wonders' then 16 when 'walls' then 15 else 13 end
    +case when v_type='trespass' then 2 when v_type='vandalism' then 3 else 0 end;
  v_roll:=public.campaign_v4_check(v_actor.id,case when v_type='lockpick' then '巧手' else '潜行' end,v_dc,'normal',0,false);
  v_state:=jsonb_set(v_state,'{v4_crimes}',coalesce(v_state->'v4_crimes','{}'::jsonb),true);
  v_state:=jsonb_set(v_state,array['v4_crimes',v_actor.id::text||':'||(v_state->>'chapter')||':'||v_area||':'||v_type],to_jsonb(case when (v_roll->>'success')::boolean then 'unseen' else 'caught' end),true);
  if (v_roll->>'success')::boolean then
   v_reward:=case when v_type in ('theft','pickpocket') then 5 else 0 end;
   update public.players set gold=gold+v_reward where id=v_actor.id;
   v_log:=v_actor.name||'完成'||v_type||'，没有被发现。'||case when v_reward>0 then '获得 '||v_reward||' 金币。' else '' end;
  else
   update public.players set wanted=least(5,wanted+case when v_type='vandalism' then 2 else 1 end),
     reputation=jsonb_set(reputation,'{guard}',to_jsonb(greatest(-100,coalesce((reputation->>'guard')::integer,0)-5))) where id=v_actor.id;
   v_log:=v_actor.name||'尝试'||v_type||'被目击。守卫开始盘问。';
  end if;
  update public.game_states set state=v_state where room_code=v_code;
 elsif p_action='guard' then
  if v_actor.wanted<1 or v_actor.conditions ? 'jailed' then raise exception 'NO_GUARD_ENCOUNTER'; end if;
  v_choice:=p_payload->>'choice';
  if v_choice in ('说服','欺骗','威吓') then
   v_roll:=public.campaign_v4_check(v_actor.id,v_choice,11+v_actor.wanted*2,'normal',0,false);
   if (v_roll->>'success')::boolean then
    update public.players set wanted=greatest(0,wanted-1) where id=v_actor.id;
    v_log:=v_actor.name||'通过'||v_choice||'争得缓和，通缉降低。';
   else v_log:=v_actor.name||'的'||v_choice||'未能说服守卫。';end if;
  elsif v_choice in ('缴纳罚款','贿赂') then
   v_cost:=case when v_choice='贿赂' then v_actor.wanted*8 else v_actor.wanted*10 end;
   update public.players set gold=gold-v_cost,wanted=greatest(0,wanted-1),
     reputation=case when v_choice='贿赂' then jsonb_set(reputation,'{guard}',to_jsonb(greatest(-100,coalesce((reputation->>'guard')::integer,0)-3))) else reputation end
     where id=v_actor.id and gold>=v_cost;
   if not found then raise exception 'NOT_ENOUGH_GOLD'; end if;
   v_log:=v_actor.name||'支付 '||v_cost||' 金币，通缉降低。';
  elsif v_choice='接受逮捕' then
   update public.players set conditions=conditions||'{"jailed":true}'::jsonb where id=v_actor.id;
   v_log:=v_actor.name||'被带往城市监狱。';
  elsif v_choice='逃跑' then
   v_roll:=public.campaign_v4_check(v_actor.id,'运动',13+v_actor.wanted*2,'normal',0,false);
   update public.players set wanted=least(5,wanted+case when (v_roll->>'success')::boolean then 0 else 1 end) where id=v_actor.id;
   v_log:=v_actor.name||case when (v_roll->>'success')::boolean then '成功甩开守卫。' else '逃跑失败，通缉提高。' end;
  elsif v_choice='拒捕' then
   update public.players set wanted=least(5,wanted+2) where id=v_actor.id;
   v_log:=v_actor.name||'拒绝逮捕，通缉提高。';
  else raise exception 'INVALID_GUARD_CHOICE'; end if;
 elsif p_action='prison' then
  if not v_actor.conditions ? 'jailed' then raise exception 'NOT_JAILED'; end if;
  v_choice:=p_payload->>'choice';
  if v_choice in ('缴纳罚款','服刑') then
   v_cost:=case when v_choice='缴纳罚款' then v_actor.wanted*10 else 0 end;
   update public.players set gold=gold-v_cost,wanted=0,conditions=conditions-'jailed' where id=v_actor.id and gold>=v_cost;
   if not found then raise exception 'NOT_ENOUGH_GOLD'; end if;
   v_log:=v_actor.name||'通过'||v_choice||'离开监狱。';
  elsif v_choice in ('游说守卫','欺骗守卫','寻找钥匙','撬锁','秘密出口') then
   v_roll:=public.campaign_v4_check(v_actor.id,case v_choice when '游说守卫' then '说服' when '欺骗守卫' then '欺骗' when '寻找钥匙' then '察觉' when '撬锁' then '巧手' else '调查' end,case v_choice when '秘密出口' then 17 else 15 end,'normal',0,false);
   if (v_roll->>'success')::boolean then
    update public.players set conditions=conditions-'jailed',wanted=case when v_choice in ('游说守卫','欺骗守卫') then greatest(0,wanted-1) else least(5,wanted+1) end where id=v_actor.id;
    v_log:=v_actor.name||'通过'||v_choice||'离开监狱。';
   else v_log:=v_actor.name||'尝试'||v_choice||'未成功，仍可寻找其他途径。';end if;
  else raise exception 'INVALID_PRISON_CHOICE'; end if;
 elsif p_action='camp_talk' then
  if not coalesce((v_state->>'v4_camp')::boolean,false) then raise exception 'NOT_IN_CAMP'; end if;
  select * into v_comp from public.players where id=(p_payload->>'companion')::bigint and room_code=v_code and is_companion;
  if not found then raise exception 'INVALID_COMPANION'; end if;
  v_choice:=p_payload->>'topic';
  if v_choice not in ('过去','近期剧情','未来计划') then raise exception 'INVALID_TOPIC'; end if;
  v_log:=v_comp.name||'：'||case when v_comp.name='亚岚·铜脉' then
    case v_choice when '过去' then '我为城墙铸过一道闩，后来它锁住了真正求救的人。我留下那份名册，是为了不再让工人变成数字。'
     when '近期剧情' then case when (v_state->>'chapter')::integer>=20 then '城里的桌椅都被拆去加固街口了。等天亮，我还要给那些搬桌子的人看看手上的伤。' else '我见过那炉心的铜纹。假的命令冷下来会消失，真正的伤亡名单却烫在金属里面。' end
     else '战后先修好门，再给死去的人刻上姓名。若你们愿意，我会一直把医疗包放在门边。' end
   else case v_choice when '过去' then '我拒绝改写巡逻表，被调到高堂时连弓都差点被收走。那时亚岚替我保住了副本。'
     when '近期剧情' then case when (v_state->>'chapter')::integer>=20 then '城墙已经不只是守卫的事了。你保护过的证人正带着邻居守住每一处暗门。' else '那份假军令还在变动。我们救下的证人必须先活过今晚，记录才有意义。' end
     else '如果大厅终于肯听证人说话，我想回城墙教年轻巡逻兵怎样拒绝错误的命令。' end end;
 elsif p_action='companion_equip' then
  if not coalesce((v_state->>'v4_camp')::boolean,false) or v_danger or v_actor.conditions ? 'jailed' then raise exception 'EQUIP_IN_CAMP_ONLY'; end if;
  select * into v_comp from public.players where id=(p_payload->>'companion')::bigint and room_code=v_code and is_companion for update;
  if not found then raise exception 'INVALID_COMPANION'; end if;
  select * into v_item from public.campaign_items where name=p_payload->>'item' and slot in ('weapon','armor','offhand');
  if not found or not v_actor.inventory ? v_item.name then raise exception 'ITEM_NOT_IN_BAG'; end if;
  v_oldname:=null;
  for v_oldname in select e.name from jsonb_array_elements_text(v_comp.equipment) e(name) join public.campaign_items i on i.name=e.name and i.slot=v_item.slot limit 1 loop exit; end loop;
  if v_oldname is not null then select * into v_old from public.campaign_items where name=v_oldname; end if;
  update public.players set inventory=public.campaign_remove_one(inventory,v_item.name)||case when v_oldname is not null then to_jsonb(v_oldname) else '[]'::jsonb end where id=v_actor.id;
  update public.players set equipment=case when v_oldname is not null then public.campaign_remove_one(equipment,v_oldname) else equipment end||to_jsonb(v_item.name),
   ac=ac+v_item.ac-coalesce(v_old.ac,0) where id=v_comp.id;
  v_log:=v_actor.name||'为'||v_comp.name||'装备'||v_item.name||'。';
 else raise exception 'INVALID_V4_ACTION';end if;
 insert into public.messages(room_code,sender,body,kind) values(v_code,v_actor.name,v_log,'v4');
 return public.party_snapshot(v_code);
end $$;
revoke all on function public.party_v4_world(text,text,jsonb) from public,anon,authenticated;
grant execute on function public.party_v4_world(text,text,jsonb) to authenticated;

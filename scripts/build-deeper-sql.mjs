import fs from "node:fs";
import { dialogues } from "../src/dialogues.js";
import { merchants, items } from "../src/merchants.js";
import { battles } from "../src/battles.js";
const source = fs.readFileSync("db/005_classes_spells.sql", "utf8");
const commandStart = source.indexOf(
  "create or replace function public.party_command(",
);
const powerStart = source.indexOf(
  "create or replace function public.party_power(",
);
let command = source.slice(
  commandStart,
  source.indexOf("-- An authenticated room member", commandStart),
);
let power = source.slice(
  powerStart,
  source.indexOf("revoke all on function public.party_snapshot", powerStart),
);
const swap = (s, from, to, label) => {
  if (!s.includes(from)) throw Error(`Missing ${label}`);
  return s.replace(from, to);
};
const segment = (s, from, to, replacement, label) => {
  const a = s.indexOf(from),
    b = s.indexOf(to, a);
  if (a < 0 || b < 0) throw Error(`Missing ${label}`);
  return s.slice(0, a) + replacement + s.slice(b);
};
command = swap(
  command,
  "v_enemy jsonb; v_aid boolean;",
  "v_enemy jsonb; v_aid boolean; v_choice jsonb; v_beat jsonb; v_step int; v_dialogue jsonb; v_item public.campaign_items%rowtype; v_old public.campaign_items%rowtype; v_equipped text; v_foe jsonb; v_enemies jsonb; v_result jsonb; v_chapter int; v_price int;",
  "command vars",
);
command = swap(
  command,
  " elsif p_action='explore' then",
  " elsif p_action='dialogue' then\n  if not (v_state->>'started')::boolean then raise exception 'NOT_STARTED'; end if;\n  v_chapter:=(v_state->>'chapter')::int;\n  v_step:=case when (v_state#>>'{dialogue,chapter}')::int=v_chapter then coalesce((v_state#>>'{dialogue,step}')::int,0) else 0 end;\n  select beats->v_step into v_beat from public.campaign_dialogues where chapter_id=v_chapter;\n  if v_beat is null then raise exception 'DIALOGUE_COMPLETE'; end if;\n  v_idx:=coalesce((p_payload->>'choice')::int,-1);\n  if v_idx not in (0,1) then raise exception 'INVALID_DIALOGUE_CHOICE'; end if;\n  v_choice:=v_beat->'options'->v_idx;\n  v_flags:=coalesce(v_state->'flags','[]'::jsonb);\n  if not v_flags ? (v_choice->>'flag') then v_flags:=v_flags||to_jsonb(v_choice->>'flag'); end if;\n  v_state:=jsonb_set(v_state,'{flags}',v_flags);\n  v_dialogue:=case when v_step=0 then jsonb_build_object('chapter',v_chapter,'step',1,'history',jsonb_build_array(jsonb_build_object('choice',v_choice->>'label','reply',v_choice->>'reply'))) else jsonb_set(jsonb_set(v_state->'dialogue','{step}',to_jsonb(v_step+1)),'{history}',coalesce(v_state#>'{dialogue,history}','[]'::jsonb)||jsonb_build_array(jsonb_build_object('choice',v_choice->>'label','reply',v_choice->>'reply'))) end;\n  v_state:=jsonb_set(v_state,'{dialogue}',v_dialogue);\n  v_log:=(v_choice->>'label')||' — '||(v_choice->>'reply');\n elsif p_action='explore' then\n  if coalesce((v_state#>>'{dialogue,chapter}')::int,-1)<>(v_state->>'chapter')::int or coalesce((v_state#>>'{dialogue,step}')::int,0)<3 then raise exception 'DIALOGUE_FIRST'; end if;",
  "dialogue action",
);
const advanceOld =
  "   v_state:=jsonb_set(v_state,'{combat}',jsonb_build_object('name',v_enemy->>'name','hp',v_enemy_hp,'max_hp',v_enemy_hp,'ac',(v_enemy->>'ac')::int-case when v_aid then 1 else 0 end,'attack_bonus',(v_enemy->>'attack')::int,'damage_min',(v_enemy->>'min')::int,'damage_die',(v_enemy->>'die')::int,'turn',v_turn,'initiative',v_init,'round',1));";
const advanceNew = `   v_enemies:='[]'::jsonb;
   for v_foe in select value from jsonb_array_elements(coalesce(v_enemy->'foes',jsonb_build_array(v_enemy))) loop
     v_enemy_hp:=(v_foe->>'hp')::int+greatest(0,v_players-2)*6-case when v_aid then 3 else 0 end;
     v_enemies:=v_enemies||jsonb_build_array(jsonb_build_object('name',v_foe->>'name','hp',v_enemy_hp,'max_hp',v_enemy_hp,'ac',(v_foe->>'ac')::int-case when v_aid then 1 else 0 end,'attack_bonus',(v_foe->>'attack')::int,'damage_min',(v_foe->>'min')::int,'damage_die',(v_foe->>'die')::int));
   end loop;
   v_state:=jsonb_set(v_state,'{combat}',jsonb_build_object('name',v_enemy->>'name','enemies',v_enemies,'hp',public.campaign_enemy_hp(v_enemies),'max_hp',public.campaign_enemy_hp(v_enemies),'turn',v_turn,'initiative',v_init,'round',1,'wards','{}'::jsonb));`;
command = swap(command, advanceOld, advanceNew, "multi foe spawn");
command = swap(
  command,
  "  v_log:='选择：'||left(coalesce(p_payload->>'label',''),80);",
  "  if (v_state->>'chapter')::int=29 then v_state:=jsonb_set(v_state,'{ending}',to_jsonb(case when (v_state->'flags') ? 'council' then '公民议会重建' when (v_state->'flags') ? 'autonomy' then '地下自治联盟' when (select count(*) from jsonb_array_elements_text(v_state->'flags') f where f not like 'voice_%' and f not like 'approach_%' and f not like 'support_%')>=18 then '城市共同体' else '艰难的黎明' end)); end if;\n  v_log:='选择：'||left(coalesce(p_payload->>'label',''),80);",
  "final chapter ending",
);
command = segment(
  command,
  "  if v_idx=29 then",
  "  if v_idx%5=0 then",
  "",
  "early ending",
);

command = segment(
  command,
  " elsif p_action='attack' then",
  " elsif p_action='heal' then",
  ` elsif p_action='attack' then
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
`,
  "attack action",
);
command = segment(
  command,
  " elsif p_action='buy' then",
  " elsif p_action='death_save' then",
  ` elsif p_action='buy' then
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
`,
  "shop actions",
);
power = swap(
  power,
  "v_warr integer;",
  "v_warr integer; v_idx integer; v_foe jsonb; v_result jsonb;",
  "power vars",
);
power = swap(
  power,
  "   elsif v_power.kind='weaken' then\n     v_combat:=jsonb_set(jsonb_set(v_combat,'{ac}',to_jsonb(greatest(8,(v_combat->>'ac')::int-v_amount))),'{attack_bonus}',to_jsonb(greatest(0,(v_combat->>'attack_bonus')::int-1)));\n     v_log:=v_power.name||'：敌人 AC -'||v_amount||'、攻击 -1';",
  `   elsif v_power.kind='weaken' then
     v_idx:=public.campaign_enemy_index(v_combat->'enemies',p_target);
     v_foe:=v_combat->'enemies'->v_idx;
     v_combat:=jsonb_set(jsonb_set(v_combat,array['enemies',v_idx::text,'ac'],to_jsonb(greatest(8,(v_foe->>'ac')::int-v_amount))),array['enemies',v_idx::text,'attack_bonus'],to_jsonb(greatest(0,(v_foe->>'attack_bonus')::int-1)));
     v_log:=v_power.name||'：'||(v_foe->>'name')||' AC -'||v_amount||'、攻击 -1';`,
  "weaken",
);
power = segment(
  power,
  "   elsif v_power.kind='damage' then",
  "   else raise exception 'UNKNOWN_EFFECT'; end if;",
  `   elsif v_power.kind='damage' then
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
`,
  "power damage",
);
power = segment(
  power,
  "   if v_combat is not null and v_combat<>'null'::jsonb and (v_combat->>'hp')::int>=0 then",
  " end if;\n update public.game_states",
  `   if v_combat is not null and v_combat<>'null'::jsonb and (v_combat->>'hp')::int>0 then
     v_result:=public.campaign_finish_turn(v_code,v_combat,v_actor.id);
     v_state:=jsonb_set(v_state,'{combat}',v_result->'combat');
     v_log:=v_log||coalesce(v_result->>'log','');
   end if;
`,
  "power turn",
);
const quote = (s) => `'${s.replaceAll("'", "''")}'`;
const catalog = `-- Server-owned story and shop catalogues. No direct client table access.
create table if not exists public.campaign_dialogues(chapter_id integer primary key references public.campaign_chapters(id),speaker text not null,role text not null,beats jsonb not null);
alter table public.campaign_dialogues enable row level security;
revoke all on public.campaign_dialogues from public,anon,authenticated;
insert into public.campaign_dialogues(chapter_id,speaker,role,beats) values
${dialogues.map((d) => `(${d.chapter},${quote(d.name)},${quote(d.role)},${quote(JSON.stringify(d.beats))}::jsonb)`).join(",\n")}
on conflict(chapter_id) do update set speaker=excluded.speaker,role=excluded.role,beats=excluded.beats;
create table if not exists public.campaign_items(name text primary key,merchant text not null,unlock_chapter integer not null,slot text not null,price integer not null,attack integer not null,damage integer not null,ac integer not null);
alter table public.campaign_items enable row level security;
revoke all on public.campaign_items from public,anon,authenticated;
insert into public.campaign_items(name,merchant,unlock_chapter,slot,price,attack,damage,ac) values
${items.map((i) => `(${quote(i.name)},${quote(merchants.find((m) => m.id === i.merchant).name)},${i.chapter},${quote(i.slot)},${i.price},${i.attack},${i.damage},${i.ac})`).join(",\n")}
on conflict(name) do update set merchant=excluded.merchant,unlock_chapter=excluded.unlock_chapter,slot=excluded.slot,price=excluded.price,attack=excluded.attack,damage=excluded.damage,ac=excluded.ac;
update public.campaign_battles set details=public.campaign_battles.details||new_data.details from (values
${battles.map(({ art, ...b }) => `(${b.chapter},${quote(JSON.stringify({ foes: b.foes }))}::jsonb)`).join(",\n")}
) as new_data(chapter_id,details) where public.campaign_battles.chapter_id=new_data.chapter_id;
`;
const helpers = `create or replace function public.campaign_enemy_hp(p_enemies jsonb) returns integer language sql immutable set search_path=public,pg_temp as $$ select coalesce(sum((enemy->>'hp')::int),0)::int from jsonb_array_elements(p_enemies) enemy $$;
create or replace function public.campaign_enemy_index(p_enemies jsonb,p_target bigint) returns integer language plpgsql immutable set search_path=public,pg_temp as $$
declare idx integer;
begin
 idx:=case when p_target is null then (select (ord-1)::int from jsonb_array_elements(p_enemies) with ordinality e(enemy,ord) where (enemy->>'hp')::int>0 order by ord limit 1) when p_target<0 then -p_target-1 else null end;
 if idx is null or idx<0 or idx>=jsonb_array_length(p_enemies) or (p_enemies->idx->>'hp')::int<=0 then raise exception 'INVALID_ENEMY'; end if;
 return idx;
end $$;
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
     select * into v_target from public.players where room_code=p_code and user_id is not null and hp>0 and death_failures<3 order by random() limit 1;
     exit when not found;
     v_roll:=floor(random()*20)::int+1;
     v_ward:=coalesce((v_combat->'wards'->>v_target.id::text)::int,0);
     if v_roll=20 or (v_roll<>1 and v_roll+(v_foe->>'attack_bonus')::int>=v_target.ac+v_ward) then
       v_dmg:=floor(random()*(v_foe->>'damage_die')::int)::int+(v_foe->>'damage_min')::int;
       update public.players set hp=greatest(0,hp-v_dmg) where id=v_target.id;
       v_log:=v_log||'；'||(v_foe->>'name')||'攻击'||v_target.name||'，伤害 '||v_dmg;
     else v_log:=v_log||'；'||(v_foe->>'name')||'未命中'; end if;
     v_combat:=jsonb_set(v_combat,'{wards}',coalesce(v_combat->'wards','{}'::jsonb)-v_target.id::text);
   end loop;
   select p.id into v_next from jsonb_array_elements(v_combat->'initiative') with ordinality e(item,ord) join public.players p on p.id=(item->>'id')::bigint where p.hp>0 and p.death_failures<3 order by e.ord limit 1;
   v_combat:=jsonb_set(v_combat,'{round}',to_jsonb((v_combat->>'round')::int+1));
 end if;
 v_combat:=jsonb_set(v_combat,'{turn}',coalesce(to_jsonb(v_next),'null'::jsonb));
 if v_next is null then v_log:=v_log||'；队伍全员倒地'; end if;
 return jsonb_build_object('combat',v_combat,'log',v_log);
end $$;
revoke all on function public.campaign_enemy_hp(jsonb),public.campaign_enemy_index(jsonb,bigint),public.campaign_finish_turn(text,jsonb,bigint) from public,anon,authenticated;
`;
const migration = `-- Upper City richer interactive story, multi-enemy combat, progression merchants.\n${catalog}\n${helpers}\n${command}\n${power}\nrevoke all on function public.party_command(text,text,jsonb),public.party_power(text,text,bigint,integer) from public,anon,authenticated;\ngrant execute on function public.party_command(text,text,jsonb),public.party_power(text,text,bigint,integer) to authenticated;\n-- Preserve active legacy fights as one enemy while new encounters spawn their full squads.\nupdate public.game_states set state=jsonb_set(state,'{combat,enemies}',jsonb_build_array((state->'combat')-'turn'-'initiative'-'round'-'wards')) where state->'combat' is not null and state->'combat'<>'null'::jsonb and state#>'{combat,enemies}' is null;\n`;
fs.writeFileSync("db/006_deeper_campaign.sql", migration);
console.log(
  `Generated ${dialogues.length} dialogue scenes, ${battles.length} battle squads and ${items.length} items`,
);

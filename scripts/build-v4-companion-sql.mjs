import fs from 'node:fs';
import {areaNpcs,areaQuests,areaBattles,wondersGoods} from '../src/areas.js';
const q=value=>`'${String(value).replaceAll("'","''")}'`;
const j=value=>`${q(JSON.stringify(value))}::jsonb`;
const n=areaNpcs.find(n=>n.id==='aran'),quest=areaQuests.find(x=>x.id==='hearth'),battle=areaBattles.find(x=>x.id==='hearth_raid');
if(!n||!quest||!battle||n.topics.length<3||quest.stages.length<6||battle.foes.length<3)throw Error('Incomplete companion quest');
const sql=`-- V4 companion content uses existing NPC, quest, encounter and player tables.
insert into public.uc_npcs(id,area,name,role,background,personality,attitude,intro,topics)
values(${q(n.id)},${q(n.area)},${q(n.name)},${q(n.role)},${q(n.background)},${q(n.personality)},${q(n.attitude)},${q(n.intro)},${j(n.topics)})
on conflict(id) do update set name=excluded.name,role=excluded.role,background=excluded.background,personality=excluded.personality,attitude=excluded.attitude,intro=excluded.intro,topics=excluded.topics;
insert into public.uc_quests(id,name,giver,area,description,reward,stages)
values(${q(quest.id)},${q(quest.name)},${q(quest.giver)},${q(quest.area)},${q(quest.description)},${j(quest.reward)},${j(quest.stages)})
on conflict(id) do update set name=excluded.name,description=excluded.description,reward=excluded.reward,stages=excluded.stages;
insert into public.uc_battles(id,name,intro,foes) values(${q(battle.id)},${q(battle.name)},${q(battle.intro)},${j(battle.foes)})
on conflict(id) do update set name=excluded.name,intro=excluded.intro,foes=excluded.foes;
insert into public.campaign_items(name,merchant,unlock_chapter,slot,price,attack,damage,ac,rarity,description,effect)
values('炉心护符','wonders',15,'offhand',95,1,1,2,'稀有','亚岚保存的刻字黄铜，攻击 +1、伤害 +1、AC +2。','')
on conflict(name) do nothing;

create or replace function public.campaign_v4_companion_join() returns trigger language plpgsql security definer set search_path=public,pg_temp as $$
declare v_record jsonb; v_id bigint; v_level integer;
begin
 v_record:=new.state#>'{side_quests,hearth}';
 if v_record->>'status'='已完成' and v_record->>'outcome'='invite'
   and coalesce(old.state#>>'{side_quests,hearth,status}','')<>'已完成'
   and not exists(select 1 from public.players where room_code=new.room_code and is_companion and name='亚岚·铜脉') then
  v_level:=greatest(3,public.campaign_level(coalesce((new.state->>'chapter')::integer,0)));
  insert into public.players(room_code,name,class_name,is_companion,hp,max_hp,ac,stats,inventory,equipment,gold,level,ability_charges,race,conditions,build)
  values(new.room_code,'亚岚·铜脉','牧师',true,30+(v_level-3)*5,30+(v_level-3)*5,16,'[14,10,16,12,16,11]'::jsonb,'["银线药水"]'::jsonb,'["铆钉护胸","炉心战锤"]'::jsonb,0,v_level,2,'矮人','{}'::jsonb,'{"feats":[],"choices":[]}'::jsonb)
  returning id into v_id;
  insert into public.messages(room_code,sender,body,kind) values(new.room_code,'亚岚·铜脉','新伙伴已加入队伍：亚岚·铜脉。伤员的名字，一个也不能漏。','companion');
  new.state:=jsonb_set(new.state,'{v4_aran_joined}',to_jsonb(v_id),true);
 end if;
 return new;
end $$;
drop trigger if exists campaign_v4_companion_join on public.game_states;
create trigger campaign_v4_companion_join before update of state on public.game_states for each row execute function public.campaign_v4_companion_join();
`;
fs.writeFileSync('db/023_v40_companion.sql',sql);
console.log('Built V4 companion migration',sql.length);

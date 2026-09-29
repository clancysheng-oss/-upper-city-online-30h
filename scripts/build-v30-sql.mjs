import fs from 'node:fs';
import {deepChapters} from '../src/deep-story.js';
import {battleAftermath} from '../src/battle-aftermath.js';
import {deepFollowups} from '../src/deep-followups.js';
const quote=s=>"'"+String(s).replaceAll("'","''")+"'";
let sql=fs.readFileSync('db/v30-functions.sql','utf8');
const aftermathSchema=sql.slice(sql.indexOf('create table if not exists public.campaign_aftermath'),sql.indexOf('create or replace function public.party_deep'));
const seeds=deepChapters.map(c=>`insert into public.campaign_deep_chapters(chapter_id,scene,focus,npc,role,lines,object_name,secret,skill,dc)
 values(${c.id},${quote(c.scene)},${quote(c.focus)},${quote(c.npc)},${quote(c.role)},${quote(JSON.stringify(c.lines))}::jsonb,${quote(c.object)},${quote(c.secret)},${quote(c.skill)},${c.dc})
 on conflict(chapter_id) do update set scene=excluded.scene,focus=excluded.focus,npc=excluded.npc,role=excluded.role,lines=excluded.lines,object_name=excluded.object_name,secret=excluded.secret,skill=excluded.skill,dc=excluded.dc;`).join('\n');
const followSeeds=deepFollowups.map((lines,id)=>`update public.campaign_deep_chapters set followups=${quote(JSON.stringify(lines))}::jsonb where chapter_id=${id};`).join('\n');
const aftermathSeeds=battleAftermath.map(a=>`insert into public.campaign_aftermath(chapter_id,object_name,narration,clue,item_name,xp)
 values(${a.chapter},${quote(a.object)},${quote(a.text)},${quote(a.clue)},${quote(a.item)},${a.xp})
 on conflict(chapter_id) do update set object_name=excluded.object_name,narration=excluded.narration,clue=excluded.clue,item_name=excluded.item_name,xp=excluded.xp;`).join('\n');
sql=sql.replace('create or replace function public.party_deep',seeds+'\n'+followSeeds+'\n'+aftermathSeeds+'\ncreate or replace function public.party_deep');
const partyDeep=sql.slice(sql.indexOf('create or replace function public.party_deep'),sql.indexOf('-- Only new encounters'));
fs.writeFileSync('db/013_v30_battle_aftermath.sql','-- v3.0 postbattle content for deployments that already ran 012.\n'+aftermathSchema+'\n'+aftermathSeeds+'\n'+partyDeep);
fs.writeFileSync('db/014_v30_followup_dialogue.sql',
 '-- v3.0 chapter-specific playable follow-up dialogue for existing saves.\n'
 +"alter table public.campaign_deep_chapters add column if not exists followups jsonb not null default '[]'::jsonb;\n"
 +followSeeds+'\n'+partyDeep);
sql+=`
insert into public.campaign_items(name,merchant,unlock_chapter,slot,price,attack,damage,ac,rarity,description,effect)
values
 ('奥术回响法杖','wonders',10,'weapon',92,2,3,0,'稀有','法师装备：法术命中 +2、伤害 +3；每场战斗首个命中的攻击法术额外造成 6 点奥术伤害。','wizard_echo'),
 ('星穹织法长袍','wonders',20,'armor',138,0,0,2,'稀有','法师装备：AC +2；攻击法术伤害 +2。','wizard_robe')
on conflict(name) do update set merchant=excluded.merchant,unlock_chapter=excluded.unlock_chapter,slot=excluded.slot,price=excluded.price,attack=excluded.attack,damage=excluded.damage,ac=excluded.ac,rarity=excluded.rarity,description=excluded.description,effect=excluded.effect;
`;
let source=fs.readFileSync('db/008_v21_combat_story.sql','utf8');
let finish=source.slice(source.indexOf('create or replace function public.campaign_finish_turn'),source.indexOf('create or replace function public.party_command'));
finish=finish.replace('and hp>0 and death_failures<3 order by case','and hp>0 and death_failures<3 and not coalesce(v_combat->\'refusing\',\'[]\'::jsonb) ? id::text order by case');
// Refusal is stored as numeric JSON; compare using a JSON array containment test.
finish=finish.replace("and not coalesce(v_combat->'refusing','[]'::jsonb) ? id::text order by case",
 "and not coalesce(v_combat->'refusing','[]'::jsonb) @> jsonb_build_array(id) order by case");
let power=source.slice(source.indexOf('create or replace function public.party_power'),source.indexOf('revoke all on function public.campaign_finish_turn'));
power=power.replace('v_foe jsonb; v_result jsonb;', 'v_foe jsonb; v_result jsonb; v_staff boolean; v_robe boolean; v_echo integer;');
power=power.replace("v_bonus:=floor(((v_actor.stats->>v_stat)::int-10)/2.0)::int+2+(v_actor.level-1)/4;",
 `v_staff:=v_actor.class_name='法师' and v_actor.equipment ? '奥术回响法杖';
     v_robe:=v_actor.class_name='法师' and v_actor.equipment ? '星穹织法长袍';
     v_bonus:=floor(((v_actor.stats->>v_stat)::int-10)/2.0)::int+2+(v_actor.level-1)/4+case when v_staff then 2 else 0 end;`);
power=power.replace("v_hp:=greatest(0,(v_foe->>'hp')::int-v_dmg);",
 `v_echo:=0;
     if v_dmg>0 and v_staff then
       v_dmg:=v_dmg+3;
       if not coalesce(v_combat->'arcane_echo_used','{}'::jsonb) ? v_actor.id::text then
         v_echo:=6; v_dmg:=v_dmg+v_echo;
         v_combat:=jsonb_set(v_combat,'{arcane_echo_used}',coalesce(v_combat->'arcane_echo_used','{}'::jsonb));
         v_combat:=jsonb_set(v_combat,array['arcane_echo_used',v_actor.id::text],'true'::jsonb,true);
       end if;
     end if;
     if v_dmg>0 and v_robe then v_dmg:=v_dmg+2; end if;
     v_hp:=greatest(0,(v_foe->>'hp')::int-v_dmg);`);
power=power.replace("'，伤害 '||v_dmg;", "'，伤害 '||v_dmg||case when v_echo>0 then '（奥术回响 +'||v_echo||'）' else '' end;");
// The existing save-slot command retains all its actions; only the encounter creation branch changes.
let command=fs.readFileSync('db/010_v22_save_slots.sql','utf8');
command=command.slice(command.indexOf('create or replace function public.party_command'),command.indexOf('create or replace function public.party_save_slot'));
command=command.replace('  if v_enemy is not null then\n   select count(*)',`  if v_enemy is not null and coalesce(v_state#>>array['deep','combat',v_idx::text,'combat_resolved'],'false')='true' then
   v_state:=jsonb_set(v_state,'{combat}','null'::jsonb);
   v_enemy:=null;
  end if;
  if v_enemy is not null then
   select count(*)`);
sql+='\n'+finish+'\n'+power+'\n'+command;
sql+='\nrevoke all on function public.campaign_finish_turn(text,jsonb,bigint),public.party_power(text,text,bigint,integer),public.party_command(text,text,jsonb) from public,anon,authenticated;\ngrant execute on function public.party_power(text,text,bigint,integer),public.party_command(text,text,jsonb) to authenticated;\n';
fs.writeFileSync('db/012_v30_story_depth.sql',sql);
console.log(`v3 seed: ${deepChapters.length} chapters, ${sql.length} bytes SQL`);

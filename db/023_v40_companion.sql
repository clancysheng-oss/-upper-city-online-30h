-- V4 companion content uses existing NPC, quest, encounter and player tables.
insert into public.uc_npcs(id,area,name,role,background,personality,attitude,intro,topics)
values('aran','wonders','亚岚·铜脉','矮人战地牧师与炉心修复师','曾替城墙锻造防火铰链；一次仓库爆炸后，他偷偷保存了真实的伤亡名册。','说话简短，忌讳空洞的誓言，遇见伤者会先动手救人','戒备','这炉火不是给你铸勋章的。先告诉我谁还留在墙外。','[{"prompt":"封存的炉心在每次钟响时升温，仓库记录却说它早已报废。","options":[{"label":"炉心藏着什么？","reply":"是被改写的撤离灯号；黄铜一热，假签名就浮上来。","follow":"他用钳子夹出一小块带字的铜皮。","attitude":1,"flag":"aran_copper"},{"label":"为何不交给大厅？","reply":"我试过。三个证人刚走出门就被人跟踪。","follow":"他让你去酒馆找保管伤亡表的人。","attitude":1,"flag":"aran_witness"},{"label":"你是不是自己弄坏了它？","reply":"我烧坏的是手，没烧坏名字。","follow":"他把烫伤的手藏进袖子。","attitude":-1,"flag":"aran_accuse"}]},{"prompt":"真正的医药包不该只给有徽章的人。","options":[{"label":"你曾在城墙救过谁？","reply":"一名传令兵和两个被命令留在外侧的工人；他们现在还活着。","follow":"他写下两名工人的外号。","attitude":1,"flag":"aran_rescue"},{"label":"可以教我处理伤口吗？","reply":"热铁不能直接贴上去。先洗净，再看有没有毒。","follow":"他把一卷干净绷带放在桌上。","attitude":1,"flag":"aran_heal"},{"label":"我们缺一名牧师。","reply":"缺人的队伍不少。我只跟肯把伤员带回来的人走。","follow":"他等你解释行动计划。","attitude":0,"flag":"aran_wait"}]},{"prompt":"我曾为错误的门令铸过闩。现在想亲手把它拆下来。","options":[{"label":"谁给你的图纸？","reply":"盖印的是大厅，画线的人却来自军需仓。","follow":"他指出图纸上故意少画的一道排水沟。","attitude":1,"flag":"aran_plan"},{"label":"你愿意与伊莉娅合作吗？","reply":"她守证人，我救伤员。如果你们不卖掉任一方，我愿意。","follow":"他第一次抬眼看向你的队伍。","attitude":1,"flag":"aran_ilya"},{"label":"事情结束以后呢？","reply":"还得有人补好城墙。胜利不是在酒馆里说一句话。","follow":"他把钳子塞回腰带。","attitude":0,"flag":"aran_future"}]}]'::jsonb)
on conflict(id) do update set name=excluded.name,role=excluded.role,background=excluded.background,personality=excluded.personality,attitude=excluded.attitude,intro=excluded.intro,topics=excluded.topics;
insert into public.uc_quests(id,name,giver,area,description,reward,stages)
values('hearth','被封存的炉心','aran','wonders','追踪被军需仓封存的炉心和失踪伤员，决定是否邀请修复师亚岚同行。','{"gold":68,"xp":135,"item":"炉心护符"}'::jsonb,'[{"area":"wonders","place":"修复室","label":"检验炉心留下的热纹","text":"铜片上的夜间灯号比官方档案晚了整整九息。","skill":"调查","dc":15},{"area":"kegs","npc":"sera","label":"核对酒馆保管的伤亡表","text":"瑟拉把两名工人的名字圈出：他们被登记成了无名死者。","skill":"洞悉","dc":14},{"area":"hall","npc":"vessa","label":"要求审计官提供军需仓封存令","text":"维莎找出一份用旧印盖的新命令，足以让你们合法接近城墙。","skill":"说服","dc":15},{"area":"walls","place":"军需仓","label":"发现被困伤员与尚未冷却的炉心","text":"铁门后有人敲出三声短讯；伏兵正在把炉心拖走。","skill":"察觉","dc":16},{"area":"walls","npc":"kevan","label":"决定行动优先次序","text":"队长肯分出人手，却要求你们先说明是否要带走仍活着的证人。","options":[["先救伤员并邀请亚岚","凯文打开侧门；亚岚相信你们愿意保护活人。","invite","说服",14],["先保住铜片证据","你保全了文件，但亚岚要继续独自照料伤员。","evidence"],["付钱请守卫私下放行","道路畅通，却失去了亚岚的信任。","bribe"]]},{"area":"walls","label":"阻止焚毁炉心","text":"带盾的佣兵试图堵死侧门，术士在高台点燃引线。","battle":"hearth_raid"},{"area":"wonders","npc":"aran","label":"交还名册并处理伤员","text":"亚岚核对完每个幸存者的名字，决定是否与你们并肩前行。","finish":true,"recruitOutcome":"invite"}]'::jsonb)
on conflict(id) do update set name=excluded.name,description=excluded.description,reward=excluded.reward,stages=excluded.stages;
insert into public.uc_battles(id,name,intro,foes) values('hearth_raid','军需仓炉心伏击','火光在军需仓的铰链上跳动；亚岚正带伤员撤向侧门。','[["封锁队长",58,17,6,5,8,"号令：阻拦侧门撤离"],["重甲堵门兵",44,16,5,4,7,"格挡：重甲掩护"],["高台点火术士",38,15,6,6,8,"投火：点燃引线"],["后巷弩手",34,14,6,4,7,"齐射：瞄准低护甲目标"]]'::jsonb)
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

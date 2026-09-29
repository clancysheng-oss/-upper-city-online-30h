-- v3.0 chapter-specific playable follow-up dialogue for existing saves.
alter table public.campaign_deep_chapters add column if not exists followups jsonb not null default '[]'::jsonb;
update public.campaign_deep_chapters set followups='["铁箱撞过车底三次，里面的东西像石板，不像活人。","倒钉蹄铁只在旧城驿站打制；你们可以按钉帽找匠人。","哈罗若肯留下口供，我会在换班前把马牵来。","水槽下那张收据写着第十三份草料，账房却只报十二份。","蹄铁外侧沾着高堂的白石灰，马车曾绕去修复室。","把收据交给哈罗，他能认出伪造车册的墨水。"]'::jsonb where chapter_id=0;
update public.campaign_deep_chapters set followups='["封匣的人用了冷刀，怕蜡融化后显出里面的旧指纹。","付款者每年改姓，却始终写错同一条街的旧名。","艾尔不知道我是议员的旧友；我替一位证人保密至今。","蜡模背后的纹章属于曾出资修筑城钟的人家。","刀口里卡着今天的纸屑，说明名单刚被人抽走。","你们若要开匣，先让艾尔把每年的收据摊在一起。"]'::jsonb where chapter_id=1;
update public.campaign_deep_chapters set followups='["灯芯沾的不是塔里的油，而是酒馆给信使防雨用的蜡。","蓝色玻璃向河边示警；红色才是催人上屋顶的诱饵。","我昨夜看到有人收走绳索，却留下第三塔的钥匙。","玻璃边缘刻着诺娅的旧暗号，她仍信任发信号的人。","废塔的梯子有新泥，追逐者比信使先到。","只要把两片玻璃叠起来，真正的会面地点会落在河岸。"]'::jsonb where chapter_id=2;
update public.campaign_deep_chapters set followups='["空盘上留有主人从不吃的胡桃碎，侍者拿错了伪装。","送餐铃在主人失踪后仍响了三次，是有人故意报平安。","伊莱娅拿着第二份请柬；她比所有宾客都早知道问题。","菜单背面写着临时更换的主位侍者，不在原班表里。","通风道口有新擦痕，能传入演讲稿却运不走人。","先问侍者他端回了哪道菜，冒名者的说法就会露馅。"]'::jsonb where chapter_id=3;
update public.campaign_deep_chapters set followups='["暗槽向井倾斜，最后会把地图送到城外而非主宅。","钥匙上的三户人家都还住着，却被契约列为空屋。","赛芙留假图是为了拖时间，她不肯让住户知道自己被卖。","井盖内侧的工匠记号与修复室出入簿相同。","水痕停在井的第二层，契约可能仍卡在格栅。","先通知三户居民，真图才能成为证据而非新的威胁。"]'::jsonb where chapter_id=4;
update public.campaign_deep_chapters set followups='["木箱上涂了防雨钟油，里面却是铅封的地契压片。","便衣官员没给夜巡姓名，只给过桥铜牌。","若能匿名作证，其他搬运工也愿指认卸货棚。","蓝粉只用于议会文书，假零件的借口站不住。","钩柄上的工坊号能替工人证明是谁压成金属片。","不要把穆雷的铺子当藏身处，收账人正沿那条路来。"]'::jsonb where chapter_id=5;
update public.campaign_deep_chapters set followups='["银桶灼伤只在碰水时疼，说明桶里是被稀释过的毒。","送货人手套上有高堂修复室的灰，不是园丁的泥。","塔姆愿作证，但我弟弟的工钱握在宅邸管事手里。","滤网里的白晶遇盐会变黑，可与井边废液对照。","水槽下还有未使用的银桶塞，编号没有被磨掉。","把样本交给奈米鉴定，贵族就不能称它为普通肥料。"]'::jsonb where chapter_id=6;
update public.campaign_deep_chapters set followups='["新末句把求援改成遗嘱，读者会误以为议员已死。","那晚的跑腿人戴着军需仓的指套，编辑部没人认识他。","莉缇留着第一版排样，只怕公布后信使先遭追捕。","废铅字的缺角和新末句完全吻合。","报社账目记着一笔没有稿费名目的军费。","先找信使确认交接，再决定哪封遗言可以公开。"]'::jsonb where chapter_id=7;
update public.campaign_deep_chapters set followups='["两队人的扣带系法不同，伪装者学了制服没学会规矩。","被诬士兵在摊前喝茶时钟声刚过九响。","维斯答应保护我孩子，我才愿认出那晚领队。","欠条旁有热杯印，时间比伪造换班令更早。","小巷墙上的擦痕来自运货箱，不是巡逻长戟。","让维斯带原件来，我会在他面前指认签名。"]'::jsonb where chapter_id=8;
update public.campaign_deep_chapters set followups='["真章缺口被我填过铅，伪地契却拓出了填补前的样子。","蜡模能复制轮廓，复制不了石头里留下的铅纹。","阿黛要先安置三户住户，随后才肯组织公开辨认。","纪念碑背面的修补年月仍清晰可读。","假地契上的蜡色比它声称的日期新三十年。","把拓片贴在街坊议事屋，人人都能自己比对。"]'::jsonb where chapter_id=9;
update public.campaign_deep_chapters set followups='["保证金从四个账户转入，最后都汇到同一个担保人。","面具买家根本没问价格，她在找谁敢认原始契约。","兰恩若知道账房交出凭证，拍卖还没结束我就得离城。","凭证上写着一间执政官外包账房的旧地址。","后台有两份目录，一份给买家，一份给追捕名单。","先取走名单，不然下一场拍卖会轮到证人。"]'::jsonb where chapter_id=10;
update public.campaign_deep_chapters set followups='["伪牌能开门，却会让机械把离开者也登记为守塔人。","每十三转影子落在地砖缝，不在钟面上。","格雷修过机械的臂，却没碰藏纸的核心。","发条背面的顺序能让机械停一轮而不毁证据。","暗格里纸边有图书馆封蜡，可去赛洛那里比对。","停机后先护住格雷，他知道如何重新启动守塔钟。"]'::jsonb where chapter_id=11;
update public.campaign_deep_chapters set followups='["被删选区的票数正好够推翻一次旧城表决。","烫痕不像水灾，像有人用热印压走姓名。","赛洛只让可信的人拿原件，我负责给居民看抄本。","页角的私人签注是议员习惯的左手钩，不是后补。","目录页码跳过的不是空页，而是一整条街。","让地下居民自己核对，任何官员都无法替他们说不存在。"]'::jsonb where chapter_id=12;
update public.campaign_deep_chapters set followups='["白鸦沿河飞是为了避开广场的捕鸟网。","剪脚环的人把地址第一行读错，第二行仍藏在铜内。","菲恩被困的屋子没有锁，真正守住他的是看门人的名单。","内层刻的地址指向一间停用的议员信箱。","羽毛上的印泥属于大厅，不属于河边。","我可从后窗接菲恩，但你们得引开登记的守卫。"]'::jsonb where chapter_id=13;
update public.campaign_deep_chapters set followups='["职务印记由多人轮用，死者签名只是掩护谁拿到柜钥匙。","莫罗离开收件室时，执政官办公室的灯才亮。","我曾替原案证人做登记，不想再看他们被写成无名者。","索引上同一页被借出两次，第二次没有归还签名。","收件簿缺页的纸纤维还留在柜缝。","拿着索引找莫罗，他至少得承认有人越过程序。"]'::jsonb where chapter_id=14;
update public.campaign_deep_chapters set followups='["旧面具的裂纹来自驱逐那天砸落的门闩。","空白处写着姓名，但只有家人知道怎么看见。","萨雅挡得住巡逻，挡不住有人把孩子名字写进听证令。","内衬三道线对应三个仍住在水道的家族。","其中一张面具背后藏着原案听证日期。","答应隐去孩子姓名，我才会引你们见证人。"]'::jsonb where chapter_id=15;
update public.campaign_deep_chapters set followups='["绿盐从护甲缝渗入，说明他们先穿甲再被迫守井。","样本里有工坊常用的染料，绝非井水自然变色。","奥里救人，我记录伤势；军令若销毁，两种证据仍在。","染料编号与高堂入库单多出的那一桶相同。","伤兵袖口留有写着倒水时辰的绳结。","先找出下令者的口音，再让伤兵在安全处辨认。"]'::jsonb where chapter_id=16;
update public.campaign_deep_chapters set followups='["钟声使废液流进左侧缝隙，巨兽才会露出软甲。","石梯可藏两人，若全队上去会惊动井壁幼兽。","它冲向人是因为井口有人不断往下倒药。","绞盘仍能拉落灯架，先检查固定点。","检修路可绕过巨兽，却能看见谁把桶拖进井。","若决定交战，请给乌伦一个不靠近腐蚀水面的位子。"]'::jsonb where chapter_id=17;
update public.campaign_deep_chapters set followups='["南线已封，送证人走那里就是把姓名交给追兵。","证人的家人尚在高堂修复室，他们怕被分开押送。","法官愿出庭，只要你们在撤离时守住彼此。","名单中有一个被划掉的出口，其实还能从酒馆进入。","两名证人的口供日期相隔一夜，是被分别关押过。","别把路线写在公开告示上，让赛洛保管一份密本。"]'::jsonb where chapter_id=18;
update public.campaign_deep_chapters set followups='["议员烧证词时先把写页者送走，他说的保护有一半是真。","他仍隐瞒谁下了命令，这一半需要当面追问。","若你们赦免他，请让他亲自面对留下来的证人。","显字药水只在左侧灯照时留下字，信里有见面日期。","台座底的刮痕表明信曾被人取出又放回。","拿信去问埃弗，他不能再只谈动机而不谈名字。"]'::jsonb where chapter_id=19;
update public.campaign_deep_chapters set followups='["刺客借镜灯熄灭穿过人群，只有一面镜仍亮着。","鞋泥混着军械库碎石，像有人故意让他被查到。","菲娅带证人走的暗门每次只能撑十息。","镜轴反光会把侧廊的人影投到听证席下。","撤离图上的旧路线与法官给的路线同出一手。","先把证人送走，再拿图询问谁复制了它。"]'::jsonb where chapter_id=20;
update public.campaign_deep_chapters set followups='["新铜丝带着私人办公室的蜡封，行会从没领过。","停钟让每张换班表在同一时刻失去先后顺序。","改革派要我只修大厅的钟，地下报时仍会停。","绝缘环可让一座钟先响，足够召来街区证人。","铜丝接头上有两个人的指纹，不止一位官员动手。","恢复钟声前先告诉杜伦，你们决定让哪些人听见。"]'::jsonb where chapter_id=21;
update public.campaign_deep_chapters set followups='["检修门原为工人留路，卫队从没拿到外侧钥匙。","施工图能证明封桥令只管桥面，不管下方安全通道。","新兵大多不知命令是假；别让他们为发令者流血。","门轴能从内侧松开，但需有人在桥上拖住卫队。","图纸上还标了雨水季会淹的岔路。","若露佩愿帮忙，工人能从干燥的一侧引你们过去。"]'::jsonb where chapter_id=22;
update public.campaign_deep_chapters set followups='["火从馆员宿舍先起，纵火者想逼我们离开档案室。","原件搬到窗边，是为了便于他们从外侧夺走。","梅瑞还在楼上数人；我不能替她决定放弃谁。","水闸一关，火油就烧不到存票墙。","油瓶里留下雇佣兵领取火油的时辰。","先把孩子带出抄本柜，之后我才敢回去取原件。"]'::jsonb where chapter_id=23;
update public.campaign_deep_chapters set followups='["拒绝旁听的两份方案都让旧地主保留否决权。","地下代表要的是席位，不是贵族允许的发言时间。","露佩肯在公约写进居民监督，我就愿记录票数。","公约空白处可把被删街区重新列为选区。","若当天只有代表签名，明日街坊会要求重来。","把共同底线写成能让孩子读懂的句子，再投票。"]'::jsonb where chapter_id=24;
update public.campaign_deep_chapters set followups='["背面墨水干在贵族印记之前，顺序无法倒过来。","被抹姓名中的一位后代仍在地下，需要自己认领。","鉴定章只证明纸，不替任何派系背书。","水印与第一夜运来的旧纸同厂，契约或曾被调包。","边角的两种针孔说明它长期与另一份案卷装订。","把原件放在各派都能看见的桌上，再请希尔宣布年代。"]'::jsonb where chapter_id=25;
update public.campaign_deep_chapters set followups='["一份命令守前门，另一份要我带人堵证人退路。","原件在盔甲夹层，铁卫队长未必看过它。","凯尔想放下武器，却需要有人给部下解释真相。","夹层纸边有未干的假印泥，改令发生在今天。","新兵的领粮表证明他们并未参加伪造会议。","公开两份日期，让凯尔自己命令部下后退。"]'::jsonb where chapter_id=26;
update public.campaign_deep_chapters set followups='["孩子在桌下听见了付款人的名字，不能让佣兵发现。","娜芙守左门，右侧柱廊还能容一队人离开。","若档案烧毁，幸存者又要被说成不存在。","绳索挂在吊灯横梁上，可压住冲入侧翼的佣兵。","火油桶底有公款封印，雇佣不是私人恩怨。","先救人，再把契约袋交给罗温当众宣读。"]'::jsonb where chapter_id=27;
update public.campaign_deep_chapters set followups='["被删街区的签名一张纸写不完，我分成三册带来。","罗温愿记录，却要有人先把地下代表带进席位。","自治若不允许外来孩子登记，旧错误会换个名字回来。","签名册有活着的旧案见证人，不只是后代。","册子背面写着每户愿承担的街道维护义务。","让各派回答谁可以投票，再谈制度叫什么。"]'::jsonb where chapter_id=28;
update public.campaign_deep_chapters set followups='["雨夜的车是秘密，如今有人愿在报纸上署名说出真相。","判决让一部分人得房，一部分人担忧没有工作。","伊莱娅说编年史要保留质疑者，未来才能纠正我们。","更正声明列出以前被删掉的三名证人。","报纸背面留了公开申诉的地址，不能再只有密函。","你们可以把这份报纸放进队伍的编年史，而不替城市写完结局。"]'::jsonb where chapter_id=29;
create or replace function public.party_deep(p_code text,p_action text,p_payload jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare
 v_code text:=upper(trim(coalesce(p_code,''))); v_actor public.players%rowtype;
 v_state jsonb; v_data public.campaign_deep_chapters%rowtype; v_deep jsonb; v_key text;
 v_done jsonb; v_idx integer; v_roll integer; v_bonus integer; v_dc integer; v_success boolean;
 v_log text; v_combat jsonb; v_foe jsonb; v_enemies jsonb; v_hp integer; v_result jsonb;
 v_comp public.players%rowtype; v_approval integer; v_slot integer; v_aftermath public.campaign_aftermath%rowtype; v_battle jsonb;
begin
 if auth.uid() is null then raise exception 'AUTH_REQUIRED'; end if;
 perform 1 from public.rooms where code=v_code for update;
 if not found then raise exception 'ROOM_NOT_FOUND'; end if;
 select * into v_actor from public.players where room_code=v_code and user_id=auth.uid();
 if not found then raise exception 'NOT_MEMBER'; end if;
 select state into v_state from public.game_states where room_code=v_code for update;
 if not coalesce((v_state->>'started')::boolean,false) then raise exception 'NOT_STARTED'; end if;
 v_deep:='{"talk":{},"inspected":{},"storyFlags":{},"companionApproval":{},"route":{},"explorationFlags":{},"combat":{},"aftermath":{},"followup":{},"debrief":{}}'::jsonb||coalesce(v_state->'deep','{}'::jsonb);
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
   v_log:=v_data.npc||'：'||(v_data.lines->>(v_idx+1));
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
 elsif p_action in ('followup','debrief') then
   v_idx:=coalesce((p_payload->>'choice')::integer,-1);
   if v_idx not between 0 and 2 then raise exception 'INVALID_CHOICE'; end if;
   if p_action='followup' and not (coalesce(v_deep->'talk'->v_key,'[]'::jsonb) ? v_idx::text) then raise exception 'ASK_WITNESS_FIRST'; end if;
   if p_action='debrief' and coalesce(v_deep#>>array['inspected',v_key],'false')<>'true' then raise exception 'INSPECT_FIRST'; end if;
   v_done:=coalesce(v_deep->p_action->v_key,'[]'::jsonb);
   if v_done ? v_idx::text then raise exception 'ALREADY_DISCUSSSED'; end if;
   v_done:=v_done||to_jsonb(v_idx::text);
   v_deep:=jsonb_set(v_deep,array[p_action,v_key],v_done,true);
   v_log:=v_data.npc||'：'||(v_data.followups->>(v_idx+case when p_action='debrief' then 3 else 0 end));
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
 elsif p_action='aftermath' then
   if v_combat is null or v_combat='null'::jsonb or coalesce((v_combat->>'hp')::integer,-1)<>0 then raise exception 'BATTLE_NOT_WON'; end if;
   if coalesce(v_deep#>>array['aftermath',v_key],'false')='true' then raise exception 'ALREADY_COLLECTED'; end if;
   select * into v_aftermath from public.campaign_aftermath where chapter_id=v_key::integer;
   select details into v_battle from public.campaign_battles where chapter_id=v_key::integer;
   if not found or v_aftermath.chapter_id is null or v_combat->>'name'<>v_battle->>'name'
     or v_combat ? 'side_quest' then raise exception 'AFTERMATH_UNAVAILABLE'; end if;
   v_deep:=jsonb_set(v_deep,array['aftermath',v_key],'true'::jsonb,true);
   v_state:=jsonb_set(v_state,'{clues}',coalesce(v_state->'clues','[]'::jsonb)||to_jsonb(v_aftermath.clue));
   update public.players set inventory=inventory||to_jsonb(v_aftermath.item_name) where id=v_actor.id;
   update public.players set experience=experience+v_aftermath.xp where room_code=v_code and user_id is not null;
   v_log:='战后搜查「'||v_aftermath.object_name||'」：'||v_aftermath.narration||' 队员各获得 '||v_aftermath.xp||' XP；'||v_actor.name||'收下'||v_aftermath.item_name||'。';
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


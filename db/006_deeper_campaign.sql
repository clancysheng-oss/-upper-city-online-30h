-- Upper City richer interactive story, multi-enemy combat, progression merchants.
-- Server-owned story and shop catalogues. No direct client table access.
create table if not exists public.campaign_dialogues(chapter_id integer primary key references public.campaign_chapters(id),speaker text not null,role text not null,beats jsonb not null);
alter table public.campaign_dialogues enable row level security;
revoke all on public.campaign_dialogues from public,anon,authenticated;
insert into public.campaign_dialogues(chapter_id,speaker,role,beats) values
(0,'守门人哈罗','守住城门的老兵','[{"text":"一辆封死车窗的马车从城门驶入，车辙留有发亮的灰。守门人却说今夜只放行十二辆。 守门人哈罗在现场等你们，想先弄清你们为何介入。","options":[{"label":"向守门人哈罗询问：核对夜间车册","reply":"守门人哈罗低声说：“雨水将墨迹晕开，只有第十三栏的纸面仍干燥。”你们知道该从哪里着手。","flag":"voice_0_inquiry"},{"label":"先听守门人哈罗讲述自己的处境","reply":"守门人哈罗说：“老守门人不敢说马车，却记得马蹄踏过桥石的节奏。”这份信任会影响后面的交涉。","flag":"voice_0_trust"}]},{"text":"守门人哈罗把局面说得更清楚：“老守门人不敢说马车，却记得马蹄踏过桥石的节奏。”现在你们得决定先以什么态度接近这场风波。","options":[{"label":"承诺协助，再调查「核对夜间车册」","reply":"守门人哈罗接受承诺，指向核对夜间车册的关键位置。你们可以开始探索。","flag":"approach_0_aid"},{"label":"保留判断，先调查「问守门人最后一件小事」","reply":"守门人哈罗尊重你们的谨慎，交代问守门人最后一件小事的来龙去脉。","flag":"approach_0_caution"}]},{"text":"守门人哈罗摊开地图：“调查灰烬和混入马车队会通向不同的后果。先查清核对夜间车册与问守门人最后一件小事，再决定。”","options":[{"label":"请守门人哈罗继续留在现场协助","reply":"守门人哈罗答应留守，并将核对夜间车册的细节记入队伍记录。","flag":"support_0_stay"},{"label":"请守门人哈罗先去照看可能受牵连的人","reply":"守门人哈罗离开前交代了问守门人最后一件小事的隐蔽路径，承诺在安全处接应。","flag":"support_0_protect"}]}]'::jsonb),
(1,'寄存铺掌柜艾尔','保管铜匣的人','[{"text":"寄存铺里有一只写着你们姓名的铜匣。掌柜坚称它已在这里等了十九年。 寄存铺掌柜艾尔在现场等你们，想先弄清你们为何介入。","options":[{"label":"向寄存铺掌柜艾尔询问：查看铜匣封蜡","reply":"寄存铺掌柜艾尔低声说：“蜡上有三代前的工匠印，新的刀痕却划开了边缘。”你们知道该从哪里着手。","flag":"voice_1_inquiry"},{"label":"先听寄存铺掌柜艾尔讲述自己的处境","reply":"寄存铺掌柜艾尔说：“账簿里每年都有人替这只匣子续费，署名各不相同。”这份信任会影响后面的交涉。","flag":"voice_1_trust"}]},{"text":"寄存铺掌柜艾尔把局面说得更清楚：“账簿里每年都有人替这只匣子续费，署名各不相同。”现在你们得决定先以什么态度接近这场风波。","options":[{"label":"承诺协助，再调查「查看铜匣封蜡」","reply":"寄存铺掌柜艾尔接受承诺，指向查看铜匣封蜡的关键位置。你们可以开始探索。","flag":"approach_1_aid"},{"label":"保留判断，先调查「与寄存铺掌柜对账」","reply":"寄存铺掌柜艾尔尊重你们的谨慎，交代与寄存铺掌柜对账的来龙去脉。","flag":"approach_1_caution"}]},{"text":"寄存铺掌柜艾尔摊开地图：“打开铜匣和保护掌柜会通向不同的后果。先查清查看铜匣封蜡与与寄存铺掌柜对账，再决定。”","options":[{"label":"请寄存铺掌柜艾尔继续留在现场协助","reply":"寄存铺掌柜艾尔答应留守，并将查看铜匣封蜡的细节记入队伍记录。","flag":"support_1_stay"},{"label":"请寄存铺掌柜艾尔先去照看可能受牵连的人","reply":"寄存铺掌柜艾尔离开前交代了与寄存铺掌柜对账的隐蔽路径，承诺在安全处接应。","flag":"support_1_protect"}]}]'::jsonb),
(2,'信使诺娅','熟悉屋顶灯语','[{"text":"三座钟楼以灯光交换信号，其中一座塔早已废弃。 信使诺娅在现场等你们，想先弄清你们为何介入。","options":[{"label":"向信使诺娅询问：记录灯光顺序","reply":"信使诺娅低声说：“两座塔一明一暗，第三座塔总迟一拍。”你们知道该从哪里着手。","flag":"voice_2_inquiry"},{"label":"先听信使诺娅讲述自己的处境","reply":"信使诺娅说：“瓦片松动，下面有人刚铺过防雨的绳索。”这份信任会影响后面的交涉。","flag":"voice_2_trust"}]},{"text":"信使诺娅把局面说得更清楚：“瓦片松动，下面有人刚铺过防雨的绳索。”现在你们得决定先以什么态度接近这场风波。","options":[{"label":"承诺协助，再调查「记录灯光顺序」","reply":"信使诺娅接受承诺，指向记录灯光顺序的关键位置。你们可以开始探索。","flag":"approach_2_aid"},{"label":"保留判断，先调查「攀上废塔屋顶」","reply":"信使诺娅尊重你们的谨慎，交代攀上废塔屋顶的来龙去脉。","flag":"approach_2_caution"}]},{"text":"信使诺娅摊开地图：“破译灯语和追上信使会通向不同的后果。先查清记录灯光顺序与攀上废塔屋顶，再决定。”","options":[{"label":"请信使诺娅继续留在现场协助","reply":"信使诺娅答应留守，并将记录灯光顺序的细节记入队伍记录。","flag":"support_2_stay"},{"label":"请信使诺娅先去照看可能受牵连的人","reply":"信使诺娅离开前交代了攀上废塔屋顶的隐蔽路径，承诺在安全处接应。","flag":"support_2_protect"}]}]'::jsonb),
(3,'伊莱娅·维恩','失踪议员的档案员','[{"text":"欢迎宴的主人不见了，所有宾客却记得他刚刚致辞。 伊莱娅·维恩在现场等你们，想先弄清你们为何介入。","options":[{"label":"向伊莱娅·维恩询问：比对宴会座次","reply":"伊莱娅·维恩低声说：“每张请柬都有签名，主人那一席的墨水却没有干。”你们知道该从哪里着手。","flag":"voice_3_inquiry"},{"label":"先听伊莱娅·维恩讲述自己的处境","reply":"伊莱娅·维恩说：“她将一个空酒杯摆到主人座前，等待你们先说出怀疑。”这份信任会影响后面的交涉。","flag":"voice_3_trust"}]},{"text":"伊莱娅·维恩把局面说得更清楚：“她将一个空酒杯摆到主人座前，等待你们先说出怀疑。”现在你们得决定先以什么态度接近这场风波。","options":[{"label":"承诺协助，再调查「比对宴会座次」","reply":"伊莱娅·维恩接受承诺，指向比对宴会座次的关键位置。你们可以开始探索。","flag":"approach_3_aid"},{"label":"保留判断，先调查「和档案员伊莱娅交谈」","reply":"伊莱娅·维恩尊重你们的谨慎，交代和档案员伊莱娅交谈的来龙去脉。","flag":"approach_3_caution"}]},{"text":"伊莱娅·维恩摊开地图：“核对座次和安抚宾客会通向不同的后果。先查清比对宴会座次与和档案员伊莱娅交谈，再决定。”","options":[{"label":"请伊莱娅·维恩继续留在现场协助","reply":"伊莱娅·维恩答应留守，并将比对宴会座次的细节记入队伍记录。","flag":"support_3_stay"},{"label":"请伊莱娅·维恩先去照看可能受牵连的人","reply":"伊莱娅·维恩离开前交代了和档案员伊莱娅交谈的隐蔽路径，承诺在安全处接应。","flag":"support_3_protect"}]}]'::jsonb),
(4,'管家赛芙','宅邸暗室的看守','[{"text":"宅邸暗室里，一张新绘的地图把整个上城区分割成可出售的地块。 管家赛芙在现场等你们，想先弄清你们为何介入。","options":[{"label":"向管家赛芙询问：测绘暗室","reply":"管家赛芙低声说：“地砖下的暗槽沿整条街延伸，图纸刻意避开了井。”你们知道该从哪里着手。","flag":"voice_4_inquiry"},{"label":"先听管家赛芙讲述自己的处境","reply":"管家赛芙说：“地块编号与现有房屋不符，仿佛整条街已经搬走。”这份信任会影响后面的交涉。","flag":"voice_4_trust"}]},{"text":"管家赛芙把局面说得更清楚：“地块编号与现有房屋不符，仿佛整条街已经搬走。”现在你们得决定先以什么态度接近这场风波。","options":[{"label":"承诺协助，再调查「测绘暗室」","reply":"管家赛芙接受承诺，指向测绘暗室的关键位置。你们可以开始探索。","flag":"approach_4_aid"},{"label":"保留判断，先调查「检查售地地图」","reply":"管家赛芙尊重你们的谨慎，交代检查售地地图的来龙去脉。","flag":"approach_4_caution"}]},{"text":"管家赛芙摊开地图：“带走地图和留下假地图会通向不同的后果。先查清测绘暗室与检查售地地图，再决定。”","options":[{"label":"请管家赛芙继续留在现场协助","reply":"管家赛芙答应留守，并将测绘暗室的细节记入队伍记录。","flag":"support_4_stay"},{"label":"请管家赛芙先去照看可能受牵连的人","reply":"管家赛芙离开前交代了检查售地地图的隐蔽路径，承诺在安全处接应。","flag":"support_4_protect"}]}]'::jsonb),
(5,'穆雷','灰市修表匠','[{"text":"修表匠掌握赊账册，记着议员和搬运工之间不该存在的交易。 穆雷在现场等你们，想先弄清你们为何介入。","options":[{"label":"向穆雷询问：追查账本缺页","reply":"穆雷低声说：“修表匠穆雷故意把钟拨慢，给你们留了一刻钟。”你们知道该从哪里着手。","flag":"voice_5_inquiry"},{"label":"先听穆雷讲述自己的处境","reply":"穆雷说：“他们担心说出名字后失去工作。”这份信任会影响后面的交涉。","flag":"voice_5_trust"}]},{"text":"穆雷把局面说得更清楚：“他们担心说出名字后失去工作。”现在你们得决定先以什么态度接近这场风波。","options":[{"label":"承诺协助，再调查「追查账本缺页」","reply":"穆雷接受承诺，指向追查账本缺页的关键位置。你们可以开始探索。","flag":"approach_5_aid"},{"label":"保留判断，先调查「安抚搬运工」","reply":"穆雷尊重你们的谨慎，交代安抚搬运工的来龙去脉。","flag":"approach_5_caution"}]},{"text":"穆雷摊开地图：“抄录账本和答应保护工人会通向不同的后果。先查清追查账本缺页与安抚搬运工，再决定。”","options":[{"label":"请穆雷继续留在现场协助","reply":"穆雷答应留守，并将追查账本缺页的细节记入队伍记录。","flag":"support_5_stay"},{"label":"请穆雷先去照看可能受牵连的人","reply":"穆雷离开前交代了安抚搬运工的隐蔽路径，承诺在安全处接应。","flag":"support_5_protect"}]}]'::jsonb),
(6,'园丁塔姆','花房的照料者','[{"text":"贵族的温室里种着只在废弃矿坑出现的白色蕨类。 园丁塔姆在现场等你们，想先弄清你们为何介入。","options":[{"label":"向园丁塔姆询问：鉴别白蕨孢子","reply":"园丁塔姆低声说：“温室最底层的花盆里留有矿水的苦味。”你们知道该从哪里着手。","flag":"voice_6_inquiry"},{"label":"先听园丁塔姆讲述自己的处境","reply":"园丁塔姆说：“园丁手上的灼伤与花房的浇灌工具一致。”这份信任会影响后面的交涉。","flag":"voice_6_trust"}]},{"text":"园丁塔姆把局面说得更清楚：“园丁手上的灼伤与花房的浇灌工具一致。”现在你们得决定先以什么态度接近这场风波。","options":[{"label":"承诺协助，再调查「鉴别白蕨孢子」","reply":"园丁塔姆接受承诺，指向鉴别白蕨孢子的关键位置。你们可以开始探索。","flag":"approach_6_aid"},{"label":"保留判断，先调查「询问园丁」","reply":"园丁塔姆尊重你们的谨慎，交代询问园丁的来龙去脉。","flag":"approach_6_caution"}]},{"text":"园丁塔姆摊开地图：“分析蕨叶和向园丁许诺帮助会通向不同的后果。先查清鉴别白蕨孢子与询问园丁，再决定。”","options":[{"label":"请园丁塔姆继续留在现场协助","reply":"园丁塔姆答应留守，并将鉴别白蕨孢子的细节记入队伍记录。","flag":"support_6_stay"},{"label":"请园丁塔姆先去照看可能受牵连的人","reply":"园丁塔姆离开前交代了询问园丁的隐蔽路径，承诺在安全处接应。","flag":"support_6_protect"}]}]'::jsonb),
(7,'报社编辑莉缇','收过遗言的人','[{"text":"失踪议员给家人、报社和街道理事留下三套互相矛盾的遗言。 报社编辑莉缇在现场等你们，想先弄清你们为何介入。","options":[{"label":"向报社编辑莉缇询问：比对三封遗言","reply":"报社编辑莉缇低声说：“同一个词在三封信里拼写各异。”你们知道该从哪里着手。","flag":"voice_7_inquiry"},{"label":"先听报社编辑莉缇讲述自己的处境","reply":"报社编辑莉缇说：“年轻信使从来没见过收信的议员。”这份信任会影响后面的交涉。","flag":"voice_7_trust"}]},{"text":"报社编辑莉缇把局面说得更清楚：“年轻信使从来没见过收信的议员。”现在你们得决定先以什么态度接近这场风波。","options":[{"label":"承诺协助，再调查「比对三封遗言」","reply":"报社编辑莉缇接受承诺，指向比对三封遗言的关键位置。你们可以开始探索。","flag":"approach_7_aid"},{"label":"保留判断，先调查「寻找送信人」","reply":"报社编辑莉缇尊重你们的谨慎，交代寻找送信人的来龙去脉。","flag":"approach_7_caution"}]},{"text":"报社编辑莉缇摊开地图：“比对笔迹和公开其中一封会通向不同的后果。先查清比对三封遗言与寻找送信人，再决定。”","options":[{"label":"请报社编辑莉缇继续留在现场协助","reply":"报社编辑莉缇答应留守，并将比对三封遗言的细节记入队伍记录。","flag":"support_7_stay"},{"label":"请报社编辑莉缇先去照看可能受牵连的人","reply":"报社编辑莉缇离开前交代了寻找送信人的隐蔽路径，承诺在安全处接应。","flag":"support_7_protect"}]}]'::jsonb),
(8,'夜巡队长维斯','被调离的小队长','[{"text":"巡逻队长愿意开口，条件是你们找出被诬陷的同袍。 夜巡队长维斯在现场等你们，想先弄清你们为何介入。","options":[{"label":"向夜巡队长维斯询问：重走夜巡路线","reply":"夜巡队长维斯低声说：“地图上的巡逻点间隔不合理，恰好绕开一条小巷。”你们知道该从哪里着手。","flag":"voice_8_inquiry"},{"label":"先听夜巡队长维斯讲述自己的处境","reply":"夜巡队长维斯说：“卖茶人看到了两套制服在换班后相互交换。”这份信任会影响后面的交涉。","flag":"voice_8_trust"}]},{"text":"夜巡队长维斯把局面说得更清楚：“卖茶人看到了两套制服在换班后相互交换。”现在你们得决定先以什么态度接近这场风波。","options":[{"label":"承诺协助，再调查「重走夜巡路线」","reply":"夜巡队长维斯接受承诺，指向重走夜巡路线的关键位置。你们可以开始探索。","flag":"approach_8_aid"},{"label":"保留判断，先调查「为被诬陷者找证人」","reply":"夜巡队长维斯尊重你们的谨慎，交代为被诬陷者找证人的来龙去脉。","flag":"approach_8_caution"}]},{"text":"夜巡队长维斯摊开地图：“接受调查和以金币换消息会通向不同的后果。先查清重走夜巡路线与为被诬陷者找证人，再决定。”","options":[{"label":"请夜巡队长维斯继续留在现场协助","reply":"夜巡队长维斯答应留守，并将重走夜巡路线的细节记入队伍记录。","flag":"support_8_stay"},{"label":"请夜巡队长维斯先去照看可能受牵连的人","reply":"夜巡队长维斯离开前交代了为被诬陷者找证人的隐蔽路径，承诺在安全处接应。","flag":"support_8_protect"}]}]'::jsonb),
(9,'街坊代表阿黛','旧印章的见证人','[{"text":"地契上盖着早被熔毁的公民议会印章。 街坊代表阿黛在现场等你们，想先弄清你们为何介入。","options":[{"label":"向街坊代表阿黛询问：拓下地契印记","reply":"街坊代表阿黛低声说：“印章的缺口与旧议会纪念碑上的缺口完全吻合。”你们知道该从哪里着手。","flag":"voice_9_inquiry"},{"label":"先听街坊代表阿黛讲述自己的处境","reply":"街坊代表阿黛说：“人们关心的不是文书，而是明早会不会被赶走。”这份信任会影响后面的交涉。","flag":"voice_9_trust"}]},{"text":"街坊代表阿黛把局面说得更清楚：“人们关心的不是文书，而是明早会不会被赶走。”现在你们得决定先以什么态度接近这场风波。","options":[{"label":"承诺协助，再调查「拓下地契印记」","reply":"街坊代表阿黛接受承诺，指向拓下地契印记的关键位置。你们可以开始探索。","flag":"approach_9_aid"},{"label":"保留判断，先调查「在街坊会议发言」","reply":"街坊代表阿黛尊重你们的谨慎，交代在街坊会议发言的来龙去脉。","flag":"approach_9_caution"}]},{"text":"街坊代表阿黛摊开地图：“拓印印章和向街坊说明会通向不同的后果。先查清拓下地契印记与在街坊会议发言，再决定。”","options":[{"label":"请街坊代表阿黛继续留在现场协助","reply":"街坊代表阿黛答应留守，并将拓下地契印记的细节记入队伍记录。","flag":"support_9_stay"},{"label":"请街坊代表阿黛先去照看可能受牵连的人","reply":"街坊代表阿黛离开前交代了在街坊会议发言的隐蔽路径，承诺在安全处接应。","flag":"support_9_protect"}]}]'::jsonb),
(10,'拍卖师兰恩','地下拍卖的主持者','[{"text":"地下拍卖将出售一页写着迁居令的古纸，买家中有人使用你们的名字。 拍卖师兰恩在现场等你们，想先弄清你们为何介入。","options":[{"label":"向拍卖师兰恩询问：潜入拍卖后台","reply":"拍卖师兰恩低声说：“买家名单有一栏以你们的队名登记。”你们知道该从哪里着手。","flag":"voice_10_inquiry"},{"label":"先听拍卖师兰恩讲述自己的处境","reply":"拍卖师兰恩说：“买家愿意谈价，却先问你们有没有原始契约。”这份信任会影响后面的交涉。","flag":"voice_10_trust"}]},{"text":"拍卖师兰恩把局面说得更清楚：“买家愿意谈价，却先问你们有没有原始契约。”现在你们得决定先以什么态度接近这场风波。","options":[{"label":"承诺协助，再调查「潜入拍卖后台」","reply":"拍卖师兰恩接受承诺，指向潜入拍卖后台的关键位置。你们可以开始探索。","flag":"approach_10_aid"},{"label":"保留判断，先调查「试探戴面具的买家」","reply":"拍卖师兰恩尊重你们的谨慎，交代试探戴面具的买家的来龙去脉。","flag":"approach_10_caution"}]},{"text":"拍卖师兰恩摊开地图：“潜入拍卖和与买家交涉会通向不同的后果。先查清潜入拍卖后台与试探戴面具的买家，再决定。”","options":[{"label":"请拍卖师兰恩继续留在现场协助","reply":"拍卖师兰恩答应留守，并将潜入拍卖后台的细节记入队伍记录。","flag":"support_10_stay"},{"label":"请拍卖师兰恩先去照看可能受牵连的人","reply":"拍卖师兰恩离开前交代了试探戴面具的买家的隐蔽路径，承诺在安全处接应。","flag":"support_10_protect"}]}]'::jsonb),
(11,'守塔人格雷','钟楼最后的维护者','[{"text":"废钟楼的齿轮里藏着纸页的一半，守塔机械却认所有闯入者为敌。 守塔人格雷在现场等你们，想先弄清你们为何介入。","options":[{"label":"向守塔人格雷询问：拆开钟楼传动轴","reply":"守塔人格雷低声说：“齿轮每十三次转动会露出一条刻字。”你们知道该从哪里着手。","flag":"voice_11_inquiry"},{"label":"先听守塔人格雷讲述自己的处境","reply":"守塔人格雷说：“守塔人反复询问谁有资格为城市敲钟。”这份信任会影响后面的交涉。","flag":"voice_11_trust"}]},{"text":"守塔人格雷把局面说得更清楚：“守塔人反复询问谁有资格为城市敲钟。”现在你们得决定先以什么态度接近这场风波。","options":[{"label":"承诺协助，再调查「拆开钟楼传动轴」","reply":"守塔人格雷接受承诺，指向拆开钟楼传动轴的关键位置。你们可以开始探索。","flag":"approach_11_aid"},{"label":"保留判断，先调查「与守塔人交换故事」","reply":"守塔人格雷尊重你们的谨慎，交代与守塔人交换故事的来龙去脉。","flag":"approach_11_caution"}]},{"text":"守塔人格雷摊开地图：“拆解齿轮和安抚守塔人会通向不同的后果。先查清拆开钟楼传动轴与与守塔人交换故事，再决定。”","options":[{"label":"请守塔人格雷继续留在现场协助","reply":"守塔人格雷答应留守，并将拆开钟楼传动轴的细节记入队伍记录。","flag":"support_11_stay"},{"label":"请守塔人格雷先去照看可能受牵连的人","reply":"守塔人格雷离开前交代了与守塔人交换故事的隐蔽路径，承诺在安全处接应。","flag":"support_11_protect"}]}]'::jsonb),
(12,'赛洛','雨水图书馆馆长','[{"text":"被水淹过的书库保存着旧城选票；馆长要求你们归还失窃的目录。 赛洛在现场等你们，想先弄清你们为何介入。","options":[{"label":"向赛洛询问：修补浸水目录","reply":"赛洛低声说：“字迹在灯火下显出被刮去的街道名称。”你们知道该从哪里着手。","flag":"voice_12_inquiry"},{"label":"先听赛洛讲述自己的处境","reply":"赛洛说：“赛洛要你们承诺让档案对所有居民开放。”这份信任会影响后面的交涉。","flag":"voice_12_trust"}]},{"text":"赛洛把局面说得更清楚：“赛洛要你们承诺让档案对所有居民开放。”现在你们得决定先以什么态度接近这场风波。","options":[{"label":"承诺协助，再调查「修补浸水目录」","reply":"赛洛接受承诺，指向修补浸水目录的关键位置。你们可以开始探索。","flag":"approach_12_aid"},{"label":"保留判断，先调查「说服馆长开放密柜」","reply":"赛洛尊重你们的谨慎，交代说服馆长开放密柜的来龙去脉。","flag":"approach_12_caution"}]},{"text":"赛洛摊开地图：“修复目录和承诺开放档案会通向不同的后果。先查清修补浸水目录与说服馆长开放密柜，再决定。”","options":[{"label":"请赛洛继续留在现场协助","reply":"赛洛答应留守，并将修补浸水目录的细节记入队伍记录。","flag":"support_12_stay"},{"label":"请赛洛先去照看可能受牵连的人","reply":"赛洛离开前交代了说服馆长开放密柜的隐蔽路径，承诺在安全处接应。","flag":"support_12_protect"}]}]'::jsonb),
(13,'驯养人菲恩','白鸦的伙伴','[{"text":"白鸦会把消息带给失踪议员，前提是你们先救出它的驯养人。 驯养人菲恩在现场等你们，想先弄清你们为何介入。","options":[{"label":"向驯养人菲恩询问：跟随白鸦","reply":"驯养人菲恩低声说：“白鸦在三处窗台停留，却从不靠近最亮的灯。”你们知道该从哪里着手。","flag":"voice_13_inquiry"},{"label":"先听驯养人菲恩讲述自己的处境","reply":"驯养人菲恩说：“驯养人被关在没有锁的房间，门外却有人看守。”这份信任会影响后面的交涉。","flag":"voice_13_trust"}]},{"text":"驯养人菲恩把局面说得更清楚：“驯养人被关在没有锁的房间，门外却有人看守。”现在你们得决定先以什么态度接近这场风波。","options":[{"label":"承诺协助，再调查「跟随白鸦」","reply":"驯养人菲恩接受承诺，指向跟随白鸦的关键位置。你们可以开始探索。","flag":"approach_13_aid"},{"label":"保留判断，先调查「营救驯养人」","reply":"驯养人菲恩尊重你们的谨慎，交代营救驯养人的来龙去脉。","flag":"approach_13_caution"}]},{"text":"驯养人菲恩摊开地图：“追踪白鸦和营救驯养人会通向不同的后果。先查清跟随白鸦与营救驯养人，再决定。”","options":[{"label":"请驯养人菲恩继续留在现场协助","reply":"驯养人菲恩答应留守，并将跟随白鸦的细节记入队伍记录。","flag":"support_13_stay"},{"label":"请驯养人菲恩先去照看可能受牵连的人","reply":"驯养人菲恩离开前交代了营救驯养人的隐蔽路径，承诺在安全处接应。","flag":"support_13_protect"}]}]'::jsonb),
(14,'登记官莫罗','保管年代记录的人','[{"text":"交易清单是真的，拆迁命令也是真的；签字日期却相隔三十年。 登记官莫罗在现场等你们，想先弄清你们为何介入。","options":[{"label":"向登记官莫罗询问：校验两份文书年代","reply":"登记官莫罗低声说：“纸张同样古老，签名的职务却隔了三十年。”你们知道该从哪里着手。","flag":"voice_14_inquiry"},{"label":"先听登记官莫罗讲述自己的处境","reply":"登记官莫罗说：“登记官只愿公开一份不完整的收件簿。”这份信任会影响后面的交涉。","flag":"voice_14_trust"}]},{"text":"登记官莫罗把局面说得更清楚：“登记官只愿公开一份不完整的收件簿。”现在你们得决定先以什么态度接近这场风波。","options":[{"label":"承诺协助，再调查「校验两份文书年代」","reply":"登记官莫罗接受承诺，指向校验两份文书年代的关键位置。你们可以开始探索。","flag":"approach_14_aid"},{"label":"保留判断，先调查「质问登记官」","reply":"登记官莫罗尊重你们的谨慎，交代质问登记官的来龙去脉。","flag":"approach_14_caution"}]},{"text":"登记官莫罗摊开地图：“核对年代和公布矛盾会通向不同的后果。先查清校验两份文书年代与质问登记官，再决定。”","options":[{"label":"请登记官莫罗继续留在现场协助","reply":"登记官莫罗答应留守，并将校验两份文书年代的细节记入队伍记录。","flag":"support_14_stay"},{"label":"请登记官莫罗先去照看可能受牵连的人","reply":"登记官莫罗离开前交代了质问登记官的隐蔽路径，承诺在安全处接应。","flag":"support_14_protect"}]}]'::jsonb),
(15,'摆渡人萨雅','地下水道的居民','[{"text":"水道居民用空白面具隐去姓名，只以交换故事作为通行费。 摆渡人萨雅在现场等你们，想先弄清你们为何介入。","options":[{"label":"向摆渡人萨雅询问：用故事换过桥权","reply":"摆渡人萨雅低声说：“水道居民不问出身，只问你们失去过什么。”你们知道该从哪里着手。","flag":"voice_15_inquiry"},{"label":"先听摆渡人萨雅讲述自己的处境","reply":"摆渡人萨雅说：“每张面具的空白处藏着一笔家族旧名。”这份信任会影响后面的交涉。","flag":"voice_15_trust"}]},{"text":"摆渡人萨雅把局面说得更清楚：“每张面具的空白处藏着一笔家族旧名。”现在你们得决定先以什么态度接近这场风波。","options":[{"label":"承诺协助，再调查「用故事换过桥权」","reply":"摆渡人萨雅接受承诺，指向用故事换过桥权的关键位置。你们可以开始探索。","flag":"approach_15_aid"},{"label":"保留判断，先调查「辨认面具图案」","reply":"摆渡人萨雅尊重你们的谨慎，交代辨认面具图案的来龙去脉。","flag":"approach_15_caution"}]},{"text":"摆渡人萨雅摊开地图：“分享经历和带药给居民会通向不同的后果。先查清用故事换过桥权与辨认面具图案，再决定。”","options":[{"label":"请摆渡人萨雅继续留在现场协助","reply":"摆渡人萨雅答应留守，并将用故事换过桥权的细节记入队伍记录。","flag":"support_15_stay"},{"label":"请摆渡人萨雅先去照看可能受牵连的人","reply":"摆渡人萨雅离开前交代了辨认面具图案的隐蔽路径，承诺在安全处接应。","flag":"support_15_protect"}]}]'::jsonb),
(16,'医师奥里','盐井哨站的救护者','[{"text":"炼金废水让井边的守卫失去理智；他们衣领上缝着上城区的徽章。 医师奥里在现场等你们，想先弄清你们为何介入。","options":[{"label":"向医师奥里询问：检查盐井护甲","reply":"医师奥里低声说：“守卫铠甲内侧有相同的炼金工坊编号。”你们知道该从哪里着手。","flag":"voice_16_inquiry"},{"label":"先听医师奥里讲述自己的处境","reply":"医师奥里说：“他在清醒时只记得有人命令把井水倒进下水道。”这份信任会影响后面的交涉。","flag":"voice_16_trust"}]},{"text":"医师奥里把局面说得更清楚：“他在清醒时只记得有人命令把井水倒进下水道。”现在你们得决定先以什么态度接近这场风波。","options":[{"label":"承诺协助，再调查「检查盐井护甲」","reply":"医师奥里接受承诺，指向检查盐井护甲的关键位置。你们可以开始探索。","flag":"approach_16_aid"},{"label":"保留判断，先调查「救助受伤守卫」","reply":"医师奥里尊重你们的谨慎，交代救助受伤守卫的来龙去脉。","flag":"approach_16_caution"}]},{"text":"医师奥里摊开地图：“搜查哨站和救助伤者会通向不同的后果。先查清检查盐井护甲与救助受伤守卫，再决定。”","options":[{"label":"请医师奥里继续留在现场协助","reply":"医师奥里答应留守，并将检查盐井护甲的细节记入队伍记录。","flag":"support_16_stay"},{"label":"请医师奥里先去照看可能受牵连的人","reply":"医师奥里离开前交代了救助受伤守卫的隐蔽路径，承诺在安全处接应。","flag":"support_16_protect"}]}]'::jsonb),
(17,'矿工乌伦','目击甲壳兽的人','[{"text":"一只因废液变异的甲壳兽拦住取证道路。 矿工乌伦在现场等你们，想先弄清你们为何介入。","options":[{"label":"向矿工乌伦询问：寻找甲壳兽弱点","reply":"矿工乌伦低声说：“巨兽的左侧甲壳会在钟响时张开。”你们知道该从哪里着手。","flag":"voice_17_inquiry"},{"label":"先听矿工乌伦讲述自己的处境","reply":"矿工乌伦说：“井边残留着足以灼伤皮肤的绿色液体。”这份信任会影响后面的交涉。","flag":"voice_17_trust"}]},{"text":"矿工乌伦把局面说得更清楚：“井边残留着足以灼伤皮肤的绿色液体。”现在你们得决定先以什么态度接近这场风波。","options":[{"label":"承诺协助，再调查「寻找甲壳兽弱点」","reply":"矿工乌伦接受承诺，指向寻找甲壳兽弱点的关键位置。你们可以开始探索。","flag":"approach_17_aid"},{"label":"保留判断，先调查「避开腐蚀的水面」","reply":"矿工乌伦尊重你们的谨慎，交代避开腐蚀的水面的来龙去脉。","flag":"approach_17_caution"}]},{"text":"矿工乌伦摊开地图：“备战和寻找绕行路线会通向不同的后果。先查清寻找甲壳兽弱点与避开腐蚀的水面，再决定。”","options":[{"label":"请矿工乌伦继续留在现场协助","reply":"矿工乌伦答应留守，并将寻找甲壳兽弱点的细节记入队伍记录。","flag":"support_17_stay"},{"label":"请矿工乌伦先去照看可能受牵连的人","reply":"矿工乌伦离开前交代了避开腐蚀的水面的隐蔽路径，承诺在安全处接应。","flag":"support_17_protect"}]}]'::jsonb),
(18,'无名法官','地下证人守护者','[{"text":"地下法官保有当年驱逐案卷，他要求你们保证证人能活到听证日。 无名法官在现场等你们，想先弄清你们为何介入。","options":[{"label":"向无名法官询问：核对驱逐案卷","reply":"无名法官低声说：“卷宗里有同一个人的两份互相冲突的证词。”你们知道该从哪里着手。","flag":"voice_18_inquiry"},{"label":"先听无名法官讲述自己的处境","reply":"无名法官说：“无名法官把证人的名字写在纸上，等你们提出保护办法。”这份信任会影响后面的交涉。","flag":"voice_18_trust"}]},{"text":"无名法官把局面说得更清楚：“无名法官把证人的名字写在纸上，等你们提出保护办法。”现在你们得决定先以什么态度接近这场风波。","options":[{"label":"承诺协助，再调查「核对驱逐案卷」","reply":"无名法官接受承诺，指向核对驱逐案卷的关键位置。你们可以开始探索。","flag":"approach_18_aid"},{"label":"保留判断，先调查「保证证人安全」","reply":"无名法官尊重你们的谨慎，交代保证证人安全的来龙去脉。","flag":"approach_18_caution"}]},{"text":"无名法官摊开地图：“保护证人和交换护卫承诺会通向不同的后果。先查清核对驱逐案卷与保证证人安全，再决定。”","options":[{"label":"请无名法官继续留在现场协助","reply":"无名法官答应留守，并将核对驱逐案卷的细节记入队伍记录。","flag":"support_18_stay"},{"label":"请无名法官先去照看可能受牵连的人","reply":"无名法官离开前交代了保证证人安全的隐蔽路径，承诺在安全处接应。","flag":"support_18_protect"}]}]'::jsonb),
(19,'议员埃弗','归来的失踪者','[{"text":"议员还活着，但他主动销毁过证词。你们须决定是否与他合作。 议员埃弗在现场等你们，想先弄清你们为何介入。","options":[{"label":"向议员埃弗询问：询问归来的议员","reply":"议员埃弗低声说：“议员承认销毁过证词，却说那是为了保护活着的人。”你们知道该从哪里着手。","flag":"voice_19_inquiry"},{"label":"先听议员埃弗讲述自己的处境","reply":"议员埃弗说：“他把真正的信放在昔日演讲台的底座里。”这份信任会影响后面的交涉。","flag":"voice_19_trust"}]},{"text":"议员埃弗把局面说得更清楚：“他把真正的信放在昔日演讲台的底座里。”现在你们得决定先以什么态度接近这场风波。","options":[{"label":"承诺协助，再调查「询问归来的议员」","reply":"议员埃弗接受承诺，指向询问归来的议员的关键位置。你们可以开始探索。","flag":"approach_19_aid"},{"label":"保留判断，先调查「找回议员藏信」","reply":"议员埃弗尊重你们的谨慎，交代找回议员藏信的来龙去脉。","flag":"approach_19_caution"}]},{"text":"议员埃弗摊开地图：“质询议员和给予作证机会会通向不同的后果。先查清询问归来的议员与找回议员藏信，再决定。”","options":[{"label":"请议员埃弗继续留在现场协助","reply":"议员埃弗答应留守，并将询问归来的议员的细节记入队伍记录。","flag":"support_19_stay"},{"label":"请议员埃弗先去照看可能受牵连的人","reply":"议员埃弗离开前交代了找回议员藏信的隐蔽路径，承诺在安全处接应。","flag":"support_19_protect"}]}]'::jsonb),
(20,'镜厅侍者菲娅','熟悉镜中暗门','[{"text":"公开听证前，有人把唯一的证人引进充满镜子的长廊。 镜厅侍者菲娅在现场等你们，想先弄清你们为何介入。","options":[{"label":"向镜厅侍者菲娅询问：复原镜厅脚印","reply":"镜厅侍者菲娅低声说：“几十道影子中只有一双鞋在熄灯时逆着人群走。”你们知道该从哪里着手。","flag":"voice_20_inquiry"},{"label":"先听镜厅侍者菲娅讲述自己的处境","reply":"镜厅侍者菲娅说：“一面镜子后的暗门正通向楼梯。”这份信任会影响后面的交涉。","flag":"voice_20_trust"}]},{"text":"镜厅侍者菲娅把局面说得更清楚：“一面镜子后的暗门正通向楼梯。”现在你们得决定先以什么态度接近这场风波。","options":[{"label":"承诺协助，再调查「复原镜厅脚印」","reply":"镜厅侍者菲娅接受承诺，指向复原镜厅脚印的关键位置。你们可以开始探索。","flag":"approach_20_aid"},{"label":"保留判断，先调查「保护证人离场」","reply":"镜厅侍者菲娅尊重你们的谨慎，交代保护证人离场的来龙去脉。","flag":"approach_20_caution"}]},{"text":"镜厅侍者菲娅摊开地图：“封锁长廊和保护证人会通向不同的后果。先查清复原镜厅脚印与保护证人离场，再决定。”","options":[{"label":"请镜厅侍者菲娅继续留在现场协助","reply":"镜厅侍者菲娅答应留守，并将复原镜厅脚印的细节记入队伍记录。","flag":"support_20_stay"},{"label":"请镜厅侍者菲娅先去照看可能受牵连的人","reply":"镜厅侍者菲娅离开前交代了保护证人离场的隐蔽路径，承诺在安全处接应。","flag":"support_20_protect"}]}]'::jsonb),
(21,'钟匠杜伦','维护城市总钟','[{"text":"城里的钟一起停住。停钟命令来自现任执政官的私人办公室。 钟匠杜伦在现场等你们，想先弄清你们为何介入。","options":[{"label":"向钟匠杜伦询问：找出停钟机关","reply":"钟匠杜伦低声说：“钟楼的总控线来自执政官办公室，而非工匠行会。”你们知道该从哪里着手。","flag":"voice_21_inquiry"},{"label":"先听钟匠杜伦讲述自己的处境","reply":"钟匠杜伦说：“改革派承诺公开证据，却要求你们先放弃地下居民的席位。”这份信任会影响后面的交涉。","flag":"voice_21_trust"}]},{"text":"钟匠杜伦把局面说得更清楚：“改革派承诺公开证据，却要求你们先放弃地下居民的席位。”现在你们得决定先以什么态度接近这场风波。","options":[{"label":"承诺协助，再调查「找出停钟机关」","reply":"钟匠杜伦接受承诺，指向找出停钟机关的关键位置。你们可以开始探索。","flag":"approach_21_aid"},{"label":"保留判断，先调查「与改革派谈条件」","reply":"钟匠杜伦尊重你们的谨慎，交代与改革派谈条件的来龙去脉。","flag":"approach_21_caution"}]},{"text":"钟匠杜伦摊开地图：“潜入办公室和接触改革派会通向不同的后果。先查清找出停钟机关与与改革派谈条件，再决定。”","options":[{"label":"请钟匠杜伦继续留在现场协助","reply":"钟匠杜伦答应留守，并将找出停钟机关的细节记入队伍记录。","flag":"support_21_stay"},{"label":"请钟匠杜伦先去照看可能受牵连的人","reply":"钟匠杜伦离开前交代了与改革派谈条件的隐蔽路径，承诺在安全处接应。","flag":"support_21_protect"}]}]'::jsonb),
(22,'桥卫雷蒙','接到封锁令的士兵','[{"text":"卫队封桥搜捕调查者；帮过的工人或地下居民或许愿意开路。 桥卫雷蒙在现场等你们，想先弄清你们为何介入。","options":[{"label":"向桥卫雷蒙询问：寻找断桥的替代路","reply":"桥卫雷蒙低声说：“桥下的旧检修道曾由灰市工人维护。”你们知道该从哪里着手。","flag":"voice_22_inquiry"},{"label":"先听桥卫雷蒙讲述自己的处境","reply":"桥卫雷蒙说：“他们的命令没有签署人，只有一枚熟悉的假印。”这份信任会影响后面的交涉。","flag":"voice_22_trust"}]},{"text":"桥卫雷蒙把局面说得更清楚：“他们的命令没有签署人，只有一枚熟悉的假印。”现在你们得决定先以什么态度接近这场风波。","options":[{"label":"承诺协助，再调查「寻找断桥的替代路」","reply":"桥卫雷蒙接受承诺，指向寻找断桥的替代路的关键位置。你们可以开始探索。","flag":"approach_22_aid"},{"label":"保留判断，先调查「向卫队出示证据」","reply":"桥卫雷蒙尊重你们的谨慎，交代向卫队出示证据的来龙去脉。","flag":"approach_22_caution"}]},{"text":"桥卫雷蒙摊开地图：“尝试谈判和请求旧盟友会通向不同的后果。先查清寻找断桥的替代路与向卫队出示证据，再决定。”","options":[{"label":"请桥卫雷蒙继续留在现场协助","reply":"桥卫雷蒙答应留守，并将寻找断桥的替代路的细节记入队伍记录。","flag":"support_22_stay"},{"label":"请桥卫雷蒙先去照看可能受牵连的人","reply":"桥卫雷蒙离开前交代了向卫队出示证据的隐蔽路径，承诺在安全处接应。","flag":"support_22_protect"}]}]'::jsonb),
(23,'馆员梅瑞','抢救档案的人','[{"text":"纵火者涌向图书馆，证据和馆员都在里面。 馆员梅瑞在现场等你们，想先弄清你们为何介入。","options":[{"label":"向馆员梅瑞询问：组织救火队","reply":"馆员梅瑞低声说：“档案室和馆员宿舍只能先救一处。”你们知道该从哪里着手。","flag":"voice_23_inquiry"},{"label":"先听馆员梅瑞讲述自己的处境","reply":"馆员梅瑞说：“煤灰落在同一种皮靴的鞋纹里。”这份信任会影响后面的交涉。","flag":"voice_23_trust"}]},{"text":"馆员梅瑞把局面说得更清楚：“煤灰落在同一种皮靴的鞋纹里。”现在你们得决定先以什么态度接近这场风波。","options":[{"label":"承诺协助，再调查「组织救火队」","reply":"馆员梅瑞接受承诺，指向组织救火队的关键位置。你们可以开始探索。","flag":"approach_23_aid"},{"label":"保留判断，先调查「追踪纵火者」","reply":"馆员梅瑞尊重你们的谨慎，交代追踪纵火者的来龙去脉。","flag":"approach_23_caution"}]},{"text":"馆员梅瑞摊开地图：“组织守卫和先救馆员会通向不同的后果。先查清组织救火队与追踪纵火者，再决定。”","options":[{"label":"请馆员梅瑞继续留在现场协助","reply":"馆员梅瑞答应留守，并将组织救火队的细节记入队伍记录。","flag":"support_23_stay"},{"label":"请馆员梅瑞先去照看可能受牵连的人","reply":"馆员梅瑞离开前交代了追踪纵火者的隐蔽路径，承诺在安全处接应。","flag":"support_23_protect"}]}]'::jsonb),
(24,'工人领袖露佩','街区议事主持者','[{"text":"四个派系提出方案：复兴议会、有限改革、旧秩序或地下自治。 工人领袖露佩在现场等你们，想先弄清你们为何介入。","options":[{"label":"向工人领袖露佩询问：主持街区议事","reply":"工人领袖露佩低声说：“四个派系各派代表，所有人都要求先保证安全。”你们知道该从哪里着手。","flag":"voice_24_inquiry"},{"label":"先听工人领袖露佩讲述自己的处境","reply":"工人领袖露佩说：“相似的要求被不同人用不同措辞提出。”这份信任会影响后面的交涉。","flag":"voice_24_trust"}]},{"text":"工人领袖露佩把局面说得更清楚：“相似的要求被不同人用不同措辞提出。”现在你们得决定先以什么态度接近这场风波。","options":[{"label":"承诺协助，再调查「主持街区议事」","reply":"工人领袖露佩接受承诺，指向主持街区议事的关键位置。你们可以开始探索。","flag":"approach_24_aid"},{"label":"保留判断，先调查「统计各派诉求」","reply":"工人领袖露佩尊重你们的谨慎，交代统计各派诉求的来龙去脉。","flag":"approach_24_caution"}]},{"text":"工人领袖露佩摊开地图：“收集意见和举行公开集会会通向不同的后果。先查清主持街区议事与统计各派诉求，再决定。”","options":[{"label":"请工人领袖露佩继续留在现场协助","reply":"工人领袖露佩答应留守，并将主持街区议事的细节记入队伍记录。","flag":"support_24_stay"},{"label":"请工人领袖露佩先去照看可能受牵连的人","reply":"工人领袖露佩离开前交代了统计各派诉求的隐蔽路径，承诺在安全处接应。","flag":"support_24_protect"}]}]'::jsonb),
(25,'公证人希尔','契约鉴定人','[{"text":"最终契约规定，土地属于所有在这里生活并为其负责的人。 公证人希尔在现场等你们，想先弄清你们为何介入。","options":[{"label":"向公证人希尔询问：鉴定契约原件","reply":"公证人希尔低声说：“契约上有四种不同墨水，最旧的一种在纸张背面。”你们知道该从哪里着手。","flag":"voice_25_inquiry"},{"label":"先听公证人希尔讲述自己的处境","reply":"公证人希尔说：“代表要求城市里每个无名者都能保有投票权。”这份信任会影响后面的交涉。","flag":"voice_25_trust"}]},{"text":"公证人希尔把局面说得更清楚：“代表要求城市里每个无名者都能保有投票权。”现在你们得决定先以什么态度接近这场风波。","options":[{"label":"承诺协助，再调查「鉴定契约原件」","reply":"公证人希尔接受承诺，指向鉴定契约原件的关键位置。你们可以开始探索。","flag":"approach_25_aid"},{"label":"保留判断，先调查「邀请地下代表」","reply":"公证人希尔尊重你们的谨慎，交代邀请地下代表的来龙去脉。","flag":"approach_25_caution"}]},{"text":"公证人希尔摊开地图：“鉴定契约和邀请所有派系会通向不同的后果。先查清鉴定契约原件与邀请地下代表，再决定。”","options":[{"label":"请公证人希尔继续留在现场协助","reply":"公证人希尔答应留守，并将鉴定契约原件的细节记入队伍记录。","flag":"support_25_stay"},{"label":"请公证人希尔先去照看可能受牵连的人","reply":"公证人希尔离开前交代了邀请地下代表的隐蔽路径，承诺在安全处接应。","flag":"support_25_protect"}]}]'::jsonb),
(26,'凯尔·索恩','执政官的守门人','[{"text":"执政官的护卫堵在会议厅。他收到的命令与真正的契约相矛盾。 凯尔·索恩在现场等你们，想先弄清你们为何介入。","options":[{"label":"向凯尔·索恩询问：核对护卫命令","reply":"凯尔·索恩低声说：“最后的守门人凯尔拿到的命令有两处日期相互矛盾。”你们知道该从哪里着手。","flag":"voice_26_inquiry"},{"label":"先听凯尔·索恩讲述自己的处境","reply":"凯尔·索恩说：“他曾发誓保护城市，而不是一个办公室。”这份信任会影响后面的交涉。","flag":"voice_26_trust"}]},{"text":"凯尔·索恩把局面说得更清楚：“他曾发誓保护城市，而不是一个办公室。”现在你们得决定先以什么态度接近这场风波。","options":[{"label":"承诺协助，再调查「核对护卫命令」","reply":"凯尔·索恩接受承诺，指向核对护卫命令的关键位置。你们可以开始探索。","flag":"approach_26_aid"},{"label":"保留判断，先调查「争取凯尔的信任」","reply":"凯尔·索恩尊重你们的谨慎，交代争取凯尔的信任的来龙去脉。","flag":"approach_26_caution"}]},{"text":"凯尔·索恩摊开地图：“展示证据和争取守卫会通向不同的后果。先查清核对护卫命令与争取凯尔的信任，再决定。”","options":[{"label":"请凯尔·索恩继续留在现场协助","reply":"凯尔·索恩答应留守，并将核对护卫命令的细节记入队伍记录。","flag":"support_26_stay"},{"label":"请凯尔·索恩先去照看可能受牵连的人","reply":"凯尔·索恩离开前交代了争取凯尔的信任的隐蔽路径，承诺在安全处接应。","flag":"support_26_protect"}]}]'::jsonb),
(27,'平民代表娜芙','议会大厅的见证人','[{"text":"谈判破裂后，一队雇佣兵冲入大厅；你们须守住证据。 平民代表娜芙在现场等你们，想先弄清你们为何介入。","options":[{"label":"向平民代表娜芙询问：测量大厅掩体","reply":"平民代表娜芙低声说：“雇佣兵从两侧门进入，平民仍在长桌旁。”你们知道该从哪里着手。","flag":"voice_27_inquiry"},{"label":"先听平民代表娜芙讲述自己的处境","reply":"平民代表娜芙说：“他们担心离开后证据会被销毁。”这份信任会影响后面的交涉。","flag":"voice_27_trust"}]},{"text":"平民代表娜芙把局面说得更清楚：“他们担心离开后证据会被销毁。”现在你们得决定先以什么态度接近这场风波。","options":[{"label":"承诺协助，再调查「测量大厅掩体」","reply":"平民代表娜芙接受承诺，指向测量大厅掩体的关键位置。你们可以开始探索。","flag":"approach_27_aid"},{"label":"保留判断，先调查「劝平民撤离」","reply":"平民代表娜芙尊重你们的谨慎，交代劝平民撤离的来龙去脉。","flag":"approach_27_caution"}]},{"text":"平民代表娜芙摊开地图：“迎战和疏散市民会通向不同的后果。先查清测量大厅掩体与劝平民撤离，再决定。”","options":[{"label":"请平民代表娜芙继续留在现场协助","reply":"平民代表娜芙答应留守，并将测量大厅掩体的细节记入队伍记录。","flag":"support_27_stay"},{"label":"请平民代表娜芙先去照看可能受牵连的人","reply":"平民代表娜芙离开前交代了劝平民撤离的隐蔽路径，承诺在安全处接应。","flag":"support_27_protect"}]}]'::jsonb),
(28,'书记员罗温','公开判决的记录者','[{"text":"在所有人面前，决定档案归属和城市的制度。 书记员罗温在现场等你们，想先弄清你们为何介入。","options":[{"label":"向书记员罗温询问：公开所有证据","reply":"书记员罗温低声说：“旧贵族、改革派与地下居民都在等待你们先开口。”你们知道该从哪里着手。","flag":"voice_28_inquiry"},{"label":"先听书记员罗温讲述自己的处境","reply":"书记员罗温说：“投票册上还有被驱逐者的空白栏。”这份信任会影响后面的交涉。","flag":"voice_28_trust"}]},{"text":"书记员罗温把局面说得更清楚：“投票册上还有被驱逐者的空白栏。”现在你们得决定先以什么态度接近这场风波。","options":[{"label":"承诺协助，再调查「公开所有证据」","reply":"书记员罗温接受承诺，指向公开所有证据的关键位置。你们可以开始探索。","flag":"approach_28_aid"},{"label":"保留判断，先调查「准备最终表决」","reply":"书记员罗温尊重你们的谨慎，交代准备最终表决的来龙去脉。","flag":"approach_28_caution"}]},{"text":"书记员罗温摊开地图：“恢复公民议会和建立地下自治会通向不同的后果。先查清公开所有证据与准备最终表决，再决定。”","options":[{"label":"请书记员罗温继续留在现场协助","reply":"书记员罗温答应留守，并将公开所有证据的细节记入队伍记录。","flag":"support_28_stay"},{"label":"请书记员罗温先去照看可能受牵连的人","reply":"书记员罗温离开前交代了准备最终表决的隐蔽路径，承诺在安全处接应。","flag":"support_28_protect"}]}]'::jsonb),
(29,'伊莱娅·维恩','保存队伍编年史','[{"text":"街道还在，城市却已经变了。盟友根据一路的承诺决定留下或离开。 伊莱娅·维恩在现场等你们，想先弄清你们为何介入。","options":[{"label":"向伊莱娅·维恩询问：回访旧盟友","reply":"伊莱娅·维恩低声说：“你们沿着一路走过的街道，听见不同人讲述同一夜。”你们知道该从哪里着手。","flag":"voice_29_inquiry"},{"label":"先听伊莱娅·维恩讲述自己的处境","reply":"伊莱娅·维恩说：“每个人在第一页写下最初来到城门的理由。”这份信任会影响后面的交涉。","flag":"voice_29_trust"}]},{"text":"伊莱娅·维恩把局面说得更清楚：“每个人在第一页写下最初来到城门的理由。”现在你们得决定先以什么态度接近这场风波。","options":[{"label":"承诺协助，再调查「回访旧盟友」","reply":"伊莱娅·维恩接受承诺，指向回访旧盟友的关键位置。你们可以开始探索。","flag":"approach_29_aid"},{"label":"保留判断，先调查「整理队伍编年史」","reply":"伊莱娅·维恩尊重你们的谨慎，交代整理队伍编年史的来龙去脉。","flag":"approach_29_caution"}]},{"text":"伊莱娅·维恩摊开地图：“记录后日谈和继续探索会通向不同的后果。先查清回访旧盟友与整理队伍编年史，再决定。”","options":[{"label":"请伊莱娅·维恩继续留在现场协助","reply":"伊莱娅·维恩答应留守，并将回访旧盟友的细节记入队伍记录。","flag":"support_29_stay"},{"label":"请伊莱娅·维恩先去照看可能受牵连的人","reply":"伊莱娅·维恩离开前交代了整理队伍编年史的隐蔽路径，承诺在安全处接应。","flag":"support_29_protect"}]}]'::jsonb)
on conflict(chapter_id) do update set speaker=excluded.speaker,role=excluded.role,beats=excluded.beats;
create table if not exists public.campaign_items(name text primary key,merchant text not null,unlock_chapter integer not null,slot text not null,price integer not null,attack integer not null,damage integer not null,ac integer not null);
alter table public.campaign_items enable row level security;
revoke all on public.campaign_items from public,anon,authenticated;
insert into public.campaign_items(name,merchant,unlock_chapter,slot,price,attack,damage,ac) values
('治疗药水','城门补给商艾米',0,'consumable',10,0,0,0),
('盾牌','城门补给商艾米',0,'offhand',30,0,0,1),
('城门长剑','城门补给商艾米',0,'weapon',18,1,2,0),
('灰市长枪','灰市铁匠穆雷',5,'weapon',32,2,3,0),
('工人护肩','灰市铁匠穆雷',5,'armor',25,0,0,1),
('钟芯刺剑','钟楼工坊格雷',10,'weapon',46,3,4,0),
('齿轮胸甲','钟楼工坊格雷',10,'armor',40,0,0,2),
('盐井战斧','盐井锻造师乌伦',15,'weapon',60,4,5,0),
('深井护符','盐井锻造师乌伦',15,'charm',50,0,0,2),
('镜刃','镜厅藏品商菲娅',20,'weapon',75,5,6,0),
('议会卫甲','镜厅藏品商菲娅',20,'armor',70,0,0,3),
('黎明钢剑','黎明铸匠凯尔',25,'weapon',90,6,7,0),
('誓约披风','黎明铸匠凯尔',25,'charm',85,0,0,3)
on conflict(name) do update set merchant=excluded.merchant,unlock_chapter=excluded.unlock_chapter,slot=excluded.slot,price=excluded.price,attack=excluded.attack,damage=excluded.damage,ac=excluded.ac;
update public.campaign_battles set details=public.campaign_battles.details||new_data.details from (values
(2,'{"foes":[{"name":"雨瓦追猎者","hp":20,"ac":13,"attack":2,"min":1,"die":4},{"name":"裂瓦弩手","hp":15,"ac":12,"attack":2,"min":1,"die":4}]}'::jsonb),
(5,'{"foes":[{"name":"灰市收账人","hp":21,"ac":13,"attack":2,"min":1,"die":4},{"name":"铁钩打手","hp":16,"ac":12,"attack":2,"min":1,"die":4}]}'::jsonb),
(8,'{"foes":[{"name":"冒名夜巡兵","hp":23,"ac":14,"attack":3,"min":1,"die":4},{"name":"伪令弩手","hp":18,"ac":13,"attack":3,"min":1,"die":4}]}'::jsonb),
(11,'{"foes":[{"name":"钟楼机械","hp":24,"ac":14,"attack":3,"min":2,"die":5},{"name":"齿轮守卫","hp":19,"ac":13,"attack":3,"min":2,"die":5},{"name":"钟摆傀儡","hp":19,"ac":13,"attack":3,"min":2,"die":5}]}'::jsonb),
(14,'{"foes":[{"name":"契约猎手","hp":26,"ac":15,"attack":3,"min":2,"die":5},{"name":"焚卷仆从","hp":21,"ac":14,"attack":3,"min":2,"die":5}]}'::jsonb),
(17,'{"foes":[{"name":"盐井甲壳兽","hp":27,"ac":15,"attack":4,"min":2,"die":5},{"name":"腐蚀幼兽","hp":22,"ac":14,"attack":4,"min":2,"die":5},{"name":"井壁爬行者","hp":22,"ac":14,"attack":4,"min":2,"die":5}]}'::jsonb),
(20,'{"foes":[{"name":"镜厅刺客","hp":29,"ac":15,"attack":4,"min":3,"die":6},{"name":"镜影护卫","hp":24,"ac":14,"attack":4,"min":3,"die":6}]}'::jsonb),
(23,'{"foes":[{"name":"档案纵火者","hp":30,"ac":16,"attack":4,"min":3,"die":6},{"name":"火油投手","hp":25,"ac":15,"attack":4,"min":3,"die":6},{"name":"破窗刺客","hp":25,"ac":15,"attack":4,"min":3,"die":6}]}'::jsonb),
(26,'{"foes":[{"name":"执政官铁卫","hp":32,"ac":16,"attack":5,"min":3,"die":6},{"name":"盾墙卫士","hp":27,"ac":15,"attack":5,"min":3,"die":6},{"name":"长戟卫士","hp":27,"ac":15,"attack":5,"min":3,"die":6}]}'::jsonb),
(28,'{"foes":[{"name":"佣兵首领","hp":33,"ac":17,"attack":5,"min":4,"die":6},{"name":"焚证术士","hp":28,"ac":16,"attack":5,"min":4,"die":6},{"name":"铁甲佣兵","hp":28,"ac":16,"attack":5,"min":4,"die":6}]}'::jsonb)
) as new_data(chapter_id,details) where public.campaign_battles.chapter_id=new_data.chapter_id;

create or replace function public.campaign_enemy_hp(p_enemies jsonb) returns integer language sql immutable set search_path=public,pg_temp as $$ select coalesce(sum((enemy->>'hp')::int),0)::int from jsonb_array_elements(p_enemies) enemy $$;
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
    where room_code=v_code and user_id is not null and level<public.campaign_level(v_idx);
  -- A completed fight grants a camp rest before the next scene. Downed allies need healing first.
  if coalesce((v_state#>>'{combat,hp}')::int,-1)=0 then
   update public.players set hp=max_hp,spell_slots=public.campaign_slots(level),ability_charges=2 where room_code=v_code and user_id is not null and hp>0;
  end if;
  select details into v_enemy from public.campaign_battles where chapter_id=v_idx;
  if v_enemy is not null then
   select count(*) into v_players from public.players where room_code=v_code and user_id is not null;
   v_aid:=coalesce(v_state->'flags','[]'::jsonb) ? (v_enemy->>'aid');
   v_enemy_hp:=(v_enemy->>'hp')::int+greatest(0,v_players-2)*7-case when v_aid then 5 else 0 end;
   select jsonb_agg(jsonb_build_object('id',id,'roll',roll) order by roll desc,id),(array_agg(id order by roll desc,id))[1] into v_init,v_turn from (select id,floor(random()*20)::int+1 as roll from public.players where room_code=v_code and user_id is not null and hp>0) i;
   v_enemies:='[]'::jsonb;
   for v_foe in select value from jsonb_array_elements(coalesce(v_enemy->'foes',jsonb_build_array(v_enemy))) loop
     v_enemy_hp:=(v_foe->>'hp')::int+greatest(0,v_players-2)*6-case when v_aid then 3 else 0 end;
     v_enemies:=v_enemies||jsonb_build_array(jsonb_build_object('name',v_foe->>'name','hp',v_enemy_hp,'max_hp',v_enemy_hp,'ac',(v_foe->>'ac')::int-case when v_aid then 1 else 0 end,'attack_bonus',(v_foe->>'attack')::int,'damage_min',(v_foe->>'min')::int,'damage_die',(v_foe->>'die')::int));
   end loop;
   v_state:=jsonb_set(v_state,'{combat}',jsonb_build_object('name',v_enemy->>'name','enemies',v_enemies,'hp',public.campaign_enemy_hp(v_enemies),'max_hp',public.campaign_enemy_hp(v_enemies),'turn',v_turn,'initiative',v_init,'round',1,'wards','{}'::jsonb));
  else v_state:=jsonb_set(v_state,'{combat}','null'::jsonb); end if;
  if v_idx%5=0 then update public.players set gold=gold+10 where room_code=v_code and user_id is not null; end if;
  v_log:='推进至第 '||(v_idx+1)||' 章。'||case when v_idx%5=0 then ' 队员各获 10 金币。' else '' end||case when v_enemy is not null then ' 遭遇：'||(v_enemy->>'name')||'。'||case when v_aid then v_enemy->>'aidText' else '' end else '' end;
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
  if not exists(select 1 from public.players where id=v_target and room_code=v_code and user_id is not null) then raise exception 'INVALID_TARGET'; end if;
  if not (select inventory ? '治疗药水' from public.players where id=v_id) then raise exception 'NO_POTION'; end if;
  update public.players set inventory=inventory-'治疗药水' where id=v_id;
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
     select * into v_target from public.players where id=coalesce(p_target,v_actor.id) and room_code=v_code and user_id is not null;
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
     v_state:=jsonb_set(v_state,'{combat}',v_result->'combat');
     v_log:=v_log||coalesce(v_result->>'log','');
   end if;
 end if;
 update public.game_states set state=jsonb_set(v_state,'{version}',to_jsonb(coalesce((v_state->>'version')::int,0)+1)),updated_at=now() where room_code=v_code;
 insert into public.messages(room_code,sender,body,kind) values(v_code,v_actor.name,v_log,'power');
 return public.party_snapshot(v_code);
end $$;

revoke all on function public.party_command(text,text,jsonb),public.party_power(text,text,bigint,integer) from public,anon,authenticated;
grant execute on function public.party_command(text,text,jsonb),public.party_power(text,text,bigint,integer) to authenticated;
-- Preserve active legacy fights as one enemy while new encounters spawn their full squads.
update public.game_states set state=jsonb_set(state,'{combat,enemies}',jsonb_build_array((state->'combat')-'turn'-'initiative'-'round'-'wards')) where state->'combat' is not null and state->'combat'<>'null'::jsonb and state#>'{combat,enemies}' is null;

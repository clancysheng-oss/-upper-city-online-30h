// Small, character-specific openings added to existing NPC dialogue trees.
export const identityRoutes=[
 {id:'mara_tiefling',area:'kegs',npc:'mara',race:'提夫林',label:'[提夫林] 先问她为何替外乡证人留房',reply:'玛拉把钥匙推来：“我年轻时也被人说过不像这座城的人。楼上的房间不查血统，只问有没有人跟着你。”',clue:'玛拉的安全房间',faction:'underground',skill:'洞悉',dc:12},
 {id:'mara_bard',area:'kegs',npc:'mara',profession:'吟游诗人',label:'[吟游诗人] 借今晚的歌询问传闻',reply:'她敲了三下杯沿：“别唱出证人的名字。停顿在第十三拍，知道旧钟的人会抬头。”',clue:'酒馆第十三拍',faction:'underground',skill:'表演',dc:13},
 {id:'mara_network',area:'kegs',npc:'mara',faction:'underground',minimum:20,label:'[地下势力] 请她安排证人暗路',reply:'玛拉展开后院地板下的旧水道图：“我们的人认得你的名字。带活人走这条路，别带追兵。”',clue:'酒馆后院暗路',skill:'说服',dc:11},
 {id:'elric_dwarf',area:'wonders',npc:'elric',race:'矮人',label:'[矮人] 指出第五环的锻痕',reply:'艾尔里克停下手中的锉刀：“这不是我们的炉子。石粉来自北段城墙的排水井，铜片却在这里登记入库。”',clue:'北段井石粉',faction:'gond',skill:'调查',dc:12},
 {id:'elric_wizard',area:'wonders',npc:'elric',profession:'法师',label:'[法师] 解析星盘的残留符文',reply:'他允许你靠近封存柜。灼痕组成的是延迟九息的启动式，而不是攻击法阵。',clue:'星盘延迟符文',faction:'gond',skill:'奥秘',dc:14},
 {id:'elric_gond',area:'wonders',npc:'elric',faction:'gond',minimum:20,label:'[贡德声望] 调出修复记录原件',reply:'“你们替药剂师守住过病人。”他打开原簿，失窃当晚的试火时刻比军令早了一刻。',clue:'失窃当晚试火记录',skill:'调查',dc:11},
 {id:'vessa_human',area:'hall',npc:'vessa',race:'人类',label:'[人类] 询问居民如何申请旁听',reply:'维莎在名单下划线：“入场不需要贵族徽章。把居民的名字交给我，我要他们在记录里有座位。”',clue:'公开旁听登记',faction:'hall',skill:'说服',dc:13},
 {id:'vessa_elf',area:'hall',npc:'vessa',race:'精灵',label:'[精灵] 比对旧印与早年的纪年法',reply:'她把两份卷宗并排铺开。旧印边缘刻着精灵历的月相，证明其中一份“新”军令借用了旧模。',clue:'旧印精灵月相',faction:'hall',skill:'历史',dc:14},
 {id:'vessa_paladin',area:'hall',npc:'vessa',profession:'圣武士',label:'[圣武士] 以誓言担保证人的安全',reply:'“誓言不能替代记录，但能让人敢签下名字。”维莎准许证人在你的护送下进入侧厅。',clue:'证人侧厅通行',faction:'hall',skill:'说服',dc:14},
 {id:'vessa_hall',area:'hall',npc:'vessa',faction:'hall',minimum:20,label:'[大厅声望] 阅览封存的质询笔录',reply:'维莎交出盖有双印的副本：“曾经被你们保护的人现在愿意说出谁改写了钟声。”',clue:'封存质询笔录',skill:'调查',dc:11},
 {id:'kevan_dragon',area:'walls',npc:'kevan',race:'龙裔',label:'[龙裔] 观察灯号与风向的冲突',reply:'凯文抬头：“你的眼睛看得比我的新兵远。第五盏灯的烟逆风而行，那是有人在塔内点了第二盏。”',clue:'逆风的第五灯',faction:'guard',skill:'察觉',dc:13},
 {id:'kevan_ranger',area:'walls',npc:'kevan',profession:'游侠',label:'[游侠] 沿排风井寻找第五人的脚印',reply:'他让开路。井边的泥只留了四双靴印，第五个人踩着铁梯上了军需仓。',clue:'军需仓铁梯脚印',faction:'guard',skill:'求生',dc:14},
 {id:'kevan_guard',area:'walls',npc:'kevan',faction:'guard',minimum:20,label:'[守卫声望] 请求北段卫队掩护',reply:'“我记得你们带回来的兵。”凯文交出北门钟表，终战时能避开第一轮的侧翼伏兵。',clue:'北门掩护钟表',skill:'说服',dc:11}
];
export function availableIdentityRoutes(area,npc,player,state){return identityRoutes.filter(r=>r.area===area&&r.npc===npc&&(!r.race||r.race===player.race)&&(!r.profession||r.profession===player.class_name)&&(!r.faction||!r.minimum||(player.reputation?.[r.faction]||0)>=r.minimum)&&!state.v4_dialogue?.[r.id]&&!state.v4_dialogue_attempts?.[`${player.id}:${r.id}`]);}

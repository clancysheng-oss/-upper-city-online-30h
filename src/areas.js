// Original Upper City locations. This catalogue also generates the server-owned SQL rows.
export const areas = [
  {id:'kegs',name:'三只旧酒桶',unlock:0,description:'铜灯悬在三只空酒桶上方。雨夜的信使、失业抄写员与城防家属在这里交换不肯写进公文的事实。',places:[['壁炉旁的账桌','一叠欠条压着酒馆旧地图。'],['后巷的雨水槽','水里浮着蓝色封蜡和碎纸。'],['楼上的空房','窗台可俯瞰通往奇迹高堂的搬货路。']]},
  {id:'wonders',name:'奇迹高堂',unlock:0,description:'拱顶下，工匠把护甲、抄写卷轴与古怪仪器摆成可触摸的展台。库存随城中风波和商路逐渐更新。',places:[['试刃台','铁屑里混有刻着私人纹章的黄铜。'],['封存柜','卷轴的登记日期与真实装订时间不符。'],['修复室','每件入库物品都有两套称重记录。']]},
  {id:'hall',name:'至高大厅',unlock:10,description:'大厅的听证席并不比走廊更安静。官员、递信人和议会顾问在庭审前抢先改写事实。',places:[['公开记录廊','被涂掉的旁听者姓名仍在纸背留下凹痕。'],['旧印室','封条从内侧开启，又被人细心粘回。'],['议事高台','此处能听见幕后的第二套表决钟声。']]},
  {id:'walls',name:'上城区城墙',unlock:15,description:'巡逻灯在雾中依次暗下。城外坡道和排水暗门给守军留下无法解释的足迹。',places:[['北段瞭望台','铜镜偏离了既定的传讯角度。'],['排水暗门','泥土上有五种靴印，四种朝外。'],['军需仓','一批没有编号的箭矢藏在盐袋底下。']]},
];
const topic=(prompt,a,b,c)=>({prompt,options:[a,b,c].map(([label,reply,follow,attitude=0,flag=''])=>({label,reply,follow,attitude,flag}))});
export const areaNpcs = [
  {id:'mara',area:'kegs',name:'玛拉·雾杯',role:'酒馆老板',background:'曾替巡夜队保管密函，拒绝再让客人在店里无声失踪。',personality:'直率，记账严谨',attitude:'谨慎欢迎',intro:'店里每一张桌子都能谈事，但请别让别人替你付账。',topics:[
    topic('昨夜有人把一只空杯倒扣在壁炉边，里面却有盐。', ['谁留下的？','穿蓝斗篷的搬运工；他一直盯着后巷。','玛拉递给你一张写着搬运时辰的纸。',1,'mara_shift'],['为什么有盐？','用来显露杯沿的指纹。他想证明自己没有碰过密函。','你看见杯底有半枚工坊印记。',0,'salt_cup'],['可以给我们一份工作吗？','我有几件麻烦，先查清谁有胆量接。','她指向墙上的委托板。',1,'mara_work']),
    topic('今早巡逻的人只喝热水。他们说城墙下面在敲第二遍钟。', ['你相信他们吗？','相信他们害怕是真的，不代表他们看见的全是真的。','她建议从排水暗门查起。',1,'second_bell'],['能请他们作证吗？','除非先保证不会把名单送去大厅。','玛拉肯借楼上房间作证人藏身处。',1,'safe_room'],['那先来顿饭。','炖菜要六枚金币，热酒要四枚。醒着的人更适合调查。','她把菜单推到你的手边。',0,'menu'])]},
  {id:'tobin',area:'kegs',name:'托宾·纸雀',role:'失业抄写员',background:'拒绝改写物资出入簿后失去大厅差事。',personality:'焦虑而敏锐',attitude:'戒备',intro:'我可以辨认字迹，但别在酒馆大声叫我的旧职务。',topics:[
    topic('有人把一笔采购记成三笔，字迹故意学得像我。',['给我看看原账。','原账撕走了页角，留下的压痕指向高堂封存柜。','托宾画出压痕里的序号。',1,'pressed_ledger'],['谁会冒你的名？','大厅旧印室有四人拿得到我的印章。','名单中一个名字被他划得极重。',0,'four_signers'],['你可能也参与了。','若我有份，就不会躲在发霉的楼板下面。','他冷了脸，却没有赶你走。',-1,'tobin_doubt']),
    topic('我的妹妹在墙上服役。她最近的信每封都少一行。',['你想让我们去找她？','找到她，也请先听她自己的说法。','他交给你一张折了三次的地图。',1,'tobin_sister'],['缺的是什么？','每封都剪去夜间换岗的时间。','你发现裁纸刀口与大厅文书一致。',0,'cut_letters'],['先把信公开。','请不要让她为我的冲动受罚。','他收回其中一封，留给你另一封。',-1,'public_letter'])]},
  {id:'sera',area:'kegs',name:'瑟拉·火莓',role:'厨师兼前军医',background:'在一次边境撤离后辞去军职，坚持照顾受伤的普通人。',personality:'温和但不轻信军令',attitude:'友善',intro:'先把湿衣服烘干。打仗前吃饱，吵架前喝水。',topics:[
    topic('有个士兵把绷带藏在袖口，不敢去军医处。',['伤从哪里来？','不是刀伤，是暗门铁栅刮出来的。','瑟拉记下铁锈颜色，供你比对。',1,'rust_bandage'],['你能救他吗？','能，但他得自己愿意进门。','她留了一份干净绷带。',1,'sera_care'],['他是不是逃兵？','伤口不会回答这个问题。','她的语气明显冷下来。',-1,'sera_distrust']),
    topic('我做的炖菜能补体力，但真正的伤要时间。',['这份菜怎么做？','白豆慢炖，药草最后才放，不能久煮。','她给队伍端来一碗热汤。',1,'stew'],['有没有治伤药？','高堂有更强的药剂；我这里是普通食物。','她告诉你药剂的供货人。',0,'potions'],['你认识城墙军官吗？','有些人愿意救人，有些人只会签名。','她提起一份被压下的伤亡表。',0,'casualty_list'])]},
  {id:'elric',area:'wonders',name:'艾尔里克·铜尺',role:'高堂器械总管',background:'从学徒升为总管，暗中保留每次失窃的修复记录。',personality:'精确而固执',attitude:'正式接待',intro:'任何商品都能问价。想碰封存柜，先说清你找什么。',topics:[
    topic('一架星盘少了可拆卸的第五环，却被登记为完整。',['第五环有什么用？','它能把城墙灯号的间隔刻进金属。','他展示磨损方向不同的螺孔。',1,'fifth_ring'],['谁签的入库单？','我的印章是对的，签名的墨水却晚了三日。','他让你核对试刃台的黄铜。',0,'late_ink'],['你收了封口费吗？','若我收了，还会留这张错误的单据？','他把账簿合上了。',-1,'elric_suspect']),
    topic('柜台上的寻常装备供冒险者使用，卷轴须遵守抄写许可。',['现在卖什么？','先看你们调查走到了哪里；危险的器物会逐步开放。','他指向标明稀有度的价签。',0,'stock'],['能定做护甲吗？','有图样和材料才行，先拿基本装备试身。','他量了量肩宽。',1,'fit_armor'],['为何锁住最贵的柜？','那不是地位问题，封印还在校准。','他记下你对稀有物品的兴趣。',-1,'sealed_stock'])]},
  {id:'ilya',area:'wonders',name:'伊莉娅·棱光',role:'半精灵奥术护卫',background:'曾在城墙值夜，因拒绝伪造换岗报告被调来高堂。',personality:'冷静、有同情心',attitude:'审慎观察',intro:'这把弓不是展品。我留在这里，是因为有人还在调查旧报告。',topics:[
    topic('城墙排水暗门比军方承认的多一扇。',['谁知道入口？','排水匠、一个文书，还有半队死去的士兵。','她画下一段可避开巡逻灯的路线。',1,'ilya_route'],['你愿意带路吗？','先证明你不会把目击者当诱饵。','她在桌上留下自己的巡逻徽章。',1,'ilya_trust'],['你在掩护谁？','我掩护还活着的人。','她握紧了弓弦。',-1,'ilya_anger']),
    topic('高堂的魔法卷轴本来要送去军需仓，后被改道。',['能鉴定吗？','这张护盾卷轴仍完整，那张火焰卷轴被拆过封。','她指出卷轴蜡印的差异。',1,'scroll_trace'],['谁改了路线？','去看公开记录廊里的物资签收。','她递给你一份副本。',0,'supply_copy'],['你会加入我们吗？','找到真正的命令，再让我自己决定。','她把徽章重新放回衣领。',0,'ilya_wait'])]},
  {id:'nemi',area:'wonders',name:'奈米·金丝',role:'药剂师与卷轴修复师',background:'为贫民诊所制作廉价药剂，和行会定价者争执多年。',personality:'诙谐，讨厌浪费',attitude:'热情',intro:'药水标签要读三遍。卷轴读错一遍，屋顶就没了。',topics:[
    topic('有人把治疗药水换成了不会愈合的染色水。',['怎么辨别？','真药水摇晃时会在瓶口留银线，假货只有颜色。','她让你带走一张鉴定纸。',1,'silver_line'],['流向哪里？','一半在军需仓，一半在酒馆后巷转手。','她记得搬运人的左手套有破洞。',0,'broken_glove'],['是不是你卖的？','要害人，我会选不那么容易闻出来的东西。','她看了你一眼，继续工作。',-1,'nemi_suspect']),
    topic('修复室的秤从不说谎，记账的人却会。',['帮我核对重量。','星盘少了第五环，账面重量仍未变化。','她交给你旧秤码。',1,'old_weights'],['稀有器物何时上架？','等封印稳固，也等你们能负担得起。','她展示后期才开放的陈列柜。',0,'rare_vault'],['我想要补给。','炖菜在酒馆，药水和卷轴在这里。','她报了一个实在的价格。',0,'nemi_stock'])]},
  {id:'vessa',area:'hall',name:'维莎·灰印',role:'市政审计官',background:'查过失踪议员的票据，却因证词未齐不能公开指控。',personality:'严苛、守程序',attitude:'正式',intro:'案卷可以怀疑，证人不能随便牺牲。告诉我你掌握的证据。',topics:[
    topic('一册账簿在听证前夜消失，封条却完整。',['谁能开门？','带旧印的人能从侧面解开封条。','她让你比对旧印室门锁。',1,'hall_seal'],['能延期听证吗？','延期会让证人更危险。先给我一份副本。','她提供一张空白证物收据。',0,'hearing_deadline'],['这是你的疏忽。','责任在我，但指责填不了证据缺口。','她暂时不再提供钥匙。',-1,'vessa_cold']),
    topic('公开记录廊登记了每个进入大厅的访客。',['查访客簿。','同一个名字在午夜重复两次，中间隔着一次钟鸣。','她展示墨迹深浅。',1,'double_entry'],['哪位官员最可疑？','我不会替你选嫌疑人，只能告诉你谁能签字。','她指出四个签章位置。',0,'four_seals'],['让我们直接拿走。','未经登记的证据进不了听证。','她挡在柜门前。',-1,'evidence_rule'])]},
  {id:'orlan',area:'hall',name:'奥兰·石羽',role:'城市档案保管员',background:'将重要抄本拆成数份藏在城内，防止有人一次烧毁全部。',personality:'小心、爱用谜语',attitude:'探询',intro:'纸张会烧，页码却能留在人的记忆里。',topics:[
    topic('你找的页码不在这栋楼，封面的火痕是真的。',['另一半在哪里？','去问高堂的修复师，她称过这本书。','他给你半片书脊。',1,'half_spine'],['为何不公开？','先公开不完整的书，会害真正的证人被指造假。','他写下找齐证据的顺序。',0,'archive_order'],['你藏了证据。','藏与保护，隔着一张没有名字的逮捕令。','他的回答更简短了。',-1,'orlan_guard']),
    topic('听证台后有一面回声墙。它记录不了声音，却会暴露敲钟时间。',['怎么测量？','把铜杯放在第三块石板上，听回声的间隔。','他把铜杯交给你。',1,'echo_wall'],['谁造的？','是旧城工匠；新官员只学会盖章。','他指向石板上的匠人刻字。',0,'stone_mark'],['这能当证据吗？','与访客簿一起，才经得起质询。','他要求你带回两份记录。',0,'two_records'])]},
  {id:'daran',area:'hall',name:'达兰·露桥',role:'议会改革派联络员',background:'希望听证公开，却受制于同僚的交易和旧债。',personality:'外向、擅长交涉',attitude:'试探',intro:'大厅里没有纯粹的盟友，只有愿意先做正确事的人。',topics:[
    topic('有人用紧急军令绕开了公开表决。',['谁签了军令？','签名是真的，命令发布的时刻却不可能。','他把时间线记在你的地图上。',1,'false_time'],['能叫停吗？','先把城墙的原始换岗表送来。','他答应安排一次公开质询。',1,'public_question'],['你也投了赞成票。','我当时不知那份文书被换过。','他对你保持距离。',-1,'daran_vote']),
    topic('民众需要听见完整故事，不是半张证据。',['我们可以公开证词。','那就保护证人，别只保护纸。','他安排旁听席。',1,'witness_seats'],['给我们钱买消息。','我只能给公开预算，不能用黑账。','他递来一份支出明细。',0,'public_budget'],['先替我们保密。','我会拖延会议，但不能永远拖。','他提出明确的时限。',0,'delay'])]},
  {id:'kevan',area:'walls',name:'凯文·远炬',role:'北段巡逻队长',background:'丢了两名队员后仍每日亲自检查灯号。',personality:'谨慎、重视部下',attitude:'怀疑外来者',intro:'站在这里能看见整个城市，也能看见它最不愿承认的缺口。',topics:[
    topic('昨晚第五盏灯比第四盏先亮，是人为的。',['谁能操控灯？','值夜人和传令官都有钥匙，只有一个有更换记录。','他给你一份排班副本。',1,'fifth_lamp'],['灯号意味着什么？','常规是撤回，倒序是让人打开暗门。','他指出城外坡道的盲区。',0,'reverse_signal'],['你在推卸责任。','我的责任是把剩下的人带回来。','他收起排班表。',-1,'kevan_distrust']),
    topic('军需仓少了四十支箭，却多了五十支无号箭。',['有人换货？','是。箭羽来自城内的手艺，不是边境补给。','他让你保留一根样本。',1,'unmarked_arrow'],['会发动袭击吗？','有人想让它看起来像城外的人干的。','他提出巡逻配合。',1,'inside_threat'],['先封锁城墙。','封锁会把我的斥候困在外面。','他要求先数清失踪人数。',-1,'wall_block'])]},
  {id:'riona',area:'walls',name:'瑞奥娜·盐脊',role:'城墙排水技师',background:'亲手修过暗门，因此知道官方图纸遗漏的通道。',personality:'务实、语速很快',attitude:'忙碌',intro:'先别踩那块松砖。上回有人掉下去，还欠我一把扳手。',topics:[
    topic('旧图纸只画了两道闸，地下还有第三道。',['如何开启？','先关北端水轮，否则会被激流推回城内。','她画下水轮的位置。',1,'third_sluice'],['是谁建的？','比这届官员更早的工人，他们没有署名。','她找到未盖章的工票。',0,'old_workers'],['堵住不就好了？','堵了水会倒灌进酒馆后巷。','她要求先疏散居民。',-1,'flood_risk']),
    topic('泥里的靴印只有四道出去，五道进来。',['第五个人去了哪？','向上的排风井，那里能通向军需仓。','她指给你带锈的爬梯。',1,'fifth_track'],['能测出时间吗？','泥还潮，应该在上一班巡逻之后。','她给出一个两小时窗口。',0,'mud_time'],['这只是野兽。','会拧开铁栅的野兽？我倒想见识。','她没打算陪你猜下去。',-1,'riona_doubt'])]},
  {id:'samir',area:'walls',name:'萨米尔·余烬',role:'城防信号手',background:'曾向外城发出正确警报，却被上级命令改成演习。',personality:'克制、记忆力强',attitude:'渴望被听见',intro:'我不需要你相信我；只要你核对两份信号簿。',topics:[
    topic('信号簿上把真实警报重写成一场演习。',['原簿在哪里？','夹在灯塔铜镜背面，我不敢独自去取。','他交出开启镜框的小钥匙。',1,'mirror_key'],['谁命令改写？','公文来自大厅，但传令人从没露面。','他描述传令人鞋跟的缺口。',0,'messenger_heel'],['你也签了名。','我签了收件，不是认可内容。','他指出自己笔画的差别。',-1,'samir_signature']),
    topic('夜里听见的钟声比大厅钟声晚九息。',['能证实吗？','每次都有同一段回声，去高台试试铜杯。','他让你记住节拍。',1,'nine_beats'],['城外也听得到？','只能听到第一声，第二声藏在墙里。','他画出墙体空腔。',0,'hollow_wall'],['这是幻术吗？','也许。但有人借它调动了真兵。','他请求保存士兵证词。',0,'real_orders'])]},
];
export const areaQuests = [
 {id:'star',name:'失窃的星盘',giver:'mara',area:'kegs',description:'追回失窃星盘的第五环，并查出谁在偷取灯号。',reward:{gold:24,xp:55,item:'刻度护符'},stages:[
  {area:'wonders',place:'封存柜',label:'核对星盘封存记录',text:'第五环不见了，入库单上的墨迹却比失窃时间更新。',skill:'调查',dc:12},
  {area:'kegs',npc:'tobin',label:'询问伪造的入库笔迹',text:'托宾辨认出签名里故意模仿自己的倒钩。',skill:'洞悉',dc:12},
  {area:'wonders',npc:'elric',label:'决定如何处置盗取零件的学徒',text:'学徒说她想用星盘证明父亲死于错误灯号。',options:[['交给审计官','留下公开证据，但学徒对你失去信任。','report'],['游说她归还零件','她愿交回第五环，并指出幕后买家。','persuade','说服',13],['收钱放她离开','你得到私下谢礼，却让星盘再次失踪。','bribe']]},
  {area:'wonders',place:'修复室',label:'修复并核对第五环',text:'零件上的刻线与城墙灯号完全吻合。',skill:'奥秘',dc:13},
  {area:'kegs',npc:'mara',label:'向玛拉说明灯号真相',text:'玛拉联系证人，承诺让旧报告在酒馆被人听见。',options:[['公开记录','证人开始聚集，玛拉对你更加信任。','public'],['先保护证人','玛拉把楼上空房留给目击者。','protect']]},
  {area:'kegs',npc:'mara',label:'交付星盘委托',text:'玛拉结清委托，并把刻度护符交给你。',finish:true}
 ]},
 {id:'medicine',name:'被换掉的药水',giver:'nemi',area:'wonders',description:'追查假药水流向，保护被当成嫌犯的送货少年。',reward:{gold:32,xp:70,item:'净化药剂'},stages:[
  {area:'kegs',place:'后巷的雨水槽',label:'检查后巷假药瓶',text:'瓶塞里卡着一缕蓝色布纤维。',skill:'察觉',dc:12},
  {area:'wonders',npc:'nemi',label:'鉴别剩余药剂',text:'奈米发现染色剂来自公共水渠，而非诊所。',skill:'调查',dc:13},
  {area:'kegs',npc:'sera',label:'决定少年的去向',text:'少年承认替人运货，却不知道箱里是假药。',options:[['交给守卫','瑟拉不赞同，但证词得到正式记录。','guard'],['游说他带路','他领你找到取货暗号，瑟拉感谢你。','guide','说服',13],['威吓逼供','他慌乱中说出军需仓名字，之后不愿再见你。','threat','威吓',13]]},
  {area:'wonders',place:'修复室',label:'追踪封蜡来源',text:'蓝色封蜡由伪造公文的同一人购入。',skill:'调查',dc:14},
  {area:'kegs',npc:'mara',label:'安排替换受害者手里的假药',text:'玛拉用酒馆的送餐路线悄悄更换药瓶。',options:[['先救病人','几名病人恢复了呼吸。','patients'],['先留一瓶作证','保留了能供审计官检测的证物。','sample']]},
  {area:'wonders',npc:'nemi',label:'向奈米交还证据',text:'奈米发放真正的药水，结清委托。',finish:true}
 ]},
 {id:'gate',name:'城墙下的第二道门',giver:'ilya',area:'wonders',description:'调查失踪巡逻队，选择是否保护伊莉娅并争取她加入。',reward:{gold:45,xp:100,item:'夜巡长弓'},stages:[
  {area:'walls',place:'排水暗门',label:'辨认失踪小队的脚印',text:'一人仍活着，被迫从排风井上行。',skill:'求生',dc:14},
  {area:'walls',npc:'riona',label:'安排排水暗门路线',text:'瑞奥娜会关掉水轮，为你争取一刻钟。',skill:'说服',dc:14},
  {area:'kegs',npc:'tobin',label:'决定是否保护证人与伊莉娅',text:'有人递来一笔钱，要求你把伊莉娅的位置写在收据上。',options:[['拒绝并保护伊莉娅','托宾把藏身处交给你；伊莉娅愿与你并肩。','protect'],['收下钱换取情报','你得到路线，但伊莉娅不会把安全交给你。','sell'],['欺骗出钱的人','你套出幕后联系人，却没能取得伊莉娅的完全信任。','deceive','欺骗',15]]},
  {area:'walls',place:'军需仓',label:'截住伪装成巡逻队的袭击者',text:'仓门被撬开，弓手占据高台，队长正准备焚毁报告。',skill:'察觉',dc:14},
  {area:'walls',label:'击退暗门伏兵',text:'救出失踪队员，击败假巡逻队。',battle:'gate_ambush'},
  {area:'wonders',npc:'ilya',label:'把失踪队员带回伊莉娅面前',text:'伊莉娅交出夜巡长弓，并决定是否成为队伍同伴。',finish:true,recruitOutcome:'protect'}
 ]},
 {id:'ledger',name:'听证席下的账簿',giver:'vessa',area:'hall',description:'找齐遭拆散的账簿，揭露谁在篡改公开听证。',reward:{gold:60,xp:125,item:'审计官胸针'},stages:[
  {area:'wonders',place:'修复室',label:'找回被剥掉的书脊',text:'书脊里有一串与听证席编号对应的刻痕。',skill:'调查',dc:15},
  {area:'hall',npc:'orlan',label:'说服保管员交出抄本',text:'奥兰要求先保证证人可以安全离开。',skill:'说服',dc:15},
  {area:'kegs',npc:'mara',label:'选择公布证据的方式',text:'酒馆已经聚集证人，门外却有带刀的人在记名字。',options:[['秘密护送证人','证人避开了耳目，记录更难质疑。','escort'],['即刻公开证据','民众聚集，但袭击者也知道了位置。','publish'],['欺骗监视者','监视者追逐假账簿，你赢得准备时间。','decoy','欺骗',15]]},
  {area:'hall',place:'旧印室',label:'比对真正的旧印',text:'真正的印章上有一道细裂痕，伪造品没有。',skill:'调查',dc:16},
  {area:'hall',label:'阻止焚毁听证账簿',text:'持火油的人封锁了记录廊，袭击者要烧掉最后的签名。',battle:'ledger_fire'},
  {area:'hall',npc:'vessa',label:'交付完整账簿',text:'维莎当众封存证据并支付委托报酬。',finish:true}
 ]},
 {id:'signal',name:'错误的第十三声',giver:'kevan',area:'walls',description:'调查假军令与钟声，阻止城防被用于制造冲突。',reward:{gold:52,xp:110,item:'信号手戒指'},stages:[
  {area:'walls',place:'北段瞭望台',label:'记录倒序灯号',text:'信号的起始时刻被提前了九息。',skill:'察觉',dc:15},
  {area:'hall',npc:'daran',label:'核对紧急军令',text:'达兰拿出投票记录，军令竟早于表决。',skill:'洞悉',dc:15},
  {area:'walls',npc:'samir',label:'决定如何保护信号手',text:'萨米尔愿意作证，却担心城墙上的同袍遭到连坐。',options:[['保护信号手与同袍','萨米尔交出原始信号簿。','protect'],['先公开他的名字','证词更快传开，部分士兵责怪你的鲁莽。','reveal'],['游说他匿名作证','他接受匿名质询，留下可验证的节拍。','anonymous','说服',16]]},
  {area:'hall',place:'议事高台',label:'测量第二道钟声',text:'回声与铜杯共振，证实钟声藏在墙里。',skill:'奥秘',dc:16},
  {area:'walls',place:'军需仓',label:'截获传令人的新命令',text:'命令要求把北段守卫调去无人的南门。',skill:'潜行',dc:16},
  {area:'walls',npc:'kevan',label:'交还原始信号簿',text:'凯文停止错误调度，结清委托，后续仍守在城墙。',finish:true}
 ]}
];
export const areaBattles = [
 {id:'gate_ambush',name:'暗门假巡逻队',intro:'火把从排风井落下；失踪队员被绑在通向军需仓的铁梯上。',foes:[['伪巡逻队长',48,16,5,4,7,'号令：每回合为友军增强攻势'],['暗门重甲兵',38,15,4,3,7,'格挡：护甲较高'],['暗门重甲兵',38,15,4,3,7,'格挡：护甲较高'],['高台弩手',30,14,5,4,6,'齐射：优先瞄准后排']]},
 {id:'ledger_fire',name:'记录廊焚证者',intro:'焚证术士以火油封门，铁卫和刀客分两路压向证人。',foes:[['焚证术士',52,16,6,5,8,'火油：攻击时造成更高伤害'],['护卷铁卫',46,17,5,4,7,'钢盾：护甲较高'],['侧廊刀客',36,15,6,4,7,'突袭：命中较高'],['火油投手',32,14,5,5,7,'投火：伤害较高']]}
];
export const wondersGoods = [
 {name:'修复师短剑',slot:'weapon',price:22,attack:1,damage:2,ac:0,unlock:0,rarity:'普通',description:'轻巧的修复工刀，攻击 +1，伤害 +2。'},
 {name:'高堂护胸',slot:'armor',price:36,attack:0,damage:0,ac:2,unlock:0,rarity:'精良',description:'分层铜片护胸，AC +2。'},
 {name:'刻度护符',slot:'offhand',price:40,attack:1,damage:0,ac:0,unlock:0,rarity:'精良',description:'星盘刻度制成，攻击 +1。'},
 {name:'银线药水',slot:'consumable',price:18,attack:0,damage:0,ac:0,unlock:0,rarity:'普通',description:'饮用恢复 14 HP。',effect:'heal'},
 {name:'护盾卷轴',slot:'consumable',price:24,attack:0,damage:0,ac:0,unlock:0,rarity:'精良',description:'使用后下一次受攻击 AC +4。',effect:'ward'},
 {name:'星火卷轴',slot:'consumable',price:28,attack:0,damage:0,ac:0,unlock:0,rarity:'精良',description:'战斗中以法术攻击造成 12–18 伤害。',effect:'damage'},
 {name:'净化药剂',slot:'consumable',price:30,attack:0,damage:0,ac:0,unlock:5,rarity:'精良',description:'恢复 20 HP 并清除倒地状态。',effect:'heal20'},
 {name:'夜巡长弓',slot:'weapon',price:70,attack:2,damage:5,ac:0,unlock:10,rarity:'稀有',description:'伊莉娅设计的弓，攻击 +2，伤害 +5。'},
 {name:'审计官胸针',slot:'offhand',price:65,attack:0,damage:0,ac:2,unlock:10,rarity:'稀有',description:'经过符文加固的徽章，AC +2。'},
 {name:'军令破咒卷轴',slot:'consumable',price:52,attack:0,damage:0,ac:0,unlock:10,rarity:'稀有',description:'战斗中以法术攻击造成 20–26 伤害。',effect:'damage20'},
 {name:'奥术回响法杖',slot:'weapon',price:92,attack:2,damage:3,ac:0,unlock:10,rarity:'稀有',description:'法师：法术命中 +2、伤害 +3；每场首个命中攻击法术额外 6 奥术伤害。'},
 {name:'信号手戒指',slot:'offhand',price:90,attack:2,damage:0,ac:1,unlock:15,rarity:'稀有',description:'校准过的传讯戒，攻击 +2，AC +1。'},
 {name:'星穹织法长袍',slot:'armor',price:138,attack:0,damage:0,ac:2,unlock:20,rarity:'稀有',description:'法师：AC +2，攻击法术伤害 +2。'},
 {name:'拱顶秘银剑',slot:'weapon',price:145,attack:4,damage:7,ac:0,unlock:20,rarity:'史诗',description:'稀少的秘银之刃，攻击 +4，伤害 +7。'},
 {name:'奇迹高堂守护甲',slot:'armor',price:170,attack:0,damage:0,ac:4,unlock:25,rarity:'史诗',description:'限量符文重甲，AC +4。'}
];

export const companionProfile={name:'伊莉娅·棱光',race:'半精灵',profession:'游侠',background:'拒绝伪造城墙换岗报告的奥术护卫，信任保护证人的队伍。',active:'棱光箭：消耗 1 次职业能力，以更高命中和额外 8 点伤害攻击。',passive:'城墙警觉：每场战斗第一回合命中 +2。'};

// V4 companion follows the same authored-area, quest, and battle catalogues.
areaNpcs.push({id:'aran',area:'wonders',name:'亚岚·铜脉',role:'矮人战地牧师与炉心修复师',background:'曾替城墙锻造防火铰链；一次仓库爆炸后，他偷偷保存了真实的伤亡名册。',personality:'说话简短，忌讳空洞的誓言，遇见伤者会先动手救人',attitude:'戒备',intro:'这炉火不是给你铸勋章的。先告诉我谁还留在墙外。',topics:[
 topic('封存的炉心在每次钟响时升温，仓库记录却说它早已报废。',['炉心藏着什么？','是被改写的撤离灯号；黄铜一热，假签名就浮上来。','他用钳子夹出一小块带字的铜皮。',1,'aran_copper'],['为何不交给大厅？','我试过。三个证人刚走出门就被人跟踪。','他让你去酒馆找保管伤亡表的人。',1,'aran_witness'],['你是不是自己弄坏了它？','我烧坏的是手，没烧坏名字。','他把烫伤的手藏进袖子。',-1,'aran_accuse']),
 topic('真正的医药包不该只给有徽章的人。',['你曾在城墙救过谁？','一名传令兵和两个被命令留在外侧的工人；他们现在还活着。','他写下两名工人的外号。',1,'aran_rescue'],['可以教我处理伤口吗？','热铁不能直接贴上去。先洗净，再看有没有毒。','他把一卷干净绷带放在桌上。',1,'aran_heal'],['我们缺一名牧师。','缺人的队伍不少。我只跟肯把伤员带回来的人走。','他等你解释行动计划。',0,'aran_wait']),
 topic('我曾为错误的门令铸过闩。现在想亲手把它拆下来。',['谁给你的图纸？','盖印的是大厅，画线的人却来自军需仓。','他指出图纸上故意少画的一道排水沟。',1,'aran_plan'],['你愿意与伊莉娅合作吗？','她守证人，我救伤员。如果你们不卖掉任一方，我愿意。','他第一次抬眼看向你的队伍。',1,'aran_ilya'],['事情结束以后呢？','还得有人补好城墙。胜利不是在酒馆里说一句话。','他把钳子塞回腰带。',0,'aran_future'])
]});
areaQuests.push({id:'hearth',name:'被封存的炉心',giver:'aran',area:'wonders',description:'追踪被军需仓封存的炉心和失踪伤员，决定是否邀请修复师亚岚同行。',reward:{gold:68,xp:135,item:'炉心护符'},stages:[
 {area:'wonders',place:'修复室',label:'检验炉心留下的热纹',text:'铜片上的夜间灯号比官方档案晚了整整九息。',skill:'调查',dc:15},
 {area:'kegs',npc:'sera',label:'核对酒馆保管的伤亡表',text:'瑟拉把两名工人的名字圈出：他们被登记成了无名死者。',skill:'洞悉',dc:14},
 {area:'hall',npc:'vessa',label:'要求审计官提供军需仓封存令',text:'维莎找出一份用旧印盖的新命令，足以让你们合法接近城墙。',skill:'说服',dc:15},
 {area:'walls',place:'军需仓',label:'发现被困伤员与尚未冷却的炉心',text:'铁门后有人敲出三声短讯；伏兵正在把炉心拖走。',skill:'察觉',dc:16},
 {area:'walls',npc:'kevan',label:'决定行动优先次序',text:'队长肯分出人手，却要求你们先说明是否要带走仍活着的证人。',options:[['先救伤员并邀请亚岚','凯文打开侧门；亚岚相信你们愿意保护活人。','invite','说服',14],['先保住铜片证据','你保全了文件，但亚岚要继续独自照料伤员。','evidence'],['付钱请守卫私下放行','道路畅通，却失去了亚岚的信任。','bribe']]},
 {area:'walls',label:'阻止焚毁炉心',text:'带盾的佣兵试图堵死侧门，术士在高台点燃引线。',battle:'hearth_raid'},
 {area:'wonders',npc:'aran',label:'交还名册并处理伤员',text:'亚岚核对完每个幸存者的名字，决定是否与你们并肩前行。',finish:true,recruitOutcome:'invite'}
]});
areaBattles.push({id:'hearth_raid',name:'军需仓炉心伏击',intro:'火光在军需仓的铰链上跳动；亚岚正带伤员撤向侧门。',foes:[['封锁队长',58,17,6,5,8,'号令：阻拦侧门撤离'],['重甲堵门兵',44,16,5,4,7,'格挡：重甲掩护'],['高台点火术士',38,15,6,6,8,'投火：点燃引线'],['后巷弩手',34,14,6,4,7,'齐射：瞄准低护甲目标']]});
export const secondCompanionProfile={name:'亚岚·铜脉',race:'矮人',profession:'牧师',background:'修复炉心时留下真实伤亡名册，拒绝让证人变成数字。',active:'战地祈祷：消耗能力次数，治疗一名队员；亦可使用符文震击。',passive:'矮人韧性：毒素豁免有优势，初始 HP 与护甲较高。'};

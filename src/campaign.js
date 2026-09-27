// Original Upper City campaign. Each chapter has several encounters; choice flags persist and shape later text/endings.
import {battleByChapter} from './battles.js';
export const acts = [
  {name:'序章 · 雨夜入城', lead:'一封没有署名的请柬把你们引到雨中的上城区。', chapters:[
    ['城门的第十三辆车','一辆封死车窗的马车从城门驶入，车辙留有发亮的灰。守门人却说今夜只放行十二辆。','调查灰烬','询问守门人','ash','混入马车队','gate'],
    ['无人认领的包裹','寄存铺里有一只写着你们姓名的铜匣。掌柜坚称它已在这里等了十九年。','打开铜匣','铜匣密码','cipher','保护掌柜','keeper'],
    ['屋顶上的灯语','三座钟楼以灯光交换信号，其中一座塔早已废弃。','破译灯语','隐秘会面','signal','追上信使','courier'],
    ['下雨的宴会','欢迎宴的主人不见了，所有宾客却记得他刚刚致辞。','核对座次','缺席的主人','absence','安抚宾客','trust'],
    ['铜门之后','宅邸暗室里，一张新绘的地图把整个上城区分割成可出售的地块。','带走地图','地契地图','map','留下假地图','decoy']
  ]},
  {name:'第一幕 · 被出售的街道',lead:'失踪者与一桩秘密的土地交易有关。',chapters:[
    ['灰市账本','修表匠掌握赊账册，记着议员和搬运工之间不该存在的交易。','抄录账本','灰市账目','ledger','答应保护工人','workers'],
    ['玻璃花房','贵族的温室里种着只在废弃矿坑出现的白色蕨类。','分析蕨叶','矿坑孢子','spore','向园丁许诺帮助','gardener'],
    ['三封不同的信','失踪议员给家人、报社和街道理事留下三套互相矛盾的遗言。','比对笔迹','篡改的信','letters','公开其中一封','publicity'],
    ['夜巡队长','巡逻队长愿意开口，条件是你们找出被诬陷的同袍。','接受调查','巡逻证词','patrol','以金币换消息','bribe'],
    ['旧印章','地契上盖着早被熔毁的公民议会印章。','拓印印章','议会印记','seal','向街坊说明','neighbours']
  ]},
  {name:'第二幕 · 无声的契约',lead:'每个派系都在寻找原始契约。',chapters:[
    ['拍卖名单','地下拍卖将出售一页写着迁居令的古纸，买家中有人使用你们的名字。','潜入拍卖','拍卖名单','auction','与买家交涉','buyer'],
    ['钟楼机械','废钟楼的齿轮里藏着纸页的一半，守塔机械却认所有闯入者为敌。','拆解齿轮','齿轮暗格','gear','安抚守塔人','warden'],
    ['雨水图书馆','被水淹过的书库保存着旧城选票；馆长要求你们归还失窃的目录。','修复目录','旧城选票','ballots','承诺开放档案','archive'],
    ['白鸦信使','白鸦会把消息带给失踪议员，前提是你们先救出它的驯养人。','追踪白鸦','信使路线','raven','营救驯养人','handler'],
    ['两份真相','交易清单是真的，拆迁命令也是真的；签字日期却相隔三十年。','核对年代','错位日期','dates','公布矛盾','expose']
  ]},
  {name:'第三幕 · 地下的名字',lead:'被抹去的人仍住在城市的地基之下。',chapters:[
    ['旧水道','水道居民用空白面具隐去姓名，只以交换故事作为通行费。','分享经历','无名者口述','testimony','带药给居民','medicine'],
    ['盐井哨站','炼金废水让井边的守卫失去理智；他们衣领上缝着上城区的徽章。','搜查哨站','炼金徽章','alchemist','救助伤者','rescued'],
    ['深井之战','一只因废液变异的甲壳兽拦住取证道路。','备战','甲壳残片','shell','寻找绕行路线','bypass'],
    ['没有名字的法官','地下法官保有当年驱逐案卷，他要求你们保证证人能活到听证日。','保护证人','驱逐案卷','verdict','交换护卫承诺','witness'],
    ['失踪者归来','议员还活着，但他主动销毁过证词。你们须决定是否与他合作。','质询议员','议员供词','confession','给予作证机会','mercy']
  ]},
  {name:'第四幕 · 城市的裂缝',lead:'证据将引发行动，旧盟友也会要求回报。',chapters:[
    ['镜厅议会','公开听证前，有人把唯一的证人引进充满镜子的长廊。','封锁长廊','镜厅脚印','mirror','保护证人','protected'],
    ['钟声停下','城里的钟一起停住。停钟命令来自现任执政官的私人办公室。','潜入办公室','停钟命令','order','接触改革派','reform'],
    ['断桥封锁','卫队封桥搜捕调查者；帮过的工人或地下居民或许愿意开路。','尝试谈判','封桥令','bridge','请求旧盟友','allies'],
    ['档案保卫战','纵火者涌向图书馆，证据和馆员都在里面。','组织守卫','纵火工具','arson','先救馆员','librarians'],
    ['城市投票','四个派系提出方案：复兴议会、有限改革、旧秩序或地下自治。','收集意见','各派条件','factions','举行公开集会','assembly']
  ]},
  {name:'终幕 · 黎明判决',lead:'你们作出的选择会决定谁拥有城市的明天。',chapters:[
    ['原始契约','最终契约规定，土地属于所有在这里生活并为其负责的人。','鉴定契约','原始契约','contract','邀请所有派系','unity'],
    ['最后的守门人','执政官的护卫堵在会议厅。他收到的命令与真正的契约相矛盾。','展示证据','矛盾命令','guard','争取守卫','defector'],
    ['议会之战','谈判破裂后，一队雇佣兵冲入大厅；你们须守住证据。','迎战','雇佣契约','mercenary','疏散市民','civilians'],
    ['公开判决','在所有人面前，决定档案归属和城市的制度。','恢复公民议会','公民议会','council','建立地下自治','autonomy'],
    ['黎明之后','街道还在，城市却已经变了。盟友根据一路的承诺决定留下或离开。','记录后日谈','队伍编年史','epilogue','继续探索','legacy']
  ]}
];
export const chapters=acts.flatMap((act, ai)=>act.chapters.map((c,ci)=>({id:ai*5+ci,act:act.name,lead:act.lead,title:c[0],text:c[1],choices:[{label:c[2],clue:c[3],flag:c[4]},{label:c[5],flag:c[6]}],combat:battleByChapter.has(ai*5+ci)})));
export const classes={战士:{hp:14,ac:16,stats:[16,12,14,10,10,10],attack:5,damage:8,skill:'运动'},游荡者:{hp:10,ac:14,stats:[10,16,12,12,10,12],attack:5,damage:6,skill:'调查'},法师:{hp:8,ac:12,stats:[8,12,12,16,12,10],attack:5,damage:8,skill:'奥秘'},牧师:{hp:11,ac:15,stats:[12,10,14,10,16,12],attack:4,damage:6,skill:'洞悉'},游侠:{hp:11,ac:14,stats:[12,16,12,12,14,10],attack:5,damage:8,skill:'求生'},吟游诗人:{hp:10,ac:13,stats:[10,14,12,12,10,16],attack:4,damage:6,skill:'说服'}};

export const npcs=[
 {name:'伊莱娅·维恩',role:'失踪议员的档案员',chapter:3,dialogue:'「名单上没有他的名字，可我亲手替他写过请柬。」'},
 {name:'穆雷',role:'灰市修表匠',chapter:5,dialogue:'「钟表不说谎。人会把它拨慢。」'},
 {name:'赛洛',role:'雨水图书馆馆长',chapter:12,dialogue:'「一份被淹的投票记录，仍是一份投票记录。」'},
 {name:'无名法官',role:'地下证人守护者',chapter:18,dialogue:'「让证人活着到天亮，我便给你们整卷真相。」'},
 {name:'露佩',role:'街区工人领袖',chapter:22,dialogue:'「桥可以封，街道记得我们的脚步。」'},
 {name:'凯尔·索恩',role:'执政官的守门人',chapter:26,dialogue:'「拿出命令的原件，我会听。」'}
];
export const sideQuests=[
 {title:'保护灰市工人',from:5,to:22,flag:'workers',reward:'断桥时获得工人支持'},
 {title:'归还图书目录',from:12,to:23,flag:'archive',reward:'保全更多旧城档案'},
 {title:'救助盐井伤者',from:16,to:24,flag:'rescued',reward:'地下居民愿意作证'},
 {title:'守护证人',from:18,to:20,flag:'witness',reward:'听证会获得关键证词'},
 {title:'争取守门人',from:26,to:27,flag:'defector',reward:'议会守卫放下武器'}
];
export function contextualText(chapter,flags=[]){
 const extra=[];
 if(chapter.id>=20&&flags.includes('workers'))extra.push('曾得到你们帮助的工人已经开始联络各街区。');
 if(chapter.id>=20&&flags.includes('archive'))extra.push('图书馆保存了你们带回的原始档案。');
 if(chapter.id>=20&&flags.includes('rescued'))extra.push('盐井的幸存者愿意以自己的姓名作证。');
 if(chapter.id>=25&&flags.includes('mercy'))extra.push('获宽恕的议员带来了另一份证词。');
 if(chapter.id>=27&&flags.includes('defector'))extra.push('守门人和他的部下选择为你们开路。');
 return [chapter.text,...extra].join(' ');
}

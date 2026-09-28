// Original, intentionally compact campaign rules. These are not D&D 5e spells.
// The matching SQL catalog is generated from this file; the server owns every effect.
const p=(id,profession,ring,kind,amount,name,description)=>({id,profession,ring,kind,amount,name,description});

export const powers=[
  p('fighter_strike','战士',0,'damage',12,'破阵斩','强力近战攻击。'),
  p('fighter_wind','战士',0,'heal',7,'坚韧复起','恢复自己或队友的生命。'),
  p('rogue_sneak','游荡者',0,'damage',13,'背刺','趁破绽造成高额伤害。'),
  p('rogue_smoke','游荡者',0,'ward',3,'烟幕闪避','抵挡下一次敌人攻击。'),
  p('wizard_bolt','法师',0,'damage',9,'奥术飞矢','基础奥术攻击。'),
  p('wizard_focus','法师',0,'ward',2,'秘法护罩','保护一名队员。'),
  p('cleric_light','牧师',0,'damage',9,'辉光打击','以神圣光芒攻击。'),
  p('cleric_prayer','牧师',0,'heal',8,'祈祷','治疗一名队员。'),
  p('ranger_arrow','游侠',0,'damage',11,'追踪箭','瞄准敌人的行踪。'),
  p('ranger_herbs','游侠',0,'heal',7,'野外草药','治疗一名队员。'),
  p('bard_note','吟游诗人',0,'damage',9,'裂音','用共鸣打乱敌人。'),
  p('bard_inspire','吟游诗人',0,'ward',3,'鼓舞','保护一名队员。'),
  p('paladin_smite','圣武士',0,'damage',11,'誓约重击','用神圣武器攻击。'),
  p('paladin_hands','圣武士',0,'heal',9,'圣疗','触碰并治疗一名队员。'),

  p('wizard_1','法师',1,'damage',11,'星火','引燃凝聚的星尘。'),
  p('wizard_2','法师',2,'ward',4,'镜面屏障','折射下一次袭击。'),
  p('wizard_3','法师',3,'damage',19,'雷霆弧','闪电贯穿敌人的防线。'),
  p('wizard_4','法师',4,'weaken',2,'重力扭曲','降低敌人的护甲和攻击。'),
  p('wizard_5','法师',5,'damage',30,'坠星','召来一颗炽热陨星。'),
  p('wizard_6','法师',6,'damage',38,'流星破城','释放强大的星陨冲击。'),

  p('cleric_1','牧师',1,'heal',12,'晨光疗愈','恢复队员生命。'),
  p('cleric_2','牧师',2,'damage',16,'净焰','焚除敌人的邪祟。'),
  p('cleric_3','牧师',3,'heal',23,'生命圣言','大幅恢复一名队员。'),
  p('cleric_4','牧师',4,'ward',5,'庇佑圣域','保护队员免受袭击。'),
  p('cleric_5','牧师',5,'damage',29,'审判之光','凝聚烈光打击敌人。'),
  p('cleric_6','牧师',6,'heal',40,'黎明复苏','救回重伤的队员。'),

  p('ranger_1','游侠',1,'damage',12,'荆棘箭','带刺箭矢追踪目标。'),
  p('ranger_2','游侠',2,'weaken',1,'困兽藤','缠住敌人，削弱防御。'),
  p('ranger_3','游侠',3,'damage',21,'猎鹰齐射','连续射出锐利箭矢。'),
  p('ranger_4','游侠',4,'heal',25,'森林复苏','唤醒自然生机。'),
  p('ranger_5','游侠',5,'damage',31,'风暴猎杀','箭雨随风暴落下。'),
  p('ranger_6','游侠',6,'damage',39,'星野追猎','向敌人的命运轨迹射击。'),

  p('bard_1','吟游诗人',1,'damage',11,'刺耳和弦','震动敌人的心神。'),
  p('bard_2','吟游诗人',2,'heal',16,'安魂曲','以旋律恢复队员生命。'),
  p('bard_3','吟游诗人',3,'weaken',1,'揭幕之歌','揭露敌人的防御破绽。'),
  p('bard_4','吟游诗人',4,'ward',5,'英雄赞歌','鼓舞一名队员抵挡伤害。'),
  p('bard_5','吟游诗人',5,'damage',30,'破晓乐章','用声浪击溃敌人。'),
  p('bard_6','吟游诗人',6,'heal',39,'不朽叙事','用传唱的故事挽回生命。'),

  p('paladin_1','圣武士',1,'damage',13,'炽誓','武器附着誓约火焰。'),
  p('paladin_2','圣武士',2,'heal',17,'守护祷文','治愈同伴的伤势。'),
  p('paladin_3','圣武士',3,'ward',4,'钢铁光环','保护身边的同伴。'),
  p('paladin_4','圣武士',4,'damage',26,'裁决之剑','将誓约化为一道剑光。'),
  p('paladin_5','圣武士',5,'heal',33,'复原圣歌','使濒死的同伴苏醒。'),
  p('paladin_6','圣武士',6,'damage',41,'破晓圣裁','倾尽神圣力量裁决敌人。'),
];

export const spellcasters=new Set(['法师','牧师','游侠','吟游诗人','圣武士']);
export const levelForChapter=chapter=>Math.min(12,1+Math.floor(chapter*2/5));
export const spellSlots=level=>[0,level>=1?Math.min(4,2+Math.floor((level-1)/2)):0,level>=3?Math.min(3,1+Math.floor((level-3)/2)):0,level>=5?Math.min(3,1+Math.floor((level-5)/2)):0,level>=7?Math.min(2,1+Math.floor((level-7)/2)):0,level>=9?1:0,level>=11?1:0];

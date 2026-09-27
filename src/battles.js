// Original encounters keyed by zero-based chapter. The database owns all numbers and rewards.
export const battles = [
  {chapter:2,name:'雨瓦追猎者',intro:'灯语被截获后，披着油布的追猎者沿湿滑屋脊围住信使。',hp:19,ac:12,attack:2,min:1,die:4,aid:'ash',aidText:'灰烬路线让队伍先占高处。'},
  {chapter:5,name:'灰市收账人',intro:'收账人带着没收工具闯进修表铺，要求交出所有账页。',hp:24,ac:13,attack:3,min:2,die:4,aid:'map',aidText:'地图标出的后门让工人及时撤离。'},
  {chapter:8,name:'冒名夜巡兵',intro:'假冒夜巡队的人试图逮捕证人，真正的队长被困在街口。',hp:26,ac:13,attack:3,min:2,die:5,aid:'workers',aidText:'受保护的工人指出了伪造的巡逻口令。'},
  {chapter:11,name:'失控的钟楼机械',intro:'守塔机械在齿轮间醒来，用铜臂封住藏有契约残页的暗格。',hp:29,ac:14,attack:3,min:2,die:5,aid:'auction',aidText:'拍卖名单标出了机械的制造商和停机记号。'},
  {chapter:14,name:'契约猎手',intro:'一名受雇猎手赶在你们核对日期前来毁掉原件。',hp:31,ac:14,attack:4,min:2,die:5,aid:'archive',aidText:'馆长留下的索引揭示了猎手的退路。'},
  {chapter:17,name:'盐井甲壳兽',intro:'废液变异的甲壳兽守住取证的深井，钟声响起时甲片张开。',art:'/images/salt-beast.webp',hp:35,ac:13,attack:4,min:3,die:6,aid:'rescued',aidText:'获救的守卫指出巨兽甲片的薄弱处。'},
  {chapter:20,name:'镜厅刺客',intro:'证人在镜厅遭到伏击，刺客借镜像隐藏行动路线。',hp:32,ac:14,attack:4,min:2,die:6,aid:'witness',aidText:'无名法官的护卫预先掩护了证人。'},
  {chapter:23,name:'档案纵火队',intro:'纵火者破窗闯入雨水图书馆，火星已经落在原始选票旁。',hp:34,ac:14,attack:4,min:3,die:5,aid:'archive',aidText:'保存好的目录指引馆员抢出证据。'},
  {chapter:26,name:'执政官铁卫',intro:'守门人的上级奉命截住契约原件，在议事厅入口布下铁卫。',hp:38,ac:15,attack:5,min:3,die:6,aid:'unity',aidText:'受邀的各派代表要求铁卫公开命令。'},
  {chapter:28,name:'议会雇佣兵首领',intro:'雇佣兵冲入大厅，试图烧毁证据并驱散参与公开判决的人。',art:'/images/council-battle.webp',hp:42,ac:15,attack:5,min:3,die:6,aid:'defector',aidText:'倒戈守卫挡住了首领的第一轮冲锋。'}
];
export const battleByChapter = new Map(battles.map(b=>[b.chapter,b]));

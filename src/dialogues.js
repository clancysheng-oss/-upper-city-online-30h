// Original dialogue scenes. Three server-owned conversations precede each chapter's investigations.
import { chapters } from "./campaign.js";
import { encounters } from "./encounters.js";
import { storyVoices } from './story-voices.js';
const cast = [
  ["守门人哈罗", "守住城门的老兵"],
  ["寄存铺掌柜艾尔", "保管铜匣的人"],
  ["信使诺娅", "熟悉屋顶灯语"],
  ["伊莱娅·维恩", "失踪议员的档案员"],
  ["管家赛芙", "宅邸暗室的看守"],
  ["穆雷", "灰市修表匠"],
  ["园丁塔姆", "花房的照料者"],
  ["报社编辑莉缇", "收过遗言的人"],
  ["夜巡队长维斯", "被调离的小队长"],
  ["街坊代表阿黛", "旧印章的见证人"],
  ["拍卖师兰恩", "地下拍卖的主持者"],
  ["守塔人格雷", "钟楼最后的维护者"],
  ["赛洛", "雨水图书馆馆长"],
  ["驯养人菲恩", "白鸦的伙伴"],
  ["登记官莫罗", "保管年代记录的人"],
  ["摆渡人萨雅", "地下水道的居民"],
  ["医师奥里", "盐井哨站的救护者"],
  ["矿工乌伦", "目击甲壳兽的人"],
  ["无名法官", "地下证人守护者"],
  ["议员埃弗", "归来的失踪者"],
  ["镜厅侍者菲娅", "熟悉镜中暗门"],
  ["钟匠杜伦", "维护城市总钟"],
  ["桥卫雷蒙", "接到封锁令的士兵"],
  ["馆员梅瑞", "抢救档案的人"],
  ["工人领袖露佩", "街区议事主持者"],
  ["公证人希尔", "契约鉴定人"],
  ["凯尔·索恩", "执政官的守门人"],
  ["平民代表娜芙", "议会大厅的见证人"],
  ["书记员罗温", "公开判决的记录者"],
  ["伊莱娅·维恩", "保存队伍编年史"],
];
export const dialogues = chapters.map((chapter, i) => {
  const [name, role] = cast[i],
    [lead, follow] = encounters[i], [opening, stakes, decision] = storyVoices[i];
  return {
    chapter: i,
    name,
    role,
    beats: [
      {
        text: opening,
        options: [
          {
            label: `追问：${lead[0]}`,
            reply: `${lead[1]} ${lead[4]}`,
            flag: `voice_${i}_inquiry`,
          },
          {
            label: `问起：${follow[0]}`,
            reply: `${follow[1]} ${follow[4]}`,
            flag: `voice_${i}_trust`,
          },
        ],
      },
      {
        text: stakes,
        options: [
          {
            label: `核实「${lead[6]}」的来历`,
            reply: `${lead[5]} ${lead[4]}`,
            flag: `approach_${i}_aid`,
          },
          {
            label: `先保护「${follow[6]}」的证人`,
            reply: `${follow[5]} ${follow[4]}`,
            flag: `approach_${i}_caution`,
          },
        ],
      },
      {
        text: decision,
        options: [
          {
            label: `争取${name}支持「${chapter.choices[0].label}」`,
            reply: `“${lead[4]}”${name}决定留下，帮助核验${lead[6]}。`,
            flag: `support_${i}_stay`,
          },
          {
            label: `请${name}协助「${chapter.choices[1].label}」`,
            reply: `“${follow[4]}”${name}带走${follow[6]}的线索，约定安全地点再见。`,
            flag: `support_${i}_protect`,
          },
        ],
      },
    ],
  };
});
if (dialogues.length !== 30) throw Error("Dialogue must cover the campaign");

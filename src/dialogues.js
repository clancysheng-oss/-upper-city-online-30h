// Original dialogue scenes. Three server-owned conversations precede each chapter's investigations.
import { chapters } from "./campaign.js";
import { encounters } from "./encounters.js";
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
    [lead, follow] = encounters[i];
  return {
    chapter: i,
    name,
    role,
    beats: [
      {
        text: `${chapter.text} ${name}在现场等你们，想先弄清你们为何介入。`,
        options: [
          {
            label: `向${name}询问：${lead[0]}`,
            reply: `${name}低声说：“${lead[1]}”你们知道该从哪里着手。`,
            flag: `voice_${i}_inquiry`,
          },
          {
            label: `先听${name}讲述自己的处境`,
            reply: `${name}说：“${follow[1]}”这份信任会影响后面的交涉。`,
            flag: `voice_${i}_trust`,
          },
        ],
      },
      {
        text: `${name}把局面说得更清楚：“${follow[1]}”现在你们得决定先以什么态度接近这场风波。`,
        options: [
          {
            label: `承诺协助，再调查「${lead[0]}」`,
            reply: `${name}接受承诺，指向${lead[0]}的关键位置。你们可以开始探索。`,
            flag: `approach_${i}_aid`,
          },
          {
            label: `保留判断，先调查「${follow[0]}」`,
            reply: `${name}尊重你们的谨慎，交代${follow[0]}的来龙去脉。`,
            flag: `approach_${i}_caution`,
          },
        ],
      },
      {
        text: `${name}摊开地图：“${chapter.choices[0].label}和${chapter.choices[1].label}会通向不同的后果。先查清${lead[0]}与${follow[0]}，再决定。”`,
        options: [
          {
            label: `请${name}继续留在现场协助`,
            reply: `${name}答应留守，并将${lead[0]}的细节记入队伍记录。`,
            flag: `support_${i}_stay`,
          },
          {
            label: `请${name}先去照看可能受牵连的人`,
            reply: `${name}离开前交代了${follow[0]}的隐蔽路径，承诺在安全处接应。`,
            flag: `support_${i}_protect`,
          },
        ],
      },
    ],
  };
});
if (dialogues.length !== 30) throw Error("Dialogue must cover the campaign");

# Upper City 30H — Party Edition

## 这版的联机流程
- 创建队伍：自动生成 5 位邀请码，创建者成为 👑 房主。
- 加入队伍：输入邀请码，或打开房主复制的邀请链接。
- 组队大厅：显示玩家、职业、房主、准备状态与 2–5 人队伍人数。
- 全员准备后，只有房主能点击“开始冒险”。
- 进入游戏后：剧情、任务、线索、战斗和消息为全队共享；只有房主能推进剧情。
- 玩家可独立发送行动、D20 和攻击。
- 邀请链接支持 `?party=ABCDE` 自动填入队伍码。

## 安装
1. Supabase SQL Editor 运行 `upgrade.sql` 一次。
2. 用 `index.html` 替换现有 GitHub 仓库的 `index.html`。
3. Commit & Push，Vercel 自动部署。
4. 第一次在网页“连接设置”填写 Project URL 和 anon/public key。

说明：当前 RLS 为私人测试用公开 demo policy，正式公开网站前应改为认证和更严格权限。

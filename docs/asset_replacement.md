# 在 Godot 中替换素材

游戏以 1920×1080 为基准，角色根节点为脚底，比赛落点由 core/player_motion.gd 的地面曲线和平台决定。现有角色是原创示意图，不是正式 Wuppo 素材。

## 一个入口管理外观

打开 `assets/characters/skin_catalog.tres`。其中八个 Skins 条目同时用于大厅预览、外观选择和比赛。可直接替换对应槽位的资源，所有联机玩家使用相同目录和槽位顺序。增加槽位时同步调整 NetworkSession 的 SKIN_COUNT，并发布新的构建。

复制一个 `*_skin.tres`，然后在该资源中替换：

- Display Name：显示名称。
- Animations：SpriteFrames 帧动画。
- Body Tint：角色颜色，使用已经上色的贴图时设为白色。
- Visual Scale / Visual Offset：尺寸和站立位置。
- Release Hop Height / Release Hop Duration：放出后的轻跳高度和时长，默认 14 像素 / 0.18 秒。
- Mouth Offset：嘴部相对精灵中心的位置，默认 (24,11)，用于挂接原创圆锥管。Bubble Texture / Bubble Max Size：泡泡图片与最大显示尺寸；泡泡根据自身半径贴住管口。Bubble Offset 字段不控制吹气位置。
- Release Sound / Burst Sound / Victory Sound：放出、爆裂与本地优胜音效；留空使用全局默认音效。

将新资源放进目录的某个槽位即可。

## 动画

展开 Animations，在 SpriteFrames 面板编辑。默认 `default_frames.tres` 在八个皮肤间共用；只改某一个外观时先复制动画资源，或在检查器中选择“设为唯一”。

约定动画名：`idle` 待机、`blow` 吹气、`warning` 初步提醒、`danger` 危险、`critical` 临界、`release` 放出反应、`burst` 爆裂反应、`celebrate` 优胜庆祝。

支持逐帧图片与精灵图集，可调整帧率及循环。`idle`、`blow`、`warning`、`danger`、`critical`、`celebrate` 通常循环；`release`、`burst` 通常不循环。缺少 danger 或 critical 时优先回退到 warning；其他缺失动画回退到 idle。默认待机与吹气动画为两帧；请按美术需要增加帧数。

角色朝右，节点原点是站立点。图片不必保持默认 96×96，但替换后要调整缩放与偏移。

## 帽子

帽子与角色颜色分别选择。复制 `assets/hats/*_hat.tres`，设置 Display Name、Texture、Offset、Scale 和 Tint，并加入 `assets/hats/hat_catalog.tres`。Texture 支持导入的 PNG、SVG 等 Texture2D，Offset 相对角色脚底原点，帽子会跟随角色运动和放出小跳。无帽子资源留空 Texture 即可。仅换贴图不需改脚本；增加槽位时同步调整 NetworkSession 的 HAT_COUNT，并给所有玩家发布相同构建。

## 泡泡与背景

放出的泡泡使用当前皮肤的 Bubble Texture，以固定水平速度和恒定向上加速度沿开口向上的抛物线飞行，到期直接移除、不渐变消失；达到 92% 完美阈值时泡泡本体变黄，不绘制周围圈圈，并播放单声清脆音效。爆裂时大泡泡收缩并随机分成 2–4 个直径为大泡泡 20%–50%、沿开口向上的抛物线飞行的小泡泡；大小随机，到期直接移除、不渐变消失，小泡泡复用当前皮肤的 Bubble Texture。修改图片尺寸不影响计分。

背景由 `ui/stage_background.gd` 原创绘制，无参考图贴图。地面形状、实际落点与平台坐标统一在 `core/player_motion.gd`，修改地形时必须一起更新共享数据，避免画面与碰撞错位。`core/world_layout.gd` 统一可玩边界、1920×1080 基准及角色与提示缩放。

## 音效与规则

`assets/audio/` 为项目合成的默认短音效，可直接替换 WAV，也可给每个皮肤设置独立 AudioStream。角色口哨、放出和爆裂音效会依本机听者与角色位置进行距离衰减和左右声像定位；倒计时、结算提示由 AudioManager 使用，静音设置作用于全部效果。蓄力提示音由 AudioManager 程序生成。

打开 `modes/bubble_race/bubble_config.tres` 修改 Bubble Seconds Min / Max、Warning Ratio / Danger Ratio / Critical Ratio、Minimum Hold 和计分倍率。当前泡泡随机范围为 1.5–4.0 秒，最低有效吹气时长为 0.3 秒。基础得分为 `实际吹气秒数 × Points Per Second × (0.6 + 0.4 × 有效进度平方)`；完美泡泡和口哨奖励见 [泡泡随机与计分](balanced_randomness.md)。

正式替换素材后在编辑器等待导入完成，再启动游戏。规则或素材目录变更后，给全部玩家发布同一构建。

# 项目结构与维护边界

项目入口为 `scenes/main_menu.tscn`，Godot 配置和当前游戏版本位于根目录 `project.godot`。主要内容按功能放在以下目录：

| 路径 | 用途 |
| --- | --- |
| `actors/` | 角色和可复用实体 |
| `assets/` | 图片、音频、皮肤和帽子资源 |
| `core/` | 网络会话、移动、比赛阶段、设置、音频和存档 |
| `data/` | 玩法参数、资源定义和目录 |
| `modes/bubble_race/` | 泡泡比赛场景、规则、计分和随机池 |
| `modes/mud_ball/` | 弗纳克球场景、球类规则和练习伙伴 |
| `scenes/`, `scripts/`, `ui/` | 场景入口、休息室逻辑和界面组件 |
| `tests/` | 玩法与网络烟雾检查 |
| `docs/` | 当前玩法、联机、素材和维护说明 |

## 共享模块

- `core/player_motion.gd` 和 `data/player_movement_config.tres` 为休息室和比赛提供共用移动逻辑与参数。
- `core/match_player_input.gd` 处理比赛间共用的移动、跳跃、蹲下和口哨输入。
- `core/network_session.gd` 管理房间、玩家名单、同步、恢复和联机协议。两个玩法都依赖它。
- `core/match_controller.gd` 与泡泡比赛控制器共同管理比赛流程；弗纳克球玩法在此基础上增加球类状态。
- `scripts/main_menu.gd` 与 `ui/menu_room.gd` 协调休息室、后院、玩家呈现和本地双人视图。

上述共享文件会影响多个玩法。修改其接口或同步字段时，应一并更新调用方和相应检查。

## 常见维护入口

- 角色颜色：`assets/characters/`、`skin_catalog.tres`。
- 帽子：`assets/hats/`、`hat_catalog.tres`。
- 泡泡规则与计分：`modes/bubble_race/bubble_rules.gd`、`bubble_config.tres`、`data/bubble_config.gd`。
- 玩家移动：`core/player_motion.gd`、`core/match_player_input.gd` 和 `data/player_movement_config.tres`。
- 房间和外观选择：`scenes/main_menu.tscn`、`scripts/main_menu.gd`、`ui/menu_room.gd`。
- 后院和跨区域移动：`scenes/backyard.tscn`、`ui/backyard.gd`、`core/backyard_layout.gd`、`core/lobby_motion.gd`。
- 种植、经济和存档：`data/plant_catalog.gd`、`core/garden_save.gd`、`ui/garden_art.gd`。
- 联机 RPC、快照或协议：`core/network_session.gd` 和 [联机约定](network_protocol.md)。

## Godot 资源注意事项

- 使用 Godot 4.7.2 打开 `project.godot`。按 F5 运行主场景。
- `.godot/` 是编辑器缓存；资源旁的 `.import` 和 `.uid` 文件由 Godot 管理，不要手工编辑。
- 场景和资源引用使用 `res://` 项目内路径，不要写入机器专属的绝对路径。
- 新增或替换素材时，确认有权在本项目中修改和再分发，并记录需要保留的署名。
- 存档位于 Godot `user://` 目录。变更存档结构时要考虑已有玩家数据的兼容性。

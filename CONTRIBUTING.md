# 参与维护

欢迎提交问题报告、玩法修正、素材改进和文档更新。开始改动前，请先阅读根目录 `README.md` 和 [项目结构说明](docs/project_structure.md)。

## 开发环境

- 使用 Godot 4.7.2 打开 `project.godot`。
- Windows 启动脚本会先导入项目资源，再运行游戏。Godot 可执行文件应在 `PATH` 中，或通过 `GODOT` 环境变量指定。例如：

  ```cmd
  set "GODOT=C:\path\to\Godot_v4.7.2-stable_win64.exe"
  run_game.cmd
  ```

- `run_two_windows.cmd` 可用于本机双窗口联机检查。
- 网络条件检查使用 Python 标准库和 Godot 命令行程序；Godot 需在 `PATH` 中或由 `GODOT` 指定。

## 协作方式

- 每个改动集中处理一个问题或一项功能，并通过 Pull Request 合并。
- 尽量限制改动范围在一个玩法或资源领域。修改 `core/`、`scripts/main_menu.gd`、共享 UI 或共享数据时，先检查所有玩法和本地双人使用方。
- 对联机协议、RPC、快照或房主裁定的修改，要同时检查主机与客户端，并更新 [联机约定](docs/network_protocol.md)。协议版本和构建标识由 `core/network_session.gd` 管理；不兼容的字段变化需要更新协议号。
- 对 `core/garden_save.gd` 或种植数据的修改，要考虑已有 `user://` 存档。
- 只提交有权修改和再分发的代码、图片、音频与字体。保留素材原有署名和许可说明。

## 检查

根据改动范围运行对应的 Godot 烟雾脚本，例如：

```text
godot --headless --path . --script tests/mud_ball_smoke.gd
godot --headless --path . --script tests/garden_smoke.gd
godot --headless --path . res://tests/garden_storage_smoke.tscn
```

网络条件检查可运行：

```text
python tests/network_conditions.py latency
python tests/network_conditions.py reconnect
python tests/network_conditions.py handover
python tests/network_conditions.py crash
```

网络条件检查会启动多个 Godot 进程并占用 UDP 7000；运行前请关闭其他使用该端口的游戏实例。部分网络检查会主动中断测试进程。

提交前请确认项目能在编辑器中打开、改动相关检查已运行，并且没有加入 `.godot/` 缓存、导出包、个人存档或未经授权的素材。

## 贡献授权

提交贡献即表示你同意将自己有权许可的贡献按根目录 `LICENSE` 中的 MIT 条款提供，适用范围以该文件说明为准。该许可不扩展到 Wuppo 或其他第三方拥有的名称、角色和内容。

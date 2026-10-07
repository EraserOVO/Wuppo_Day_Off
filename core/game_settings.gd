extends Node

const PREFERENCES_PATH := "user://preferences.cfg"
const ACTION_NAMES := ["向左", "向右", "跳跃 / 二段跳", "吹泡泡 / 大厅交互", "吹口哨"]
const DEFAULT_KEYS := [[KEY_A, KEY_D, KEY_W, KEY_K, KEY_L], [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_KP_0, KEY_KP_PERIOD]]
const ENGLISH_TEXT := {
	"帽子": "Hats", "染色泡泡": "Dye Bubbles", "售出": "Sell", "购买数量": "Quantity", "1 个": "1", "5 个": "5", "确认购买": "Confirm purchase", "确认购买 · %s 斯马特": "Confirm purchase · %s Smurt", "价格：%s 斯马特": "Price: %s Smurt", "价格：%s 斯马特 · 库存：%s": "Price: %s Smurt · In stock: %s", "%s种子": "%s seed", "%s染色泡泡": "%s Dye Bubble",
	"种下后约 %s 分钟成熟，可收获出售。": "Matures in about %s minutes, then can be harvested and sold.", "成熟作物，可在种子摊出售。": "A mature crop, ready to sell at the seed cart.", "移除当前佩戴的帽子。": "Remove the currently equipped hat.", "装饰帽子，可在物品栏中穿戴。": "A decorative hat you can equip from your inventory.", "食用后改变角色颜色。": "Eat it to change your character's color.", "本地货币，可用于购买种子和装扮。": "Local currency for seeds and apparel.",
	"向左": "Move left", "向右": "Move right", "跳跃 / 二段跳": "Jump / Double jump", "吹泡泡 / 大厅交互": "Blow bubble / Interact", "吹口哨": "Whistle",
	"左": "Left", "右": "Right", "左键": "Left click", "右键": "Right click", "鼠标 %s 键": "Mouse %s button", "移动": "Move", "跳跃": "Jump", "蹲下": "Crouch", "吹泡泡": "Blow bubble", "交互": "Interact", "口哨": "Whistle",
	"关闭窗口": "Close window", "正在前往吹泡泡比赛……": "Going to the Bubble Race…", "物品栏": "Inventory", "斯马特": "Smurt", "斯马特（smurt）": "Smurt", "手持：无": "Holding: Nothing", "手持：%s": "Holding: %s", "物品": "Items", "服饰 · 帽子": "Apparel · Hats", "服饰 · 染色泡泡": "Apparel · Dye bubbles", "无": "None", "染色泡泡：": "Dye bubble: ", "种子：": "Seed: ", "收获物：": "Produce: ", "不戴帽子": "Remove hat", "种子": "Seed", "收获物": "Produce", "种": "Seed", "收": "Crop", "%s：%s ×%s": "%s: %s ×%s", "%s染色泡泡 ×%s": "%s dye bubble ×%s",
	"等待所有参赛玩家\n": "Waiting for all players\n", "已加载": "Loaded", "加载中……": "Loading…", "等待所有参赛玩家": "Waiting for all players", "小提示：": "Tip: ",
	"退出游戏": "Quit game", "确定要退出游戏吗？": "Are you sure you want to quit?", "退出对局": "Leave match", "退出对局？": "Leave match?", "确定退出当前对局并返回大厅吗？": "Leave this match and return to the lobby?", "游戏已暂停": "Game paused", "对局已暂停。继续游戏，或退出当前对局返回大厅。": "The match is paused. Resume or leave the match and return to the lobby.", "继续游戏": "Resume", "确认退出": "Confirm", "已退出对局。": "Left the match.", "再来一局": "Play again", "返回大厅": "Return to lobby", "返回大厅，准备下一局": "Return to lobby and ready up", "比赛结束": "Match over", "等待所有玩家加载……": "Waiting for all players to load…", "已暂停 · 按 Esc 继续": "Paused · Press Esc to resume", "暂停 · 等待连接恢复": "Paused · Waiting for connection", "准备  %s": "Ready  %s", "左队": "Left team", "右队": "Right team", "%s获胜！\n%s : %s": "%s wins!\n%s : %s", "%s 分 · 最大 %s": "%s pts · Best %s",
	"电脑伙伴": "Practice partner", "练习伙伴": "Practice partner", "对手": "Opponent", "你": "You", "等待对手": "Waiting for opponent", "已离开玩家": "Player left",
	"本局优胜：%s": "Round winner: %s", "本局没有放出有效泡泡，下一局再试试！": "No valid bubbles this round. Try again next round!", "最大泡泡奖：%s（%s 分）": "Largest bubble: %s (%s pts)", "等待房主返回大厅，再准备下一局。": "Waiting for the host to return to the lobby before the next round.", "玩家": "Player", "得分": "Score", "放出": "Released", "爆裂": "Burst", "结果": "Result", "优胜": "Winner", "最大泡泡": "Largest bubble", "完美泡泡": "Perfect bubble", "+%s分": "+%s pts", "口哨助攻 +%.1f分": "Whistle assist +%.1f pts", "口哨击破 ×%s · +%.1f分": "Whistle burst ×%s · +%.1f pts",
	"蓄力达到 92% 可以吹出完美泡泡。": "Charge to 92% for a perfect bubble.", "跳跃键再按一次，就能在空中二段跳。": "Press jump again in midair to double jump.", "口哨能干扰附近正在吹泡泡的对手。": "Whistling can disrupt nearby opponents blowing bubbles.", "吹得太久会爆裂，及时松开吹泡泡键。": "Bubbles burst if you blow too long. Release the button in time.", "休息室里的口哨只有声音，不会影响别人。": "Whistles in the lounge are only for fun and do not affect others.",
	"已读取上一份有效存档备份。": "Loaded the most recent valid save backup.", "种子与斯马特": "Seeds and Smurt", "当前余额：%s 斯马特": "Balance: %s Smurt", "种子 %s 斯马特 · 成熟约 %s 分钟（±5%%）· 售价 %s 斯马特": "Seeds cost %s Smurt · Grows in about %s min (±5%%) · Sells for %s Smurt", "种子库存：%s · 已收获：%s": "Seeds: %s · Harvested: %s", "购买 1 份种子 · %s 斯马特": "Buy 1 seed · %s Smurt", "购买 5 份种子 · %s 斯马特": "Buy 5 seeds · %s Smurt", "已购买一份%s种子。": "Bought one %s seed.", "已购买五份%s种子。": "Bought five %s seeds.", "染色泡泡 · 点击购买后放入物品栏": "Dye bubbles · Buy to add them to your inventory", "帽子 · 购买后可在物品栏穿戴": "Hats · Buy, then equip from your inventory", "试戴": "Try on", "已购买": "Owned", "购买 · %s": "Buy · %s", "买下了%s。": "Bought %s.", "%s泡泡%s": "%s dye bubble%s", "试色": "Try color", "买下了%s染色泡泡。": "Bought the %s dye bubble.", "库存：%s": "In stock: %s",
	"游玩模式": "Play mode", "当前房间模式": "Current room mode", "单人": "Single player", "本地双人": "Local 2-player", "多人": "Online multiplayer", "房间模式由房主 P1 设置。": "The host (P1) sets the room mode.", "联机房间": "Online room", "创建联机房间（最多 4 人）": "Create online room (up to 4 players)", "房主 LAN / VPN 地址，同电脑用 127.0.0.1": "Host LAN / VPN address (use 127.0.0.1 on this computer)", "加入房间": "Join room", "请输入房主地址。": "Enter the host address.", "房间状态：": "Room status: ", "已准备": "Ready", "未准备": "Not ready", "准备 / 取消准备": "Ready / Unready", "房间比赛时长": "Room match duration", "30 秒": "30 sec", "60 秒": "60 sec", "90 秒": "90 sec", "主机地址：": "Host address: ", "UDP 7000 · 请确认使用双方可访问的网卡地址": "UDP 7000 · Use a network address both players can reach", "离开联机房间": "Leave online room", "玩家资料": "Player profile", "玩家昵称": "Player name", "操作键位": "Controls", "个人键位（点击后按键或点击鼠标，Esc 取消）": "Personal controls (press a key or click, Esc to cancel)", "请按新键位……": "Press a new key…", "恢复自己的默认键位": "Restore default controls", "蓄力显示": "Charge display", "自己的蓄力显示": "Charge display", "圆形 · 跟随角色": "Circular · follows character", "条形 · 屏幕下方": "Bar · bottom of screen", "声音": "Audio", "音量（本地双人共用音响，取两人设置平均值）": "Volume (local 2-player uses the average of both players)", "本机静音": "Mute this computer", "玩法和赛制": "Game and rules", "可玩的游戏": "Game", "吹泡泡比赛": "Bubble Race", "弗纳克球 / 布里克球": "Wuppo Ball / Brickball", "获胜目标分数": "Score to win", "5 分": "5 pts", "7 分": "7 pts", "10 分": "10 pts", "15 分": "15 pts", "身体顶球 · 落在对方半场得分 · 得分方发球 · 先到 %s 分获胜\n2 人 1v1 / 3 人 1v2 / 4 人 2v2": "Hit the ball with your body · Score by landing it in the other half · Scoring team serves · First to %s points wins\n2 players 1v1 / 3 players 1v2 / 4 players 2v2", "单人：与电脑伙伴练习\n本地双人：P1 与 P2 同屏对战\n多人：2–4 人，全部准备后由房主启动": "Single player: practice with a bot\nLocal 2-player: P1 and P2 play on one screen\nOnline: 2–4 players; the host starts when everyone is ready", "练习伙伴难度": "Practice partner difficulty", "简单": "Easy", "普通": "Normal", "困难": "Hard", "简单：反应稍慢，主要单跳接球\n普通：预判反弹，尝试二段跳救球\n困难：提前抢接落点，调整顶球方向回击": "Easy: slower reactions, mostly single jumps\nNormal: predicts bounces and uses double jumps to save the ball\nHard: moves early to meet the ball and aims returns", "简单：较常蓄力失误，容易错过口哨，较少追跳\n普通：偶尔早放或迟哨，也会尝试完美泡泡\n困难：失误较少，快速反击并积极追上平台": "Easy: often mistimes charging, misses whistles, and rarely chases jumps\nNormal: sometimes releases early or whistles late, and attempts perfect bubbles\nHard: makes fewer mistakes, counters quickly, and actively chases platforms", "对局时长": "Match duration", "启动比赛": "Start match", "先到电脑创建或加入联机房间。": "Create or join an online room at the computer first.", "用身体顶球，得分方从自己半场上方发球，先到 %s 分获胜。": "Hit the ball with your body. The scoring team serves from its side. First to %s points wins.", "已返回休息室。": "Returned to the lounge.", "语言": "Language", "中文": "Chinese", "英文": "English", "语言设置": "Language", "简体中文": "Simplified Chinese",
	"这个按键已被占用，请换一个（Esc 取消）": "That key is already in use. Choose another (Esc to cancel).", "已返回大厅，等待下一局。": "Returned to the lobby. Waiting for the next round.", "正在开始下一局。": "Starting the next round.", "界面语言": "Interface language", "LOBBY": "Lobby", "CONNECTING": "Connecting", "JOINING": "Joining", "HOSTING": "Hosting", "PRACTICE": "Practice", "LOCAL_DUEL": "Local duel", "PAUSED": "Paused", "RESULTS": "Results", "LOADING": "Loading", "COUNTDOWN": "Countdown", "PLAYING": "Playing",
	"网络已连接，正在加入房间……": "Connected to the network. Joining room…", "恢复连接超时，请检查 VPN / 防火墙后重新加入。": "Reconnect timed out. Check your VPN or firewall, then rejoin.", "连接超时，请确认房主地址、网络连接和游戏版本。": "Connection timed out. Check the host address, network, and game version.", "创建失败：%s": "Could not create room: %s", "房间已创建，最多 4 人。": "Room created. Up to 4 players can join.", "连接失败：%s": "Connection failed: %s", "正在连接……": "Connecting…", "已离开房间。": "Left the room.", "版本或房间不匹配，请使用相同版本重新加入。": "Version or room mismatch. Rejoin with the same game version.", "该玩家已经在线。": "That player is already online.", "版本不匹配、房间已满或比赛已开始。": "Version mismatch, room full, or match already started.", "连接已恢复，分数和角色外观已保留。": "Connection restored. Scores and character appearances are unchanged.", "房主调整了玩法或比赛设置，请重新准备。": "The host changed the game or match settings. Ready up again.", "玩家断线，等待自动重连（最多 15 秒）。": "A player disconnected. Waiting for them to reconnect (up to 15 seconds).", "比赛时长改为 %s 秒，请重新准备。": "Match duration set to %s sec. Ready up again.", "弗纳克球获胜分数改为 %s 分，请重新准备。": "Wuppo Ball target set to %s points. Ready up again.", "可直接单人练习，或创建 / 加入联机房间。": "Practice solo or create / join an online room.", "正在连接，可点击离开取消。": "Connecting. Select Leave to cancel.", "等待另一位玩家加入（%s / %s 人）。": "Waiting for another player to join (%s / %s players).", "等待准备：%s": "Waiting for these players to ready up: %s", "全部准备好了，房主可以开始 %s 分球赛。": "Everyone is ready. The host can start the %s-point ball match.", "全部准备好了，房主可以开始 %s 秒比赛。": "Everyone is ready. The host can start the %s-second match.", "连接失败，请检查主机地址与网络。": "Connection failed. Check the host address and network.", "连接中断，正在自动恢复……": "Connection lost. Reconnecting…", "已接替房主，等待其他玩家恢复连接。": "You are now the host. Waiting for other players to reconnect.", "已接替房主。": "You are now the host.", "正在恢复连接 · 最多等待 %s 秒": "Reconnecting · waiting up to %s sec", "比赛暂停 · 等待断线玩家恢复": "Match paused · waiting for disconnected player", "房间已创建 · %s / %s 人": "Room created · %s / %s players", "正在连接主机……": "Connecting to host…", "已连接网络 · 正在加入房间……": "Connected · joining room…", "已连接 · 延迟 %s ms%s": "Connected · %s ms latency%s", "（较高）": " (high)", "已连接 · 正在测量延迟": "Connected · measuring latency", "单人练习 · 不需要网络": "Single-player practice · offline", "本地双人 · P1 K / L · P2 小键盘 0 / .": "Local 2-player · P1 K / L · P2 numpad 0 / .", "未连接": "Not connected",
	"衣柜": "Wardrobe", "电脑": "Computer", "种子摊": "Seed cart", "门": "Door", "房间": "Room", "后院": "Backyard", "紫色大蓝莓": "Giant Purple Blueberry", "洋葱葱": "Garlic Scallion", "奶油": "Cream", "粉桃": "Peach", "薄荷": "Mint", "天蓝": "Sky Blue", "葡萄紫": "Grape Purple", "柠檬黄": "Lemon Yellow", "珊瑚红": "Coral Red", "深海蓝": "Deep Sea Blue", "无帽子": "No hat", "派对尖帽": "Party Hat", "叶子帽": "Leaf Hat", "小皇冠": "Small Crown", "紫色鸭舌帽": "Purple Cap",
	"种植存档无法读取，已保留原文件；请恢复存档备份后重启游戏。": "The garden save could not be read. The original file was kept; restore a save backup and restart the game.", "无法保存种植存档，请检查磁盘空间和存档目录权限。": "Could not save the garden. Check disk space and save-folder permissions.", "种植存档写入失败，本次操作未扣款。": "Could not write the garden save. This purchase was not charged.", "无法创建种植存档备份，本次操作未扣款。": "Could not back up the garden save. This purchase was not charged.", "无法更新种植存档，本次操作未扣款。": "Could not update the garden save. This purchase was not charged.", "无效的玩家资料。": "Invalid player profile.", "无效的种子数量。": "Invalid seed quantity.", "斯马特不足，先收获并出售成熟植物。": "Not enough Smurt. Harvest and sell mature plants first.", "种子库存已满。": "Seed inventory is full.", "无效的种植地。": "Invalid garden plot.", "这块地已经种了植物。": "This plot already has a plant.", "没有这种种子，请先到种子摊购买。": "You do not have this seed. Buy some from the seed cart first.", "这块地还没有植物。": "There is no plant on this plot yet.", "植物还未成熟，请再等一会儿。": "The plant is not mature yet. Please wait a little longer.", "收获库存已满。": "Produce inventory is full.", "没有足够的成熟植物可出售。": "You do not have enough mature plants to sell.", "钱包已满。": "Your wallet is full.", "无效的帽子。": "Invalid hat.", "这顶帽子已经在物品栏里了。": "You already have this hat in your inventory.", "斯马特不足，先种植并出售作物。": "Not enough Smurt. Grow and sell crops first.", "无效的染色泡泡数量。": "Invalid dye bubble quantity.", "染色泡泡库存已满。": "Dye bubble inventory is full.", "无效的染色泡泡。": "Invalid dye bubble.", "没有找到这个角色的本地资料。": "Local profile not found.", "角色已经是这个颜色了。": "This character already has that color.", "没有这款染色泡泡，请先到衣柜购买。": "You do not have this dye bubble. Buy one from the wardrobe first.", "无效的帽子选择。": "Invalid hat selection.", "这顶帽子还没有购买。": "You have not bought this hat yet."
}
const ENGLISH_FRAGMENTS := {
	"价格：": "Price: ", "确认购买 · ": "Confirm purchase · ",
	"：": ": ", "（": " (", "）": ")", "，": ", ", "。": ".", "、": ", ", " 分": " pts", " 秒": " sec", " 分钟": " min", "UDP 7000": "UDP 7000",
	"鼠标 左 键": "Mouse left button", "鼠标 右 键": "Mouse right button", "鼠标 %s 键": "Mouse %s button",
	"手持：": "Holding: ", "染色泡泡：": "Dye bubble: ", "种子：": "Seed: ", "收获物：": "Produce: ", "种子库存：": "Seeds: ", " · 已收获：": " · Harvested: ", "当前余额：": "Balance: ", " 斯马特": " Smurt", "种子 ": "Seeds cost ", " · 成熟约 ": " · Matures in about ", " 分钟（±5%）· 售价 ": " min (±5%) · Sells for ", "购买 1 份种子 · ": "Buy 1 seed · ", "购买 5 份种子 · ": "Buy 5 seeds · ", "已购买一份": "Bought one ", "已购买五份": "Bought five ", "种子。": " seed.", "买下了": "Bought ", "染色泡泡。": " dye bubble.", "库存：": "In stock: ", " %s泡泡": " %s bubble", "%s泡泡%s": "%s dye bubble%s",
	"房间状态：": "Room status: ", "主机地址：": "Host address: ", "请确认使用双方可访问的网卡地址": "Use a network address both players can reach", "左队  ": "Left team  ", "  右队": "  Right team", "左队": "Left team", "右队": "Right team", " 分 · 最大 ": " pts · Best ", "获胜！": " wins!", "本局优胜：": "Round winner: ", "最大泡泡奖：": "Largest bubble: ", "口哨助攻 +": "Whistle assist +", "口哨击破 ×": "Whistle burst ×", " 分)": " pts)", "等待所有参赛玩家": "Waiting for all players", "小提示：": "Tip: ", "染色泡泡 ×": "dye bubble ×", "染色泡泡": "dye bubble", "泡泡": "bubble", "已加载": "Loaded", "加载中……": "Loading…", "准备  ": "Ready  ", "房间已创建 · ": "Room created · ", "等待另一位玩家加入": "Waiting for another player to join", "人": "players", " 人）。": " players).", "等待准备：": "Waiting for players to ready up: ", "全部准备好了，房主可以开始 ": "Everyone is ready. The host can start the ", " 秒比赛。": "-second match.", " 分球赛。": "-point ball match.", "正在恢复连接 · 最多等待 ": "Reconnecting · waiting up to ", "已连接 · 延迟 ": "Connected · latency ", " ms（较高）": " ms (high)", "购买 · ": "Buy · ", "身体顶球": "Hit the ball with your body", "落在对方半场得分": "score by landing in the opponent's half", "得分方发球": "the scoring team serves", "先到 ": "First to ", " 分获胜": " points wins", " 2 人 ": " 2 players ", " 3 人 ": " 3 players ", " 4 人 ": " 4 players "
}
var circular_meters := true
var language := "zh"
var profiles: Dictionary = {}
var preferences_path := PREFERENCES_PATH

func _ready() -> void:
	var config := ConfigFile.new()
	config.load(preferences_path)
	circular_meters = bool(config.get_value("display", "circular_meters", true))
	language = str(config.get_value("display", "language", "zh"))
	if language not in ["zh", "en"]: language = "zh"
	for slot in [1, 2]:
		var section := "p%s" % slot
		profiles[slot] = {"keys": DEFAULT_KEYS[slot - 1].duplicate(), "circular": bool(config.get_value(section, "circular", circular_meters)), "volume": float(config.get_value(section, "volume", 0.45)), "skin": clampi(int(config.get_value(section, "skin", config.get_value("player", "skin", 0) if slot == 1 else 1)), 0, 7), "hat": clampi(int(config.get_value(section, "hat", config.get_value("player", "hat", 0) if slot == 1 else 0)), 0, 4)}
		var saved: Array = config.get_value(section, "keys", DEFAULT_KEYS[slot - 1])
		if saved.size() == 5: profiles[slot]["keys"] = saved
	apply_volume(false)

func keys(slot: int) -> Array:
	return profiles[slot]["keys"]

func matches(event: InputEvent, slot: int, action: int, local_duel: bool) -> bool:
	var code := int(keys(slot)[action])
	if event is InputEventKey: return event.physical_keycode == code
	if event is InputEventMouseButton:
		if code < 0: return event.button_index == -code
		return not local_duel and slot == 1 and ((action == 3 and code == KEY_K and event.button_index == MOUSE_BUTTON_LEFT) or (action == 4 and code == KEY_L and event.button_index == MOUSE_BUTTON_RIGHT))
	return false

func key_name(code: int) -> String:
	if code < 0: return text("鼠标 %s 键" % ("左" if code == -1 else ("右" if code == -2 else str(-code))))
	return OS.get_keycode_string(code)

func controls_text(slot: int) -> String:
	var k := keys(slot)
	if language == "en": return "P%s  %s / %s move · %s jump · S / ↓ crouch · %s blow bubble / interact · %s whistle" % [slot, key_name(k[0]), key_name(k[1]), key_name(k[2]), key_name(k[3]), key_name(k[4])]
	return "P%s  %s / %s 移动 · %s 跳跃 · S / ↓ 蹲下 · %s 吹泡泡 / 交互 · %s 口哨" % [slot, key_name(k[0]), key_name(k[1]), key_name(k[2]), key_name(k[3]), key_name(k[4])]

func text(source: String) -> String:
	if language != "en": return source
	if ENGLISH_TEXT.has(source): return str(ENGLISH_TEXT[source])
	var result := source
	var keys: Array = ENGLISH_FRAGMENTS.keys()
	keys.sort_custom(func(a, b): return str(a).length() > str(b).length())
	for key in keys: result = result.replace(str(key), str(ENGLISH_FRAGMENTS[key]))
	return result

func text_with_names(source: String, names: Array) -> String:
	var protected: Dictionary = {}
	var prepared := source
	for index in names.size():
		var player_name := str(names[index])
		if player_name.is_empty(): continue
		var token := "[[PLAYER_NAME_%s]]" % index
		prepared = prepared.replace(player_name, token)
		protected[token] = player_name
	var result := text(prepared)
	for token in protected: result = result.replace(str(token), str(protected[token]))
	return result

func set_language(value: String) -> void:
	language = "en" if value == "en" else "zh"
	save()

func uses_circular(slot: int) -> bool:
	return bool(profiles[slot]["circular"])

func save() -> void:
	var config := ConfigFile.new()
	config.load(preferences_path)
	for slot in profiles:
		for field in profiles[slot]: config.set_value("p%s" % slot, field, profiles[slot][field])
	config.set_value("display", "circular_meters", circular_meters)
	config.set_value("display", "language", language)
	config.save(preferences_path)

func set_circular_meters(enabled: bool) -> void:
	circular_meters = enabled
	profiles[1]["circular"] = enabled
	save()

func apply_volume(two_players: bool) -> void:
	AudioManager.volume = float(profiles[1]["volume"])
	if two_players: AudioManager.volume = (AudioManager.volume + float(profiles[2]["volume"])) * 0.5

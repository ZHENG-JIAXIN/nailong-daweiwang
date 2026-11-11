# 奶龙大胃王 · 战斗扩展 交付概览

在原有「吞噬成长」玩法之上，新增完整战斗系统：**角色 / 武器 / BOSS / 角色增益**。
全部采用代码绘制 2D 形状（无新增美术资源），兼容单线程 Web 导出。

## 改动文件
| 文件 | 改动 |
|------|------|
| `src/bullet.gd` | **新增** 子弹：Area2D + 发光弹体绘制，命中 `damageable` 调用 `take_damage` 后销毁 |
| `src/fish.gd` | 加 `hp/max_hp/contact_damage/is_boss/boss_name`、`died` 信号、`damageable` 组、`take_damage()`、`make_boss()`（3 种 BOSS）、BOSS 头顶名字+血条绘制 |
| `src/player.gd` | 武器库 `WEAPONS`(4 把)、生命值、开火/换弹/切枪(1-4/R)、近战扇形挥砍、角色增益 `apply_buffs()`（随吞噬成长放大）、瞄准跟随鼠标、受伤无敌帧、武器代码绘制 |
| `src/main.gd` | HUD 加 生命/武器/弹药；顶部 BOSS 血条；击杀计分+奶龙币；BOSS 触发生成；玩家被大鱼/BOSS 碰撞掉血；`mk_label` 设 IGNORE 防遮挡点击 |
| `src/game_manager.gd` | 新增 `add_coins(amount)` |

## 设计数值（可继续微调）
- **3 角色增益（随吞噬成长分级放大）**
  - 奶龙·突击手：换弹 ×(0.7−0.02·成长)（下限0.4）、移速 ×(1.10+0.02·成长)
  - 噜噜·狙击手：远程伤害 ×(1.25+0.05·成长)、射程由武器决定
  - 奶娃·狂战：近战伤害 ×(1.40+0.06·成长)、击杀回血 (6+成长)、移速 ×(1.05+0.02·成长)
- **4 武器**
  - M4A1 突击步枪（远程·弹匣25·射速0.10s·伤害14）
  - 巴雷特M95 狙击枪（远程·弹匣25·射速0.90s·伤害55·高初速）
  - 尼泊尔军刀（近战·无弹药·CD0.4s·伤害40·扇形1.1·触及72）
  - 战斧（近战·无弹药·CD0.6s·伤害30·扇形1.8·触及112）
- **鱼类**：HP ≈ `6 + 0.8·半径`，接触伤害 `max(5, 0.45·半径)`；小鱼仍可直接吞噬成长。
- **BOSS**：得分 ≥800 或 击杀 ≥25 随机 1 只（深海巨鲨 / 熔岩章鱼 / 幽灵鲸王），体型 95–130（约 3–4 倍）、专属配色、头顶名字+血条、全图追猎；击杀 +400 分 / +30 币，并抬升下一轮阈值（分数+1000 / 击杀+30）。
- **角色生命**：基础 100，被大鱼/BOSS 接触按 `contact_damage` 掉血，0.4s 无敌帧防瞬间秒杀，HP≤0 结算。

## 操作
- 移动鼠标：控制奶龙移动（朝鼠标方向）
- 左键：开火（朝鼠标方向，按住连发）
- 1–4：切换武器（M4A1 / 巴雷特 / 尼泊尔军刀 / 战斧）
- R：换弹（远程空仓也会自动换弹）

## 已知手感点
移动=鼠标跟随、开火=朝鼠标方向，因此「边退边打」较难（需改移动方案，暂未做）。

## 部署（需你本机操作）
本沙箱无 Godot，无法无头语法检查；代码已按 GDScript 4 规则人工校对。请在你本机：
1. Godot 打开项目 → 重新导出 Web（Export Project，覆盖旧包）
2. `git add . && git commit -m "feat: 角色/武器/BOSS/增益战斗系统" && git push`
3. GitHub Actions 变绿后，浏览器**硬刷新**（Ctrl+F5）验证

---

## 追加：移动端加载优化（Netlify 预压缩 wasm）

**问题**：GitHub Pages 首包 45 MB，`index.wasm` 38 MB 无压缩传输，手机加载巨慢。

**方案**（配置已落地，待你在 Netlify 侧点几下）：把 wasm 预压缩成 `index.wasm.gz`
（10,084,297 B，约 9.6 MB），用 Netlify 的 200 重写 + `Content-Encoding: gzip`
让浏览器自动解压，URL 仍是 `/index.wasm`，**Godot 侧零改动**。

| 文件 | 状态 | 作用 |
|------|------|------|
| `src/release/web/index.wasm.gz` | 新增 | 预压缩体，38 MB → 9.6 MB（省约 29.4 MB） |
| `netlify.toml` | 新增 | publish 目录、自动重生成 gz、重写规则、响应头与缓存策略 |
| `src/release/web/_redirects` | 新增 | 与 netlify.toml 镜像的 `200!` 重写 |
| `src/release/web/_headers` | 改写为纯注释 | 响应头统一收敛到 netlify.toml，避免 `gzip, gzip` 双重编码 |

**关键约束**：必须用 Git 连接部署，不能用 Netlify Drop；`force = true` / `200!` 不能省；
`Content-Encoding` 只在 netlify.toml 声明一处。

**已知偏差**：`fileSizes` 仍按未压缩字节计，进度条偏保守（仅显示问题）；
每次重新导出 Web 后需把 `index.html` 的 `experimentalVK` 改回 `true`（手机虚拟键盘）。

**质量门：PASS**（2026-11-07 线上验证完成）

- 站点：`https://willowy-horse-183745.netlify.app/`，已设为 Public
  （原为团队默认 Private，匿名访问会 401 "Login Redirect"）
- `/index.wasm` 带 `Accept-Encoding` 时返回 `Content-Encoding: gzip`、
  `Content-Length: 10084297`、`Content-Type: application/wasm`；
  不带时自动解压回原始 wasm（Netlify 对 `.gz` 文件的原生内容协商）
- 浏览器实收 9.6 MB（原 38 MB）；`experimentalVK: true`、
  `index.pck` 6403760、200 重写（Etag 一致）均已确认
- 生效机制与预期不同：`netlify.toml` 里自定义的那条 `Content-Encoding`
  实际被 Netlify 忽略，属冗余配置，建议下次改动时顺手删除
- 剩余：用户侧手机实测加载速度与登录框输入手感

---

## 追加：双端输入分离（方案 A · 2026-11-09）

**问题**：移动、瞄准、开火共用同一个鼠标/触摸位置，角色永远朝鼠标跑，无法「边退边打」。

**方案**：三路解耦——移动走按键，瞄准用鼠标（PC）/右半屏触摸（移动端），开火用左键（PC）/右半屏按住（移动端）。

| 文件 | 改动 |
|---|---|
| `design/gdd/input-ux-spec.md` | **新增** UX 规格：输入映射表、屏幕按键布局、边界状态表、验收标准 |
| `src/player.gd` | 删 `target` 追点模型；移动改为 `键盘向量 + pad_dir` 合成并归一化；瞄准支持触摸优先；开火拆 `firing`/`touch_firing` 两路 |
| `src/main.gd` | 新增左下角 W/A/S/D 可按住按钮（按下高亮、斜向叠加）；删「鼠标写 target」；右半屏触摸瞄准+开火；菜单/登录/结算隐藏并清空；hint 文案更新 |
| `src/project.godot` | **不需要改**：`emulate_mouse_from_touch` 是 Godot 默认开启项（`true`），手动写入会被编辑器清理 |

**关键设计**：屏幕按钮用普通 `Button`（PC 鼠标可按、移动端触摸可按），走 `button_down`/`button_up`；左 45% 屏宽留给方向键并用 `_point_over_pad()` 过滤，避免按方向键误触开火；松开事件无条件复位，避免「键内按下、键外松开」卡住持续开火。

**质量门：CONCERNS（仅剩双端实测）** — 代码已上线。
已完成：Godot 重新导出成功（脚本编译通过）、提交 `3f8b4d2`、push、Netlify 自动部署；
线上 `index.pck` 与 `index.html` 的 `fileSizes` 均为 `6407376`，版本一致。
剩余阻塞项：按 UX 规格 §7 做 PC / 移动端实测（尤其移动端左下角按键、右半屏瞄准开火）。

**已知风险与缓解**：
- `export_presets.cfg` 的 `html/experimental_virtual_keyboard=true` 已开启，重新导出会**自动**带上 `experimentalVK:true`，无需手动改
- 导出后本地 `index.wasm.gz` 会过时，但 Netlify build command 每次部署自动重生成，线上不受影响
- 移动端暂不提供切武器/换弹屏幕键（远程空仓自动换弹、近战无弹药）
- **已在 v2.0 解决**：v1.0 的「触摸转鼠标只跟随第一指」隐患，通过 `InputEventScreenTouch.index` 双指追踪消除（见下节）

---

## 追加：双浮动摇杆 v2.0（手感打磨 · 2026-11-10）

用户实测反馈：v1.0 按键太小、固定太死、射击角度不足 360°。根因是「固定 D-pad +
绝对触摸点瞄准」——`aim_dir = 触摸点 − 角色位置`，而触摸点被限制在右半屏，
手指永远到不了角色左侧，朝左几乎不可达；角色跑到屏幕右侧时角度还会乱跳。

**改法**：方向改为「手指相对按下点的偏移向量」，与角色坐标、落点位置都无关。

| 文件 | 改动 |
|---|---|
| `src/joystick_overlay.gd` | **新增** 代码绘制双摇杆（底盘 R=104、摇杆头 R=44，青蓝 / 橙半透明，按下淡入） |
| `src/main.gd` | 删固定 D-pad 全套；用 `InputEventScreenTouch.index` 追踪左右两指，按下点即摇杆原点；`_sync_joysticks()` 输出移动向量与瞄准向量；`touch_seen` 屏蔽触摸模拟的鼠标事件 |
| `src/player.gd` | 瞄准从绝对点改为 `touch_aim_dir` 方向向量 → 真 360° |
| `design/gdd/input-ux-spec.md` | 重写为 v2.0 摇杆规格 |

**要点**：轻推慢走 / 推到底全速（全向连续，不再是 8 向）；右摇杆按住即开火、松开保留朝向；
双指先后顺序任意；PC 保持 `WASD + 鼠标`，摇杆仅在有触摸时出现。

**质量门：CONCERNS（仅剩双端实测）** — 代码已上线。
已完成：Godot 打开并重新导出成功（新 `class_name JoystickOverlay` 已注册、脚本编译通过）、
提交 `978c057`、push、Netlify 自动部署；线上 `index.pck` 与 `index.html` 的
`fileSizes` 均为 `6407312`，版本一致。
剩余阻塞项：按规格 §7 做双端实测（重点：360° 绕圈、双指任意顺序、摇杆尺寸手感）。

---

## 追加：加载性能优化 A（构建脚本化 · 2026-11-10）

**诊断**：压缩链路没坏（wasm 实收 9.6 MB）。瓶颈是
① 国内直连 TTFB ~0.85s / 吞吐 ~1.1MB/s，16 MB 首包纯下载约 15 秒
② 手机 CPU 现场编译 38 MB wasm，再 10–20 秒
另外 `index.pck` 实测 gzip 只能压到 6.36 MB（省 0.8%），预压缩无意义。
（曾误判 `fileSizes` 会让进度条卡在 25%，见下方「误判与撤销」。）

**落地**：

| 文件 | 改动 |
|---|---|
| `scripts/prepare-web.sh` | **新增** 构建脚本：用当前 wasm 重新生成 gz（`-9 -n` 确定性输出）；**不改** `index.html` |
| `netlify.toml` | `command` 从裸 gzip 改为 `bash scripts/prepare-web.sh` |
| `src/release/web/index.wasm.gz` | 本地重新生成，与 11-10 导出的 wasm 同步 |

**要点**：只做「预压缩体同步」一件事，数值自适应，wasm 变小也不用改脚本；
只改 publish 目录的构建产物，仓库里的 `index.html` 保持 Godot 原样。

**仍需用户侧**：重新导出时确认用 **Release 模板、不勾 "Export With Debug"**，
可再省约 10–15% 引擎体积（脚本会自动适配新的 gz 大小）。

### ⚠️ 一次误判与撤销（15:24）

第一版脚本里加了 sed，把 `fileSizes.index.wasm` 改成 gz 大小 `10084286`。
线上确实生效（HTML 与 gz 的 `Content-Length` 都是 10084286、本地与线上
sha256 一致），但**用户实测进度条一打开就爆满并停住**——这是回归。

根因（读 `index.js` 确认）：`loadFetch` 用 `response.body.getReader()` 累加
`result.value.length` 作为 `loaded`；浏览器会自动解压 `Content-Encoding: gzip`，
所以 `loaded` 是**解压后字节数**，天然等于未压缩 wasm 大小 `39514754`。
Godot 导出的 `fileSizes` 本来就正确。改成 gz 大小后 `loaded` 迅速超过 `total`，
进度条瞬间到 100%，之后只剩 WASM 编译的静默期，看起来像卡死。

**已撤销 sed**，脚本只重新生成 gz；仓库里 `index.html` 一直是
`fileSizes.index.wasm = 39514754`，重新部署后线上会恢复正确值。
脚本文件头已写死这条禁令，避免再犯。

**线上复验（15:30，PASS）** — 提交 `fix: 撤销 fileSizes 修正, 恢复 Godot 原值` 后：
- 线上 `index.html` 的 `fileSizes.index.wasm = 39514754`（已恢复 Godot 原值）
- 线上 `/index.wasm` 仍返回 `Content-Encoding: gzip` /
  `Content-Length: 10084286` / `Content-Type: application/wasm`（压缩链路未受影响）
- 本地 gz 与线上一致：`10084286` bytes、sha256 `ffa4b293…`

**质量门：CONCERNS** — 回归已修复并复验 PASS；整体仍开着，剩余：
① 跨境链路与手机 WASM 编译（方案 B / C，用户暂未选）
② 双浮动摇杆双端真人实测 ③ 用户手机端确认进度条恢复正常、游戏能进入。

---

## 追加：无尽关卡制 + 武器快捷栏 + 子弹可见性（2026-11-11 · 方案 A）

**问题**：旧版 3 关累计分数达标即 `game_win()` 结束，没有持续目标与单关反馈；
移动端无法切武器；浅色关卡背景上子弹（白芯 + 淡黄拖尾）几乎看不见。

| 文件 | 改动 |
|---|---|
| `design/gdd/level-progression-spec.md` | **新增** 无尽关卡规格：独立目标、难度曲线、结算评价、BOSS 节奏、验收标准 |
| `design/gdd/bullet-visibility-spec.md` | **新增** 子弹对比度规格：亮度判据、双层描边配色、尺寸 |
| `src/main.gd` | 新增 `level_index / level_score / level_kills / level_target` 与 `levelclear` 状态；得分双记；`level_clear()` 结算面板（统计 / S-A-B 评价 / 奖励币 / 继续按钮）；`next_level()` 三主题循环 + 每 3 关强制 BOSS；难度按关数递增并封顶；HUD 下方 4 个武器快捷按钮；`_point_over_weapon_bar()` 排除摇杆与 PC 开火误触；`_apply_bg()` 同步背景亮度 |
| `src/bullet.gd` | 自适应双层描边（浅背景深描边 / 深背景亮描边），视觉半径 4.5→6.5、碰撞 5→6、拖尾加长 |
| `src/game_manager.gd` | 新增运行时 `bg_is_light`（不进存档） |

**关键设计**：死亡才最终结算（不再有「通关」终点）；每关目标 `300+200×(n-1)`；
过关需玩家点「继续」才推进，保留自主感；`state` 相关函数全部有 `playing` 保护，
结算期间不生成鱼、不掉血、不开火。

**线上验证（15:46，PASS）** — 提交 `892fb54` 已推送并部署：
- 线上 `index.pck` `6412080`、`index.html` 的 `fileSizes` 同为 `6412080`，版本一致
- `fileSizes.index.wasm = 39514754` 保持 Godot 原值（构建脚本未改 HTML，回归未复发）
- `experimentalVK: true`；`/index.wasm` 仍返回 `Content-Encoding: gzip` /
  `Content-Length: 10084286` / `application/wasm`

**质量门：CONCERNS（仅剩双端实测）** — 已完成：① Godot 打开并重新导出
（脚本编译通过）② 重新导出 Web + push + Netlify 部署 + 线上验证。
剩余阻塞项：按两份规格做双端真人实测（重点：连续 10 关、每 3 关 BOSS、
武器按钮不生成摇杆、深浅背景子弹对比、结算面板按钮可点）。

**已知风险**：武器栏 `y=214` 与顶部 HUD 末行接近，Godot 里若发现重叠需下调；
`game_win()` 保留但不再接线；目标分数与难度公式为初版数值，待 Playtest 微调。

---

## 追加：BGM 启动链路优化（2026-11-11）

用户要求「一进去就有音乐 + 画面音乐都流畅」，并提供了一个 38 MB 的 MP4 MV。
初次评估提示了授权与体积风险；**用户随后确认其拥有该曲目的相应权利**，
因此按授权素材接入。

**音源处理**：本机原先无 ffmpeg / ffprobe，已通过 `imageio-ffmpeg`
（自带二进制，无需系统安装）补齐转码能力，并新增可复用脚本
`scripts/extract_bgm.py`：提取音轨 → Ogg Vorbis 96 kb/s / 48 kHz / stereo，
输出 `src/assets/audio/bgm.ogg` **2.30 MB**（3 分 37 秒）。
与旧 `bgm.wav`（2.3 MB）体积基本持平，**首包未膨胀**；
38 MB 的 MP4 只作为转码输入，**未进入工作区、未打进 pck**。
`bgm.wav` 保留作备份，程序已不再引用。

**落地**：

| 文件 | 改动 |
|---|---|
| `src/audio_player.gd` | 静音起步（`MUTE_DB=-80`）让解码与 AudioContext 尽早就绪；首个真实手势只解除静音、**不 stop/play 重启**（零空白、不从头）；已在播放时进游戏不打断；每次手势检查播放器是否被挂起（切后台回来）并恢复；`InputEventScreenDrag` 也算手势；`preload` 切到 `bgm.ogg`，并兼容 `AudioStreamOggVorbis.loop` |
| `src/main.gd` | 登录页加一行「点击或按键后音乐开始播放」提示 |
| `scripts/extract_bgm.py` | **新增** 可复用转码脚本：提取音轨 → Ogg 96 kb/s / 48 kHz / stereo |
| `src/assets/audio/bgm.ogg` | **新增** 压缩后的 BGM 音源，2.30 MB / 3 分 37 秒 |
| `src/assets/audio/README.txt` | 补自动播放策略说明、修正「自动查找」的过时描述、更新音源与授权占位 |

**画面流畅**：现状 BGM 走 `preload` 文件播放、由音频后端解码，不占游戏主线程
（`_process` 在文件模式下空转），本就是最优解，**未改动**，避免引入新卡顿。

**浏览器硬限制**：无用户手势时音频一律静音，「零交互自动响」在 Web 上做不到；
现在能做到的是「第一次点击 / 按键的瞬间立刻出声」。

**质量门：CONCERNS** — 需重新导出 Web + push 后双端实测：
① 首次点击出声、进游戏不重启、切后台回来恢复
② 新 Ogg 音源能正常播放并循环、音量与旧版相当
③ 帧率无变化、`index.pck` 未明显膨胀。
注意：Godot 首次打开会为 `bgm.ogg` 自动生成 `.import` 文件，需一并提交；
若导入参数里循环默认关闭，运行时 `ogg.loop = true` 会覆盖。

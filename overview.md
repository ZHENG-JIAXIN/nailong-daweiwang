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
③ `fileSizes.index.wasm` 仍按 39.5 MB 算，进度条卡在约 25% 再跳，观感像卡死。
另外 `index.pck` 实测 gzip 只能压到 6.36 MB（省 0.8%），预压缩无意义。

**落地**：

| 文件 | 改动 |
|---|---|
| `scripts/prepare-web.sh` | **新增** 构建脚本：用当前 wasm 重新生成 gz（`-9 -n` 确定性输出），并把 `index.html` 的 `fileSizes.index.wasm` 改成 gz 实际字节数 |
| `netlify.toml` | `command` 从裸 gzip 改为 `bash scripts/prepare-web.sh` |
| `src/release/web/index.wasm.gz` | 本地重新生成，与 11-10 导出的 wasm 同步 |

**要点**：数值自适应，wasm 变小后不用改脚本；只改 publish 目录的构建产物，
仓库里的 `index.html` 保持 Godot 原样，避免每次重导产生 diff。本地已验证
`fileSizes` 从 `39514754` → `10084297`，`index.pck` 保持 `6407312` 不变；
`-n` 让两次生成的 sha256 完全一致。

**仍需用户侧**：重新导出时确认用 **Release 模板、不勾 "Export With Debug"**，
可再省约 10–15% 引擎体积（脚本会自动适配新的 gz 大小）。

**质量门：CONCERNS** — 首包体积与进度条已优化，但跨境链路与手机 WASM 编译
仍未解决（属方案 B / C 范畴，用户暂未选）。

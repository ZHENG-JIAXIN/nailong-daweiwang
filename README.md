# 奶龙大胃王（同人 · 非商用）

一款「大鱼吃小鱼 / 越吃越大」玩法的网页小游戏，使用 **Godot 4** 开发，免费 MIT 引擎，角色为原创萌系占位形象。

## 玩法
- 登录 / 注册（多用户，存档按浏览器隔离）
- 3 难度、3 关卡（浅海乐园 / 珊瑚浅滩 / 深渊秘境），通关进阶
- 3 角色（奶龙 / 噜噜 / 奶娃）
- 吞噬成长、捕食者 AI、程序化音频、每日签到 + 答题赚币

## 运行
- 源码：`src/`（`project.godot` 为工程根，Godot 4.7 打开即玩）
- 网页构建：`src/release/web/`（由 Godot Web 导出生成）

## 部署
通过 GitHub Actions 自动发布到 GitHub Pages：推送到 `main` 分支即触发 `deploy.yml`，
将 `src/release/web/` 部署为静态站点。仓库 `Settings → Pages → Source` 选 **GitHub Actions**。

> 合规：本作仅限非商用同人；正式商用前须取得相关 IP 授权。当前角色贴图为原创占位图。

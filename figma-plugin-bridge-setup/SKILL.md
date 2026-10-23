---
name: figma-plugin-bridge-setup
description: One-shot install and configuration of the TalkToFigma local plugin bridge (cursor-talk-to-figma-mcp) so Cursor AI can read, edit and export Figma files through the Figma desktop plugin API with no REST/MCP quota. Use when the user asks to install or configure Figma MCP, TalkToFigma, the Figma plugin bridge, wants unlimited Figma reads, hits Figma 429 / rate limits, or refers to the Figma tutorial video setup.
---

# Figma 插件桥一键安装（TalkToFigma）

目标：用户只需要在 Figma 里点三下，其余全部由 Agent 完成。
原理：Cursor →（MCP, stdio）→ `server.ts` →（WebSocket localhost:3055）→ Figma 桌面端插件。走插件 API，不经过 api.figma.com，不消耗 REST / 官方 MCP 的每月额度。

## 和用户说话的规矩

- 用户可能完全不懂技术。只让用户做**必须人手点的事**，一次只给一步，说清楚「点哪里、看到什么算成功」。
- 命令全部由 Agent 自己执行，不要让用户复制粘贴命令。
- 每一步做完先自己验证，再进入下一步。

## 流程

```
- [ ] 1. 跑安装脚本（Agent）
- [ ] 2. 让 Cursor 加载 MCP（用户点一下或 Agent 检查）
- [ ] 3. 在 Figma 里导入并运行插件（用户点三下）
- [ ] 4. 连上频道并验证读写（Agent）
```

### 1. 跑安装脚本

Windows（PowerShell）：

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.cursor\skills\figma-plugin-bridge-setup\scripts\setup.ps1"
```

macOS / Linux：

```bash
bash ~/.cursor/skills/figma-plugin-bridge-setup/scripts/setup.sh
```

脚本是幂等的，重复跑没有副作用。它会：
1. 没有 bun 就装 bun；
2. 把仓库放到 `~/.cursor/cursor-talk-to-figma-mcp`（git 失败时自动改下 zip）并 `bun install`；
3. 把 `TalkToFigma` 合并进 `~/.cursor/mcp.json`（保留其他服务器，原文件备份成 `mcp.json.bak`）；
4. 后台启动中继（端口 3055，已在跑就跳过）；
5. 在桌面放一个「启动 Figma 中继」的快捷方式（Windows `.cmd` / macOS `.command`）；
6. 最后打印插件 manifest 的完整路径（Windows 下同时复制到剪贴板）。

脚本最后一行是 `RESULT: OK` 才算成功；否则按输出里的 `ERROR:` 行查「排错」表。需要代理时先设置 `HTTPS_PROXY` 环境变量再跑。

随时可以跑检查脚本（只读，不改任何东西）：

```powershell
powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\.cursor\skills\figma-plugin-bridge-setup\scripts\check.ps1"
```
```bash
bash ~/.cursor/skills/figma-plugin-bridge-setup/scripts/check.sh
```

### 2. 让 Cursor 加载 MCP

先用 `GetDynamicTools` 搜 `TalkToFigma`（pattern `(?i)talk`）。能看到 `join_channel` 等工具就跳过这一步。
看不到时，对用户说：

> 打开 Cursor 设置（右上角齿轮）→ 左边点 **MCP** → 找到 **TalkToFigma**，把开关关掉再打开；变成绿点就好了。还不行就把 Cursor 完全关掉重开一次。

### 3. 用户在 Figma 里点三下

必须是 **Figma 桌面版**（网页版不能导入开发插件）。原话发给用户，把 `<manifest 路径>` 换成脚本打印的路径：

> 1. 打开 Figma 桌面版，进入你要操作的文件。
> 2. 顶部菜单 **Plugins → Development → Import plugin from manifest…**，选这个文件：
>    `<manifest 路径>`（已经复制到剪贴板，弹窗里直接粘贴）
>    这一步只需要做一次。
> 3. **Plugins → Development → Cursor MCP Plugin** 运行插件，在插件窗口里点 **Connect**。
>    看到绿色的「Connected」和一串频道号（比如 `j68x8npx`），把频道号发给我。

### 4. 连上并验证

拿到频道号后由 Agent 依次调用：
1. `join_channel`，参数 `{ "channel": "<频道号>" }`；
2. `get_document_info`，读到文件名和页面就说明成功；
3. 告诉用户结果，比如：「连上了，读到文件『xxx』，有 N 个页面。现在可以直接让我读、改、导出这个文件了。」

## 日常使用

- 每次开 Figma 都要：确认中继在跑（双击桌面快捷方式，或 Agent 跑 `check`）→ 运行插件 → Connect → 把新频道号给 Agent。
- 频道号每次连接都会变。
- 插件导出只有 PNG / JPG；要 SVG 再走一次 REST。
- 大画板一次读取可能超时，按子节点拆开读。

## 排错

| 现象 | 处理 |
|---|---|
| `ERROR: bun` | 网络问题。设置 `HTTPS_PROXY` 后重跑；或让用户从 bun.sh 手动安装后重跑 |
| `ERROR: clone` / `ERROR: download` | 访问 GitHub 失败，设置 `HTTPS_PROXY` 后重跑 |
| `ERROR: port 3055 in use` | 被别的程序占用。`check` 会打印占用进程，结束它后重跑 |
| 插件显示 Disconnected / 连不上 | 中继没在跑：双击桌面「启动 Figma 中继」，或重跑 setup |
| Plugins 菜单里没有 Development | 用的是网页版，换桌面版 |
| `join_channel` 成功但读取超时 | 插件窗口被关了或换了文件：重新运行插件、Connect，换新频道号 |
| Cursor 里看不到 TalkToFigma 工具 | 回到第 2 步；仍不行就检查 `~/.cursor/mcp.json` 里 `TalkToFigma` 的 bun 路径和 server.ts 路径是否存在 |

## 不要做的事

- 不要为这个方案申请或填写 Figma 个人令牌，它用不到令牌。
- 不要改 `mcp.json` 里其他服务器的配置。
- 不要把中继改成监听 `0.0.0.0`，只留在本机。

#!/usr/bin/env bash
# TalkToFigma 插件桥状态检查（只读）
REPO="$HOME/.cursor/cursor-talk-to-figma-mcp"
MCP_JSON="$HOME/.cursor/mcp.json"
bad=0
item() { if [ "$1" = 1 ]; then echo "[OK]   $2 $3"; else echo "[FAIL] $2 $3"; bad=$((bad + 1)); fi; }
ok() { "$@" >/dev/null 2>&1 && echo 1 || echo 0; }

BUN="$HOME/.bun/bin/bun"; [ -x "$BUN" ] || BUN="$(command -v bun || true)"
item "$(ok test -x "$BUN")" bun "$BUN"
item "$(ok test -f "$REPO/src/talk_to_figma_mcp/server.ts")" 仓库 "$REPO"
item "$(ok test -d "$REPO/node_modules")" 依赖 node_modules
item "$(ok grep -q '"TalkToFigma"' "$MCP_JSON")" mcp.json "$MCP_JSON"
L="$(lsof -nP -iTCP:3055 -sTCP:LISTEN 2>/dev/null | tail -n +2 | head -1)"
if [ -n "$L" ]; then item "$(ok grep -q '^bun' <<<"$L")" "中继 3055" "$(awk '{print $1" PID "$2}' <<<"$L")"
else item 0 "中继 3055" "没有在监听，双击桌面「启动 Figma 中继」或重跑 setup"; fi
echo "MANIFEST: $REPO/src/cursor_mcp_plugin/manifest.json"
[ $bad = 0 ] && echo "RESULT: OK" || { echo "RESULT: FAIL"; exit 1; }

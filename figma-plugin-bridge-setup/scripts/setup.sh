#!/usr/bin/env bash
# TalkToFigma 插件桥一键安装（macOS / Linux，幂等）
# 结果以最后一行 "RESULT: OK" / "RESULT: FAIL" 为准。
set -u
REPO="$HOME/.cursor/cursor-talk-to-figma-mcp"
MCP_JSON="$HOME/.cursor/mcp.json"
HERE="$(cd "$(dirname "$0")" && pwd)"
PORT=3055

fail() { echo "ERROR: $1"; echo "RESULT: FAIL"; exit 1; }
step() { echo "==> $1"; }
[ -n "${HTTPS_PROXY:-}" ] && export HTTP_PROXY="${HTTP_PROXY:-$HTTPS_PROXY}"

step "检查 bun"
BUN="$HOME/.bun/bin/bun"
[ -x "$BUN" ] || BUN="$(command -v bun || true)"
if [ -z "$BUN" ] || [ ! -x "$BUN" ]; then
  step "安装 bun"
  curl -fsSL https://bun.sh/install | bash || fail "bun 安装失败"
  BUN="$HOME/.bun/bin/bun"
  [ -x "$BUN" ] || fail "bun 安装后仍找不到"
fi
echo "    bun: $BUN"

step "准备 cursor-talk-to-figma-mcp"
SERVER_TS="$REPO/src/talk_to_figma_mcp/server.ts"
if [ ! -f "$SERVER_TS" ]; then
  if command -v git >/dev/null && git clone --depth 1 https://github.com/grab/cursor-talk-to-figma-mcp.git "$REPO"; then :; else
    step "git 不可用或失败，改下 zip"
    TMP="$(mktemp -d)"
    curl -fsSL -o "$TMP/ttf.zip" https://codeload.github.com/grab/cursor-talk-to-figma-mcp/zip/refs/heads/main || fail "download 失败"
    unzip -q "$TMP/ttf.zip" -d "$TMP" || fail "解压失败"
    rm -rf "$REPO"; mv "$TMP"/cursor-talk-to-figma-mcp-* "$REPO"
  fi
  [ -f "$SERVER_TS" ] || fail "找不到 server.ts"
fi
(cd "$REPO" && "$BUN" install) || fail "bun install 失败"

step "写入 Cursor MCP 配置"
"$BUN" "$HERE/merge-mcp.mjs" "$MCP_JSON" "$BUN" "$SERVER_TS" || fail "mcp.json 写入失败"

step "启动中继（端口 $PORT）"
listening() { lsof -nP -iTCP:$PORT -sTCP:LISTEN 2>/dev/null | tail -n +2; }
if [ -n "$(listening)" ]; then
  listening | grep -q '^bun' || fail "port $PORT in use：$(listening | awk '{print $1" PID "$2}' | head -1)"
  echo "    中继已在运行"
else
  (cd "$REPO" && nohup "$BUN" run src/socket.ts >"$REPO/socket.log" 2>&1 &)
  for _ in $(seq 20); do sleep 0.5; [ -n "$(listening)" ] && break; done
  [ -n "$(listening)" ] || fail "中继 10 秒内没有监听 $PORT，见 $REPO/socket.log"
  echo "    中继已在后台启动（日志 $REPO/socket.log）"
fi

if [ -d "$HOME/Desktop" ]; then
  SC="$HOME/Desktop/启动 Figma 中继.command"
  printf '#!/bin/bash\ncd "%s"\n"%s" run src/socket.ts\n' "$REPO" "$BUN" >"$SC"
  chmod +x "$SC"
  echo "    桌面快捷方式：$SC"
fi

MANIFEST="$REPO/src/cursor_mcp_plugin/manifest.json"
[ -f "$MANIFEST" ] || fail "找不到插件 manifest.json"
command -v pbcopy >/dev/null && printf '%s' "$MANIFEST" | pbcopy
echo
echo "MANIFEST: $MANIFEST"
echo "RESULT: OK"

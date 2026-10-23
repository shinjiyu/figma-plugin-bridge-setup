# TalkToFigma 插件桥状态检查（只读）
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$Repo = Join-Path $env:USERPROFILE '.cursor\cursor-talk-to-figma-mcp'
$McpJson = Join-Path $env:USERPROFILE '.cursor\mcp.json'
$bad = 0
function Item($ok, $name, $detail) {
  if ($ok) { Write-Host "[OK]   $name $detail" } else { Write-Host "[FAIL] $name $detail"; $script:bad++ }
}

$bun = Join-Path $env:USERPROFILE '.bun\bin\bun.exe'
if (-not (Test-Path $bun)) { $c = Get-Command bun -ErrorAction SilentlyContinue; if ($c) { $bun = $c.Source } }
Item (Test-Path $bun) 'bun' $bun
$server = Join-Path $Repo 'src\talk_to_figma_mcp\server.ts'
Item (Test-Path $server) '仓库' $Repo
Item (Test-Path (Join-Path $Repo 'node_modules')) '依赖' 'node_modules'

$entry = $null
if (Test-Path $McpJson) {
  try { $entry = (Get-Content $McpJson -Raw -Encoding UTF8 | ConvertFrom-Json).mcpServers.TalkToFigma } catch {}
}
$cfgOk = $entry -and (Test-Path $entry.command) -and (Test-Path $entry.args[0])
Item $cfgOk 'mcp.json' ($(if ($entry) { "$($entry.command) $($entry.args[0])" } else { '没有 TalkToFigma 条目' }))

$l = Get-NetTCPConnection -LocalPort 3055 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
if ($l) {
  $p = Get-Process -Id $l.OwningProcess -ErrorAction SilentlyContinue
  Item ($p.ProcessName -match '^bun') '中继 3055' "$($p.ProcessName) PID $($p.Id)"
} else { Item $false '中继 3055' '没有在监听，双击桌面「启动 Figma 中继」或重跑 setup' }

Write-Host "MANIFEST: $(Join-Path $Repo 'src\cursor_mcp_plugin\manifest.json')"
if ($bad) { Write-Host 'RESULT: FAIL'; exit 1 } else { Write-Host 'RESULT: OK' }

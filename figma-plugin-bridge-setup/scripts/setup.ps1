# TalkToFigma 插件桥一键安装（Windows，幂等）
# 结果以最后一行 "RESULT: OK" / "RESULT: FAIL" 为准。
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

$Home_ = $env:USERPROFILE
$Repo = Join-Path $Home_ '.cursor\cursor-talk-to-figma-mcp'
$McpJson = Join-Path $Home_ '.cursor\mcp.json'
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Port = 3055

function Fail($msg) { Write-Host "ERROR: $msg"; Write-Host 'RESULT: FAIL'; exit 1 }
function Step($msg) { Write-Host "==> $msg" }

if ($env:HTTPS_PROXY -and -not $env:HTTP_PROXY) { $env:HTTP_PROXY = $env:HTTPS_PROXY }
$proxyArgs = @{}
if ($env:HTTPS_PROXY) { $proxyArgs.Proxy = $env:HTTPS_PROXY }

# 1. bun
Step '检查 bun'
$Bun = Join-Path $Home_ '.bun\bin\bun.exe'
if (-not (Test-Path $Bun)) {
  $cmd = Get-Command bun -ErrorAction SilentlyContinue
  if ($cmd) { $Bun = $cmd.Source }
}
if (-not (Test-Path $Bun)) {
  Step '安装 bun'
  try { Invoke-RestMethod https://bun.sh/install.ps1 @proxyArgs | Invoke-Expression } catch { Fail "bun 安装失败：$($_.Exception.Message)" }
  $Bun = Join-Path $Home_ '.bun\bin\bun.exe'
  if (-not (Test-Path $Bun)) { Fail 'bun 安装后仍找不到 bun.exe' }
}
Write-Host "    bun: $Bun"

# 2. 仓库
Step '准备 cursor-talk-to-figma-mcp'
$ServerTs = Join-Path $Repo 'src\talk_to_figma_mcp\server.ts'
if (-not (Test-Path $ServerTs)) {
  $ok = $false
  if (Get-Command git -ErrorAction SilentlyContinue) {
    $gitArgs = @('clone', '--depth', '1', 'https://github.com/grab/cursor-talk-to-figma-mcp.git', $Repo)
    if ($env:HTTPS_PROXY) { $gitArgs = @('-c', "http.proxy=$($env:HTTPS_PROXY)") + $gitArgs }
    & git @gitArgs 2>&1 | Out-Host
    $ok = ($LASTEXITCODE -eq 0) -and (Test-Path $ServerTs)
  }
  if (-not $ok) {
    Step 'git 不可用或失败，改下 zip'
    $zip = Join-Path $env:TEMP 'ttf.zip'; $tmp = Join-Path $env:TEMP 'ttf-unzip'
    try {
      Invoke-WebRequest https://codeload.github.com/grab/cursor-talk-to-figma-mcp/zip/refs/heads/main -OutFile $zip -UseBasicParsing @proxyArgs
      if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
      Expand-Archive $zip $tmp -Force
      if (Test-Path $Repo) { Remove-Item $Repo -Recurse -Force }
      Move-Item (Get-ChildItem $tmp | Select-Object -First 1).FullName $Repo
    } catch { Fail "download 失败：$($_.Exception.Message)" }
    if (-not (Test-Path $ServerTs)) { Fail 'download 后找不到 server.ts' }
  }
}
Push-Location $Repo
& $Bun install 2>&1 | Out-Host
$code = $LASTEXITCODE
Pop-Location
if ($code -ne 0) { Fail 'bun install 失败' }

# 3. mcp.json
Step '写入 Cursor MCP 配置'
& $Bun (Join-Path $Here 'merge-mcp.mjs') $McpJson $Bun $ServerTs
if ($LASTEXITCODE -ne 0) { Fail 'mcp.json 写入失败' }

# 4. 中继
Step "启动中继（端口 $Port）"
$listen = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
if ($listen) {
  $p = Get-Process -Id $listen.OwningProcess -ErrorAction SilentlyContinue
  if ($p -and $p.ProcessName -notmatch '^bun') { Fail "port $Port in use，被 $($p.ProcessName)（PID $($p.Id)）占用" }
  Write-Host '    中继已在运行'
} else {
  Start-Process -FilePath $Bun -ArgumentList 'run', 'src/socket.ts' -WorkingDirectory $Repo -WindowStyle Minimized
  $up = $false
  for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Milliseconds 500
    if (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue) { $up = $true; break }
  }
  if (-not $up) { Fail "中继 10 秒内没有监听 $Port" }
  Write-Host '    中继已启动（最小化窗口，别关）'
}

# 5. 桌面快捷方式
$Desk = [Environment]::GetFolderPath('Desktop')
$Cmd = Join-Path $Desk '启动 Figma 中继.cmd'
$body = "@echo off`r`ntitle Figma 中继（别关这个窗口）`r`ncd /d `"$Repo`"`r`n`"$Bun`" run src/socket.ts`r`npause`r`n"
[IO.File]::WriteAllText($Cmd, $body, [Text.Encoding]::GetEncoding(936))
Write-Host "    桌面快捷方式：$Cmd"

# 6. manifest
$Manifest = Join-Path $Repo 'src\cursor_mcp_plugin\manifest.json'
if (-not (Test-Path $Manifest)) { Fail '找不到插件 manifest.json' }
try { Set-Clipboard -Value $Manifest } catch {}
Write-Host ''
Write-Host "MANIFEST: $Manifest"
Write-Host '（已复制到剪贴板）'
Write-Host 'RESULT: OK'

Set-Location -LiteralPath $PSScriptRoot

$nodeVersionText = node --version 2>$null
if ($LASTEXITCODE -ne 0 -or -not $nodeVersionText) {
  Write-Error '未找到 Node.js。请安装 Node.js 22.5 或更高版本。'
  exit 1
}
$nodeVersion = [version]($nodeVersionText.TrimStart('v') + '.0')
if ($nodeVersion -lt [version]'22.5.0') {
  Write-Error "Node.js 版本过低：$nodeVersionText。请使用 Node.js 22.5 或更高版本。"
  exit 1
}

if (-not (Test-Path -LiteralPath '.env')) {
  Copy-Item -LiteralPath '.env.example' -Destination '.env'
  Write-Host 'Created server/.env. AI remains in demo mode until you configure all three VISION_* values.'
}

node scripts/check-env.mjs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Avoid starting a second server when the previous terminal/process is still alive.
$existing = Get-NetTCPConnection -LocalPort 8787 -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
$existingPid = if ($existing) { [int]$existing.OwningProcess } else { 0 }
if (-not $existingPid) {
  $netstatLine = netstat -ano | Select-String '\s0\.0\.0\.0:8787\s.*LISTENING\s+(\d+)$' | Select-Object -First 1
  if ($netstatLine -and $netstatLine.Matches.Count -gt 0) { $existingPid = [int]$netstatLine.Matches[0].Groups[1].Value }
}
if ($existingPid) {
  try {
    $health = Invoke-RestMethod -Uri 'http://127.0.0.1:8787/api/health' -TimeoutSec 2
    if ($health.service -eq 'birdfolio') {
      Write-Host "Birdfolio server is already running at http://127.0.0.1:8787 (PID $existingPid)."
      Write-Host 'Keep using the existing server; do not start a second copy.'
      exit 0
    }
  } catch {
    Write-Error "Port 8787 is already occupied by PID $existingPid. Stop that process or choose another PORT before starting Birdfolio."
    exit 1
  }
}

$wireless = Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias 'WLAN' -ErrorAction SilentlyContinue |
  Where-Object { $_.IPAddress -notlike '169.254.*' } |
  Select-Object -First 1 -ExpandProperty IPAddress
if ($wireless) {
  Write-Host "Phone URL (when on the same reachable Wi-Fi): http://${wireless}:8787"
} else {
  Write-Host 'Run ipconfig and use the WLAN IPv4 address in the app settings.'
}
Write-Host 'Keep this terminal open while using the community and AI features.'
node --dns-result-order=ipv4first src/server.mjs

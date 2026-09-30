[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$env:PUB_CACHE = Join-Path $PSScriptRoot '.pub-cache'

flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

flutter build web --release --pwa-strategy=none --base-href / --dart-define-from-file=.dart-defines.public.json
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$publicConfig = Get-Content -LiteralPath '.dart-defines.public.json' -Raw | ConvertFrom-Json
$env:VITE_SUPABASE_URL = [string]$publicConfig.SUPABASE_URL
$env:VITE_SUPABASE_ANON_KEY = [string]$publicConfig.SUPABASE_ANON_KEY

npm.cmd ci --prefix operator-panel
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

npm.cmd run build --prefix operator-panel -- --base /painel/
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$panelOutput = Join-Path $PSScriptRoot 'build/web/painel'
if (Test-Path -LiteralPath $panelOutput) {
    $resolvedPanelOutput = (Resolve-Path -LiteralPath $panelOutput).Path
    if ($resolvedPanelOutput -ne $panelOutput) { throw 'Destino do painel fora da pasta esperada.' }
    Remove-Item -LiteralPath $panelOutput -Recurse -Force
}
New-Item -ItemType Directory -Path $panelOutput -Force | Out-Null
Get-ChildItem -LiteralPath 'operator-panel/dist' | Copy-Item -Destination $panelOutput -Recurse -Force
Write-Host 'Versao para Vercel pronta em build/web.'

[CmdletBinding()]
param(
    [switch]$CheckOnly,
    [string]$ConfigPath
)

$ErrorActionPreference = 'Stop'
try {
    if (-not $ConfigPath) { $ConfigPath = Join-Path $PSScriptRoot '.dart-defines.json' }
    $createConfiguration = -not (Test-Path -LiteralPath $ConfigPath)
    if ($createConfiguration) {
        if ($CheckOnly) { throw 'Configuracao ausente. Execute .\run-blualert.bat e informe a URL e a chave publica do Supabase.' }
        Write-Host 'Conecte ao projeto Supabase que ja possui sua conta. Nao precisa cadastrar novamente.'
        $projectUrl = (Read-Host 'Project URL (https://...supabase.co)').Trim().TrimEnd('/')
        $publicKey = (Read-Host 'Chave publica anon ou sb_publishable_...').Trim()
    } else {
        $configuration = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
        $projectUrl = ([string]$configuration.SUPABASE_URL).Trim().TrimEnd('/')
        $publicKey = ([string]$configuration.SUPABASE_ANON_KEY).Trim()
    }

    $projectUri = $null
    if (-not [Uri]::TryCreate($projectUrl, [UriKind]::Absolute, [ref]$projectUri) -or
        $projectUri.Scheme -ne 'https' -or -not $projectUri.Host.Contains('.') -or
        $projectUri.AbsolutePath -ne '/' -or $projectUri.Query -or $projectUri.Fragment -or $projectUri.UserInfo -or
        $projectUrl -match 'SEU_PROJECT_REF') {
        throw 'SUPABASE_URL invalida. Copie a Project URL do seu projeto, sem caminhos ou parametros.'
    }
    if ($publicKey.StartsWith('sb_secret_')) { throw 'Chave secret recusada. Use somente a chave publica anon/publishable.' }
    if ($publicKey -notmatch '^sb_publishable_[A-Za-z0-9_-]+$') {
        $jwtParts = $publicKey.Split('.')
        if ($jwtParts.Count -ne 3) { throw 'Chave publica invalida ou ainda preenchida com o exemplo.' }
        try {
            $payload = $jwtParts[1].Replace('-', '+').Replace('_', '/')
            $payload = $payload.PadRight($payload.Length + ((4 - $payload.Length % 4) % 4), '=')
            $claims = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json
        } catch { throw 'Chave anon invalida. Copie novamente a chave publica completa.' }
        if ($claims.role -ne 'anon') { throw 'Esta chave nao e anon. Tokens de usuario e chaves service_role nao podem configurar o app.' }
        if ($claims.ref -and $projectUri.Host.EndsWith('.supabase.co') -and $claims.ref -ne $projectUri.Host.Split('.')[0]) {
            throw 'A URL e a chave pertencem a projetos diferentes.'
        }
    }

    if ($createConfiguration) {
        $configurationJson = @{SUPABASE_URL = $projectUrl; SUPABASE_ANON_KEY = $publicKey} | ConvertTo-Json
        [IO.File]::WriteAllText($ConfigPath, $configurationJson, [Text.UTF8Encoding]::new($false))
        Write-Host 'Configuracao salva em .dart-defines.json.'
    }
    Write-Host 'Configuracao local validada. A conta sera verificada ao entrar no aplicativo.'
    exit 0
} catch {
    Write-Host ('Nao foi possivel configurar: ' + $_.Exception.Message)
    exit 1
}

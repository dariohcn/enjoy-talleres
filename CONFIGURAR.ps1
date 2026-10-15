$ErrorActionPreference = 'Stop'
Set-Location -LiteralPath $PSScriptRoot
$projectEndpoint = (Read-Host 'URL del proyecto (https://identificador.supabase.co)').Trim().TrimEnd('/')
$projectPublicKey = (Read-Host 'Clave publicable (nunca una clave secreta o service_role)').Trim()
if ($projectEndpoint -notmatch '^https://[a-z0-9-]+\.supabase\.co$') { throw 'URL no válida.' }
if ($projectPublicKey.StartsWith('sb_secret_') -or -not $projectPublicKey) { throw 'Debe utilizar la clave publicable.' }
if ($projectPublicKey.StartsWith('eyJ')) {
    $payloadPart = $projectPublicKey.Split('.')[1].Replace('-', '+').Replace('_', '/')
    $payloadPart = $payloadPart.PadRight([int]([Math]::Ceiling($payloadPart.Length / 4.0) * 4), '=')
    $keyData = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payloadPart)) | ConvertFrom-Json
    if ($keyData.role -ne 'anon') { throw 'No publique una clave con privilegios de servidor.' }
} elseif (-not $projectPublicKey.StartsWith('sb_publishable_')) { throw 'Formato de clave publicable no reconocido.' }
$publicConfig = @{endpoint=$projectEndpoint;publicKey=$projectPublicKey} | ConvertTo-Json
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'config.js'), "window.ENJOY_CONFIG = Object.freeze($publicConfig);`n", [Text.UTF8Encoding]::new($false))
Write-Host 'Conexión guardada en config.js. Continúe con LEAME-PRIMERO.md para instalar la base de datos.'
& (Join-Path $PSScriptRoot 'VERIFICAR.ps1')

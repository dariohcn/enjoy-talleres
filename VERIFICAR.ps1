$ErrorActionPreference = 'Stop'
$manifestPath = Join-Path $PSScriptRoot 'ARCHIVOS.json'
if (-not (Test-Path -LiteralPath $manifestPath)) { throw 'Falta ARCHIVOS.json. Extraiga el ZIP completo.' }
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
$failures = @()
foreach ($entry in $manifest) {
    $filePath = Join-Path $PSScriptRoot $entry.path
    if (-not (Test-Path -LiteralPath $filePath -PathType Leaf)) { $failures += "Falta: $($entry.path)"; continue }
    if ($entry.path -ne 'config.js') {
        $actualHash = (Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash.ToLower()
        if ($actualHash -ne $entry.sha256) { $failures += "Archivo modificado: $($entry.path)" }
    }
}
if ($failures.Count) { $failures | ForEach-Object { Write-Host $_ }; throw 'El proyecto está incompleto o fue modificado. Revise los archivos indicados.' }
Write-Host "Correcto: $($manifest.Count) archivos presentes. Esto verifica la entrega; no confirma la conexión del servidor."

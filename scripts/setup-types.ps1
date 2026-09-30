# Tip analizi araçlarını .tools/luau-lsp altına indirir (git'e girmez).
# Kaynak: JohnnyMorganz/luau-lsp (GitHub sürümü) ve aynı depodaki Roblox tip tanımları (globalTypes.d.luau).
# Sonra: python scripts/check-types.py  (verify.ps1 de çalıştırır; araç yoksa adım atlanır)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$dir = Join-Path $root ".tools/luau-lsp"
New-Item -ItemType Directory -Path $dir -Force | Out-Null
$zip = Join-Path $dir "luau-lsp-win64.zip"
Invoke-WebRequest -Uri "https://github.com/JohnnyMorganz/luau-lsp/releases/latest/download/luau-lsp-win64.zip" -OutFile $zip
Expand-Archive -LiteralPath $zip -DestinationPath $dir -Force
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau" -OutFile (Join-Path $dir "globalTypes.d.luau")
Write-Host "Kuruldu: $dir"

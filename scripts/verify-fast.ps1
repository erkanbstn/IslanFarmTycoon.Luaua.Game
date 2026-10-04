# Hızlı geliştirme kontrolü; yayın/merge öncesi verify.ps1 -Mode Full kullan.
param(
	[string]$LuauDirectory = "",
	[string]$Python = "python",
	[switch]$RequireTypes
)
$ErrorActionPreference = "Stop"
& (Join-Path $PSScriptRoot "verify.ps1") -Mode Fast -LuauDirectory $LuauDirectory -Python $Python -RequireTypes:$RequireTypes
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

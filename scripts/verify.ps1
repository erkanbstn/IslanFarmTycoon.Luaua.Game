param(
	[string]$LuauDirectory = "",
	[string]$Python = "python"
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$toolManifest = Get-Content -LiteralPath (Join-Path $projectRoot "rokit.toml") -Raw
$failures = [System.Collections.Generic.List[string]]::new()

function Resolve-ProjectTool([string]$Name) {
	# Read the pinned version instead of accidentally taking another project's tool.
	$escapedName = [Regex]::Escape($Name)
	$match = [Regex]::Match($toolManifest, "(?m)^$escapedName\s*=\s*`"([^`"]+)`"")
	if (-not $match.Success) { throw "Tool missing from rokit.toml: $Name" }
	$pin = $match.Groups[1].Value
	$parts = $pin.Split('@')
	$relative = $parts[0].ToLowerInvariant().Replace('/', [IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar + $parts[1]
	$profileRoot = [Environment]::GetFolderPath("UserProfile")
	if (-not $profileRoot) { $profileRoot = $env:USERPROFILE }
	$extension = if ($env:OS -eq "Windows_NT") { ".exe" } else { "" }
	if ($profileRoot) {
		$direct = Join-Path $profileRoot (".rokit/tool-storage/" + $relative + "/" + $Name + $extension)
		if (Test-Path -LiteralPath $direct) { return $direct }
	}
	$command = Get-Command $Name -ErrorAction SilentlyContinue
	if ($command) { return $command.Source }
	throw "Missing $Name ($pin). Run rokit install first."
}

function Invoke-Check([string]$Label, [scriptblock]$Action) {
	Write-Host "Running: $Label"
	try {
		& $Action
		if ($LASTEXITCODE -ne 0) { throw "Exit code $LASTEXITCODE" }
	} catch {
		$failures.Add($Label)
		Write-Warning "$Label failed: $_"
	}
}

Push-Location $projectRoot
try {
	$stylua = Resolve-ProjectTool "stylua"
	$selene = Resolve-ProjectTool "selene"
	$rojo = Resolve-ProjectTool "rojo"
	if (-not $LuauDirectory) { $LuauDirectory = Join-Path $projectRoot ".tools/luau" }
	$extension = if ($env:OS -eq "Windows_NT") { ".exe" } else { "" }
	$interpreter = Join-Path $LuauDirectory ("luau" + $extension)
	$compiler = Join-Path $LuauDirectory ("luau-compile" + $extension)
	$analyzer = Join-Path $LuauDirectory ("luau-analyze" + $extension)
	if (-not (Test-Path -LiteralPath $interpreter) -or -not (Test-Path -LiteralPath $compiler) -or -not (Test-Path -LiteralPath $analyzer)) {
		throw "Luau 0.740 interpreter/compiler/analyzer missing. Provide -LuauDirectory PATH."
	}
	New-Item -ItemType Directory -Path ".test-build" -Force | Out-Null
	Invoke-Check "StyLua" { & $stylua --check src plugin tests }
	Invoke-Check "Selene" { & $selene src plugin tests }
	Invoke-Check "Luau syntax compilation" {
		$sourceFiles = Get-ChildItem -LiteralPath src,plugin,tests -Recurse -File -Filter *.luau | Select-Object -ExpandProperty FullName
		& $compiler --null @sourceFiles
	}
	Invoke-Check "Pure Luau regression tests" { & $Python scripts/run-tests.py --luau $interpreter }
	Invoke-Check "Locale key parity and UI literal coverage" { & $Python scripts/check-locales.py --strict-literals }
	Invoke-Check "AI guide consistency" { & $Python scripts/check-ai-docs.py }
	Invoke-Check "Pure helper type analysis (SessionLock, OrderRules, SeasonVisuals only)" {
		& $analyzer src/server/Modules/SessionLock.luau src/server/Modules/OrderRules.luau src/shared/Modules/SeasonVisuals.luau
	}
	Invoke-Check "Game Rojo build" { & $rojo build default.project.json -o .test-build/game.rbxlx }
	Invoke-Check "Plugin Rojo build" { & $rojo build plugin.project.json -o .test-build/plugin.rbxmx }
	Invoke-Check "Studio test Rojo build" { & $rojo build test.project.json -o .test-build/tests.rbxlx }
} finally {
	Pop-Location
}

if ($failures.Count -gt 0) {
	throw ("Verification failed: " + ($failures -join ", "))
}
Write-Host "All automated checks passed. Studio multiplayer, DataStore fault and device tests remain separate."

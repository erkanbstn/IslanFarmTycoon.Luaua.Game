param(
	[ValidateSet("Fast", "Full")]
	[string]$Mode = "Full",
	[string]$LuauDirectory = "",
	[string]$Python = "python",
	# CI/temiz klon: luau-lsp yoksa tip denetimini atlamak yerine hata ver
	[switch]$RequireTypes
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$toolManifest = Get-Content -LiteralPath (Join-Path $projectRoot "rokit.toml") -Raw
$failures = [System.Collections.Generic.List[string]]::new()
$skipped = [System.Collections.Generic.List[string]]::new()

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
	Invoke-Check "Harness dependency and lexical order checks" { & $Python scripts/check-test-dependencies.py }
	Invoke-Check "AI tooling regression tests" { & $Python tests/tooling.spec.py }
	Invoke-Check "Economy comparison regression tests" { & $Python scripts/test-compare-economy.py }
	Invoke-Check "Studio QA generation regression tests" { & $Python scripts/test-studio-qa.py }
	Invoke-Check "Pure Luau regression tests" { & $Python scripts/run-tests.py --luau $interpreter }
	Invoke-Check "Visual service identity regression tests" { & $Python scripts/check-visual-identity.py --luau $interpreter }
	Invoke-Check "Type checker failure and baseline regression tests" { & $Python scripts/test-check-types.py }
	if ($Mode -eq "Full") {
		Invoke-Check "Simulation completion stopping regression tests" { & $Python tests/simulation-stop.spec.py --luau $interpreter }
		Invoke-Check "Economy simulation smoke (--smoke parses the JSON itself)" {
			& $Python scripts/simulate-economy.py --luau $interpreter --persona casual --hours 2 --smoke
		}
		Invoke-Check "Rebirth economy simulation smoke" {
			& $Python scripts/simulate-economy.py --luau $interpreter --persona casual --hours 2 --completion basic --rebirth 1 --perks income:1 --starting-gold 780 --gold-policy equipment --smoke
		}
		# Uçuk değer denetimi: parti miktarı, ürün değeri/taban, sipariş ödülü/değer ve gelir dakikası, kademe fiyat tavanı (ECONOMY_LIMITS)
		Invoke-Check "Economy audit (absurd values)" { & $Python scripts/audit-economy.py --luau $interpreter --check }
		# Çiftlik tamamlama süresi tema 1 -> 6 her oyuncu tipinde KESİN artar; tüm çiftlikler bitince simülasyon durur.
		Invoke-Check "Tier completion times grow with the theme (sim)" { & $Python scripts/simulate-tiers.py --luau $interpreter --personas ideal,casual,idle --assert-monotonic }
	}
	Invoke-Check "Locale key parity and UI literal coverage" { & $Python scripts/check-locales.py --strict-literals }
	Invoke-Check "Config text translation coverage" { & $Python scripts/check-config-locales.py }
	Invoke-Check "AI guide consistency" { & $Python scripts/check-ai-docs.py }
	Invoke-Check "Repository hygiene (dead references, orphans, tracked junk)" { & $Python scripts/check-repo-hygiene.py }
	if ($Mode -eq "Full") {
		Invoke-Check "Model asset coverage" { & $Python scripts/check-assets.py }
		Invoke-Check "Model validator regression tests" { & $Python scripts/test-check-assets.py }
	}
	Invoke-Check "Pure helper type analysis (SessionLock, SeasonVisuals only)" {
		& $analyzer src/server/Modules/SessionLock.luau src/shared/Modules/SeasonVisuals.luau
	}
	Invoke-Check "Architecture dependency rules" { & $Python scripts/check-architecture.py }
	# check-types.py araçlar yoksa sessizce 0 döner; burada atlama görünür olsun (temiz klonda yanlış güven vermesin).
	$lspExecutable = Join-Path $projectRoot (".tools/luau-lsp/luau-lsp" + $extension)
	$lspDefinitions = Join-Path $projectRoot ".tools/luau-lsp/globalTypes.d.luau"
	if ((Test-Path -LiteralPath $lspExecutable) -and (Test-Path -LiteralPath $lspDefinitions)) {
		Invoke-Check "Type analysis (baseline)" { & $Python scripts/check-types.py }
	} elseif ($RequireTypes) {
		$failures.Add("Type analysis (luau-lsp missing, -RequireTypes)")
		Write-Warning "Type analysis FAILED: .tools/luau-lsp is missing and -RequireTypes was given. Install: powershell scripts/setup-types.ps1"
	} else {
		$skipped.Add("Type analysis")
		Write-Warning "Type analysis SKIPPED: .tools/luau-lsp is missing, so new type findings can slip through. Install: powershell scripts/setup-types.ps1"
	}
	if ($Mode -eq "Full") {
		Invoke-Check "Game Rojo build" { & $rojo build default.project.json -o .test-build/game.rbxlx }
		Invoke-Check "Plugin Rojo build" { & $rojo build plugin.project.json -o .test-build/plugin.rbxmx }
		Invoke-Check "Studio test Rojo build" { & $rojo build test.project.json -o .test-build/tests.rbxlx }
		# Harita eklentisi Rojo ile güncellenmez: plugin/ eklenti dosyasından yeniyse derlenmemiş demektir.
		$installedPlugin = if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA "Roblox/Plugins/IslandFarmTycoonHarita.rbxm" } else { "" }
		if ($installedPlugin -and (Test-Path -LiteralPath $installedPlugin)) {
			$pluginSources = @(Get-ChildItem -LiteralPath plugin -Recurse -File) + @(Get-Item -LiteralPath plugin.project.json)
			$newestSource = $pluginSources | Sort-Object LastWriteTime -Descending | Select-Object -First 1
			if ($newestSource.LastWriteTime -gt (Get-Item -LiteralPath $installedPlugin).LastWriteTime) {
				$skipped.Add("Installed Studio plugin is older than plugin/")
				Write-Warning "Studio map plugin may be stale ($($newestSource.Name) is newer than the installed .rbxm). Rebuild: rojo build plugin.project.json --plugin IslandFarmTycoonHarita.rbxm"
			}
		}
	}
} finally {
	Pop-Location
}

if ($failures.Count -gt 0) {
	throw ("Verification failed: " + ($failures -join ", "))
}
if ($skipped.Count -gt 0) {
	Write-Warning ("Automated checks passed, but NOT everything ran: " + ($skipped -join "; "))
}
if ($Mode -eq "Fast") {
	Write-Host "Fast checks passed. Full mode additionally runs simulations/economy audit, assets and Rojo builds. Studio checks remain separate."
} else {
	Write-Host "All Full automated checks passed. Studio multiplayer, DataStore fault and device tests remain separate."
}

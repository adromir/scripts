# ==============================================================================
# llama.cpp Benchmark Suite
# Author: Adromir (https://github.com/adromir)
# Description: Automated real-world performance benchmark for llama.cpp.
# Features:
#   1. Compare multiple llama.cpp builds with 1 model
#   2. Compare multiple GGUF models with 1 build
#   3. Parameter Sweep across thread, GPU, or context configurations
# Architecture: Clean separation of functional code, layout (XAML/HTML), and i18n.
# ==============================================================================

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic

# --- Path Resolution ---
$scriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptDir) -and (-not [string]::IsNullOrWhiteSpace($PSCommandPath))) {
	$scriptDir = Split-Path -Parent $PSCommandPath
}
if ([string]::IsNullOrWhiteSpace($scriptDir)) {
	$scriptDir = (Get-Location).Path
}

$xamlPath     = Join-Path -Path $scriptDir -ChildPath "MainWindow.xaml"
$profileDlgPath = Join-Path -Path $scriptDir -ChildPath "ProfileDialog.xaml"
$langDir      = Join-Path -Path $scriptDir -ChildPath "lang"
$profilesPath = Join-Path -Path $scriptDir -ChildPath "profiles.json"
$templatePath = Join-Path -Path $scriptDir -ChildPath "templates\report_template.html"
$jinjaPath    = Join-Path -Path $scriptDir -ChildPath "templates\benchmark.jinja"

# Ensure MainWindow.xaml exists
if (-not (Test-Path -Path $xamlPath)) {
	[System.Windows.Forms.MessageBox]::Show("MainWindow.xaml not found in:`n$xamlPath", "Fatal Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
	exit 1
}

# --- Dynamic Localization Loader ---
$global:Localization = @{}
if (Test-Path -Path $langDir) {
	Get-ChildItem -Path $langDir -Filter "*.json" | ForEach-Object {
		$code = $_.BaseName.ToLower()
		try {
			$jsonRaw = Get-Content -Path $_.FullName -Raw -Encoding UTF8
			$jsonObj = ConvertFrom-Json $jsonRaw
			$dict = @{}
			foreach ($prop in $jsonObj.psobject.Properties) {
				$dict[$prop.Name] = $prop.Value
			}
			$global:Localization[$code] = $dict
		}
		catch {
			Write-Warning "Failed to parse language file: $($_.FullName)"
		}
	}
}

if ($global:Localization.Count -eq 0) {
	[System.Windows.Forms.MessageBox]::Show("No valid translation files found in:`n$langDir", "Fatal Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
	exit 1
}

# Determine default language
$sysLang = [System.Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName.ToLower()
$global:CurrentLang = if ($global:Localization.ContainsKey($sysLang)) { $sysLang } elseif ($global:Localization.ContainsKey("en")) { "en" } else { ($global:Localization.Keys | Select-Object -First 1) }

function Get-LocalizedText {
	param(
		[string]$Key,
		[object[]]$FormatArgs
	)
	$dict = $global:Localization[$global:CurrentLang]
	if ($null -ne $dict -and $dict.ContainsKey($Key)) {
		$val = [string]$dict[$Key]
		if ($FormatArgs -and $FormatArgs.Count -gt 0) {
			return ($val -f $FormatArgs)
		}
		return $val
	}
	return $Key
}

# --- Test Suite Scenarios ---
$Scenarios = @(
	@{
		Id              = "short"
		Name            = "Scenario 1: Quick Q&A"
		TokensToPredict = 96
		Prompt          = "Explain the technical concept of zero-cost abstractions in systems programming languages like Rust and modern C++. Detail how compiler optimization passes eliminate runtime overhead compared to dynamic dispatch."
	},
	@{
		Id              = "reasoning"
		Name            = "Scenario 2: Code & Architecture"
		TokensToPredict = 256
		Prompt          = "Design a high-performance thread-safe lock-free ring buffer in modern C++20 using std::atomic with explicit acquire-release memory order semantics. Explain why sequential consistency is unnecessary here, how cache-line bouncing and false sharing are prevented via hardware cache-line padding, and provide a full code implementation with enqueue and dequeue methods."
	},
	@{
		Id              = "prefill"
		Name            = "Scenario 3: Heavy Context Prefill"
		TokensToPredict = 64
		Prompt          = @"
Distributed Transactional Storage Engine Architecture Specification:
1. Storage Topology: The cluster implements a shared-nothing sharded architecture where each storage node manages key-value partitions using Log-Structured Merge (LSM) trees backed by non-volatile NVMe storage. Client mutations append to an append-only Write-Ahead Log (WAL) before updating an in-memory mutable memtable implemented as a concurrent skip-list. Write operations utilize Direct I/O with asynchronous completion queues via io_uring to bypass the operating system page cache, eliminating writeback stalls. When an active memtable reaches 128 MiB, it is converted into an immutable snapshot flushed asynchronously to Level-0 SSTable files. Each SSTable contains an index block, bloom filters configured with 10 bits per key yielding 1% false positive probability, and Zstandard compression dictionaries.
2. Compaction Hierarchy: To mitigate read amplification across overlapping L0 files, leveled compaction operates across six levels (L0 to L5). Each level Ln enforces strict non-overlapping partition boundaries with ten times the capacity of Ln-1. When level Ln exceeds quota, concurrent compaction workers merge-sort overlapping tables into Ln+1, purging tombstones preceding the cluster-wide active transaction watermark.
3. Distributed Consensus: Availability zones coordinate replication through Multi-Paxos augmented with leadership leases. Each partition constitutes a consensus group of five voting replicas. The elected leader acquires a renewable physical time lease synchronized via hybrid logical clocks (HLC) bounded by precision time protocol daemons. Client writes submit exclusively to the leaseholder, which broadcasts Paxos Accept messages over an RDMA mesh transport. Once a quorum of three replicas acknowledges durable flush, the mutation applies to the LSM tree and commits.
4. Concurrency Control: Snapshot Isolation uses multi-version concurrency control (MVCC). Every record contains an 8-byte descending commit sequence number. Point queries leverage an LRU block cache in pinned hugepage memory. Write conflicts detect at commit time via optimistic coordinators.
Analyze the architecture described above. Evaluate the trade-offs between write amplification and read latency, assess lease renewal resilience under clock drift, and describe Direct I/O interactions with NVMe controller queue depths during concurrent flush and compaction.
"@
	},
	@{
		Id              = "stress"
		Name            = "Scenario 4: Sustained Generation"
		TokensToPredict = 512
		Prompt          = "Write a complete production-grade asynchronous telemetry processing worker pool in modern Rust or C++. Implement worker thread management, graceful shutdown on termination signals, dynamic backpressure queues, exponential backoff retries with jitter for downstream failures, and telemetry metrics tracking throughput, p99 latency percentiles, and active worker count. Provide full runnable code with detailed architectural comments."
	}
)

# --- Load WPF UI from XAML ---
$xmlReader = [System.Xml.XmlReader]::Create($xamlPath)
$Window    = [System.Windows.Markup.XamlReader]::Load($xmlReader)
$xmlReader.Close()

# --- Map UI Controls ---
$LblAppTitle           = $Window.FindName("LblAppTitle")
$LblBenchmarkMode      = $Window.FindName("LblBenchmarkMode")
$CmbBenchmarkMode      = $Window.FindName("CmbBenchmarkMode")
$LblLanguage           = $Window.FindName("LblLanguage")
$CmbLanguage           = $Window.FindName("CmbLanguage")
$GrpSetup              = $Window.FindName("GrpSetup")

$LblSingleCli          = $Window.FindName("LblSingleCli")
$TxtSingleCli          = $Window.FindName("TxtSingleCli")
$BtnBrowseSingleCli    = $Window.FindName("BtnBrowseSingleCli")

$LblModelPath          = $Window.FindName("LblModelPath")
$TxtModelPath          = $Window.FindName("TxtModelPath")
$BtnBrowseModel        = $Window.FindName("BtnBrowseModel")

$GridBaseParams        = $Window.FindName("GridBaseParams")
$LblThreads            = $Window.FindName("LblThreads")
$TxtThreads            = $Window.FindName("TxtThreads")
$LblGpuLayers          = $Window.FindName("LblGpuLayers")
$TxtGpuLayers          = $Window.FindName("TxtGpuLayers")
$LblCtxSize            = $Window.FindName("LblCtxSize")
$TxtCtxSize            = $Window.FindName("TxtCtxSize")

$LblGpuDevice          = $Window.FindName("LblGpuDevice")
$CmbGpuDevice          = $Window.FindName("CmbGpuDevice")
$BtnRefreshGpu         = $Window.FindName("BtnRefreshGpu")
$LblRepetitions        = $Window.FindName("LblRepetitions")
$CmbRepetitions        = $Window.FindName("CmbRepetitions")

$LblChatTemplate       = $Window.FindName("LblChatTemplate")
$TxtChatTemplate       = $Window.FindName("TxtChatTemplate")
$BtnBrowseTemplate     = $Window.FindName("BtnBrowseTemplate")
$BtnBenchmarkTemplate  = $Window.FindName("BtnBenchmarkTemplate")

# Profiles Controls
$LblProfiles           = $Window.FindName("LblProfiles")
$CmbProfiles           = $Window.FindName("CmbProfiles")
$BtnApplyProfile       = $Window.FindName("BtnApplyProfile")
$BtnManageProfiles     = $Window.FindName("BtnManageProfiles")
$BtnSaveCurrentProfile = $Window.FindName("BtnSaveCurrentProfile")

# Advanced Performance Tuning Controls
$ExpAdvancedParams     = $Window.FindName("ExpAdvancedParams")
$LblBatchSize          = $Window.FindName("LblBatchSize")
$TxtBatchSize          = $Window.FindName("TxtBatchSize")
$LblUbatchSize         = $Window.FindName("LblUbatchSize")
$TxtUbatchSize         = $Window.FindName("TxtUbatchSize")
$LblCacheTypeK         = $Window.FindName("LblCacheTypeK")
$CmbCacheTypeK         = $Window.FindName("CmbCacheTypeK")
$LblCacheTypeV         = $Window.FindName("LblCacheTypeV")
$CmbCacheTypeV         = $Window.FindName("CmbCacheTypeV")
$ChkFlashAttn          = $Window.FindName("ChkFlashAttn")
$ChkMlock              = $Window.FindName("ChkMlock")
$ChkMmap               = $Window.FindName("ChkMmap")
$ChkCpuAffinity        = $Window.FindName("ChkCpuAffinity")
$TxtCpuAffinity        = $Window.FindName("TxtCpuAffinity")
$ChkDflash             = $Window.FindName("ChkDflash")
$ChkGdnReplay          = $Window.FindName("ChkGdnReplay")

# Mode Panels
$GrpBuilds             = $Window.FindName("GrpBuilds")
$LstBuilds             = $Window.FindName("LstBuilds")
$BtnAddBuild           = $Window.FindName("BtnAddBuild")
$BtnRemoveBuild        = $Window.FindName("BtnRemoveBuild")
$BtnClearBuilds        = $Window.FindName("BtnClearBuilds")

$GrpModels             = $Window.FindName("GrpModels")
$LstModels             = $Window.FindName("LstModels")
$BtnAddModels          = $Window.FindName("BtnAddModels")
$BtnRemoveModel        = $Window.FindName("BtnRemoveModel")
$BtnClearModels        = $Window.FindName("BtnClearModels")

$GrpParams             = $Window.FindName("GrpParams")
$LstParams             = $Window.FindName("LstParams")
$TxtNewParamName       = $Window.FindName("TxtNewParamName")
$TxtNewParamThreads    = $Window.FindName("TxtNewParamThreads")
$TxtNewParamGpu        = $Window.FindName("TxtNewParamGpu")
$TxtNewParamCtx        = $Window.FindName("TxtNewParamCtx")
$BtnAddCustomParam     = $Window.FindName("BtnAddCustomParam")
$LblQuickSweep         = $Window.FindName("LblQuickSweep")
$CmbQuickSweep         = $Window.FindName("CmbQuickSweep")
$BtnApplyQuickSweep    = $Window.FindName("BtnApplyQuickSweep")
$BtnRemoveParam        = $Window.FindName("BtnRemoveParam")
$BtnClearParams        = $Window.FindName("BtnClearParams")

$GrpSuite              = $Window.FindName("GrpSuite")
$ChkWarmup             = $Window.FindName("ChkWarmup")
$ChkScenShort          = $Window.FindName("ChkScenShort")
$ChkScenReason         = $Window.FindName("ChkScenReason")
$ChkScenPrefill        = $Window.FindName("ChkScenPrefill")
$ChkScenStress         = $Window.FindName("ChkScenStress")
$LblScenEvalHeader     = $Window.FindName("LblScenEvalHeader")
$LblScenPromptSpeed    = $Window.FindName("LblScenPromptSpeed")
$LblScenGenSpeed       = $Window.FindName("LblScenGenSpeed")
$LblScenLoadTime       = $Window.FindName("LblScenLoadTime")

$BtnRun                = $Window.FindName("BtnRun")
$BtnReport             = $Window.FindName("BtnReport")
$PrgStatus             = $Window.FindName("PrgStatus")
$GrpLog                = $Window.FindName("GrpLog")
$TxtLog                = $Window.FindName("TxtLog")
$TxtStatus             = $Window.FindName("TxtStatus")

# Script-wide storage for last generated report path
$Script:GeneratedReportPath = ""

# Parameter Config Objects Store for Mode 3
$Script:ParamConfigs = [System.Collections.ArrayList]::new()

# --- Helper Functions ---
function Update-WpfEvents {
	[System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
}

function Write-LogMessage {
	param([string]$Message)
	$timestamp = Get-Date -Format "HH:mm:ss"
	$TxtLog.AppendText("[${timestamp}] ${Message}`r`n")
	$TxtLog.ScrollToEnd()
	Update-WpfEvents
}

# --- Hardware & GPU Discovery ---
function Get-AvailableGpuDevices {
	param([string]$CliPath)
	$devices = [System.Collections.ArrayList]::new()

	# 1. Auto / System Default
	$autoLabel = if ($global:Localization.ContainsKey($global:CurrentLang)) { $global:Localization[$global:CurrentLang]["AutoDevice"] } else { "Auto / System Default" }
	[void]$devices.Add([PSCustomObject]@{
		Id      = "auto"
		Name    = $autoLabel
		Backend = "AUTO"
		Index   = $null
	})

	# 2. Try querying llama-cli.exe --list-devices if a valid build is found
	$targetCli = ""
	if (-not [string]::IsNullOrWhiteSpace($CliPath) -and (Test-Path -Path $CliPath)) {
		$targetCli = $CliPath
	}
	elseif ($LstBuilds -and $LstBuilds.Items.Count -gt 0) {
		$candidate = [string]$LstBuilds.Items[0]
		if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -Path $candidate)) {
			$targetCli = $candidate
		}
	}
	elseif ($TxtSingleCli -and (-not [string]::IsNullOrWhiteSpace($TxtSingleCli.Text))) {
		$singleCandidate = $TxtSingleCli.Text.Trim()
		if (-not [string]::IsNullOrWhiteSpace($singleCandidate) -and (Test-Path -Path $singleCandidate)) {
			$targetCli = $singleCandidate
		}
	}

	if (-not [string]::IsNullOrWhiteSpace($targetCli) -and (Test-Path -Path $targetCli)) {
		try {
			$cliDir = Split-Path -Parent $targetCli
			$psi = New-Object System.Diagnostics.ProcessStartInfo
			$psi.FileName               = $targetCli
			$psi.Arguments              = "--list-devices"
			$psi.WorkingDirectory       = $cliDir
			$psi.UseShellExecute        = $false
			$psi.RedirectStandardOutput = $true
			$psi.RedirectStandardError  = $true
			$psi.CreateNoWindow         = $true

			$extraPaths = @($cliDir)
			$gitMingw64 = "C:\Program Files\Git\mingw64\bin"
			if (Test-Path -Path $gitMingw64) { $extraPaths += $gitMingw64 }
			$existingPath = [Environment]::GetEnvironmentVariable("PATH", "Process")
			$psi.EnvironmentVariables["PATH"] = ($extraPaths + @($existingPath) -join ";")

			$proc = [System.Diagnostics.Process]::Start($psi)
			$stdout = $proc.StandardOutput.ReadToEnd()
			$proc.WaitForExit(3000)

			$lines = $stdout -split "`r?`n"
			foreach ($line in $lines) {
				if ($line -match '^\s*([A-Za-z]+)(\d+):\s*(.+?)(?:\s*\(\d+.*?\))?$') {
					$backend = $Matches[1].ToUpper()
					$idx     = [int]$Matches[2]
					$devName = $Matches[3].Trim()
					[void]$devices.Add([PSCustomObject]@{
						Id      = "$($Matches[1])$($Matches[2])"
						Name    = "$($Matches[1])$($Matches[2]): ${devName}"
						Backend = $backend
						Index   = $idx
					})
				}
			}
		}
		catch { }
	}

	# 3. Fallback to Win32_VideoController if no CLI devices were discovered
	if ($devices.Count -le 1) {
		try {
			$gpus = Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue
			$gIdx = 0
			foreach ($gpu in $gpus) {
				if (-not [string]::IsNullOrWhiteSpace($gpu.Name)) {
					[void]$devices.Add([PSCustomObject]@{
						Id      = "GPU${gIdx}"
						Name    = "GPU ${gIdx}: $($gpu.Name)"
						Backend = "OS"
						Index   = $gIdx
					})
					$gIdx++
				}
			}
		}
		catch { }
	}

	# 4. CPU Only Option
	$cpuLabel = if ($global:Localization.ContainsKey($global:CurrentLang)) { $global:Localization[$global:CurrentLang]["CpuOnlyDevice"] } else { "CPU Only (No GPU Offload)" }
	[void]$devices.Add([PSCustomObject]@{
		Id      = "cpu"
		Name    = $cpuLabel
		Backend = "CPU"
		Index   = $null
	})

	return $devices
}

function Update-GpuDeviceList {
	param([string]$CliPath)
	$prevSelectedTag = ""
	if ($CmbGpuDevice.SelectedItem) {
		$prevSelectedTag = [string]$CmbGpuDevice.SelectedItem.Tag
	}

	$CmbGpuDevice.Items.Clear()
	$deviceList = Get-AvailableGpuDevices -CliPath $CliPath

	$selectedItem = $null
	foreach ($dev in $deviceList) {
		$cbi = New-Object System.Windows.Controls.ComboBoxItem
		$cbi.Tag         = $dev.Id
		$cbi.Content     = $dev.Name
		$cbi.DataContext = $dev
		[void]$CmbGpuDevice.Items.Add($cbi)

		if ($dev.Id -eq $prevSelectedTag) {
			$selectedItem = $cbi
		}
	}

	# Auto-select discrete GPU if available when no prior user selection exists
	if ($null -eq $selectedItem) {
		foreach ($item in $CmbGpuDevice.Items) {
			$devObj = $item.DataContext
			if ($devObj -and ($devObj.Name -match "RX|RTX|GeForce|Radeon RX|Arc|NVIDIA") -and ($devObj.Name -notmatch "Graphics$|Integrated")) {
				$selectedItem = $item
				break
			}
		}
	}
	if ($null -eq $selectedItem -and $CmbGpuDevice.Items.Count -gt 0) {
		$selectedItem = $CmbGpuDevice.Items[0]
	}

	$CmbGpuDevice.SelectedItem = $selectedItem
}

# --- Hardware Performance Profile Management & Universal Affinity ---
function Convert-AffinityMask {
	param([string]$MaskStr)
	if ([string]::IsNullOrWhiteSpace($MaskStr)) {
		return [IntPtr]::Zero
	}
	$trimmed = $MaskStr.Trim()
	try {
		if ($trimmed.StartsWith("0x", [System.StringComparison]::OrdinalIgnoreCase)) {
			$val = [Convert]::ToInt64($trimmed.Substring(2), 16)
		} elseif ($trimmed -match '^[0-9a-fA-F]+$' -and $trimmed -match '[a-fA-F]') {
			$val = [Convert]::ToInt64($trimmed, 16)
		} else {
			$val = [Convert]::ToInt64($trimmed, 10)
		}
		return [IntPtr]$val
	}
	catch {
		Write-Warning "Failed to parse CPU affinity mask '$MaskStr': $($_.Exception.Message)"
		return [IntPtr]::Zero
	}
}

function Get-AvailableProfiles {
	if (Test-Path -Path $profilesPath) {
		try {
			$raw = Get-Content -Path $profilesPath -Raw -Encoding UTF8
			$json = ConvertFrom-Json $raw
			if ($json -is [array]) {
				return [System.Collections.ArrayList]::new([object[]]$json)
			} elseif ($null -ne $json) {
				return [System.Collections.ArrayList]::new([object[]]@($json))
			}
		}
		catch {
			Write-Warning "Could not load profiles from $profilesPath : $($_.Exception.Message)"
		}
	}
	return [System.Collections.ArrayList]::new()
}

function Save-ProfilesToFile {
	param([System.Collections.ArrayList]$ProfilesList)
	try {
		$jsonStr = ConvertTo-Json -InputObject $ProfilesList -Depth 5
		[System.IO.File]::WriteAllText($profilesPath, $jsonStr, [System.Text.Encoding]::UTF8)
		return $true
	}
	catch {
		Write-Warning "Failed to save profiles: $($_.Exception.Message)"
		return $false
	}
}

function Update-ProfilesDropdown {
	param([string]$SelectProfileName = "")
	if (-not $CmbProfiles) { return }
	$CmbProfiles.Items.Clear()

	$profiles = Get-AvailableProfiles
	$selectedIndex = 0
	$idx = 0
	foreach ($p in $profiles) {
		$cbi = New-Object System.Windows.Controls.ComboBoxItem
		$cbi.Content = [string]$p.Name
		$cbi.Tag = $p
		if (-not [string]::IsNullOrWhiteSpace($p.Description)) {
			$cbi.ToolTip = [string]$p.Description
		}
		[void]$CmbProfiles.Items.Add($cbi)
		if ($SelectProfileName -and $p.Name -eq $SelectProfileName) {
			$selectedIndex = $idx
		}
		$idx++
	}

	if ($CmbProfiles.Items.Count -gt 0) {
		$CmbProfiles.SelectedIndex = $selectedIndex
	}
}

function Apply-ProfileObject {
	param([PSCustomObject]$Profile)
	if (-not $Profile) { return }

	if ($null -ne $Profile.Threads -and $TxtThreads)     { $TxtThreads.Text = [string]$Profile.Threads }
	if ($null -ne $Profile.GpuLayers -and $TxtGpuLayers) { $TxtGpuLayers.Text = [string]$Profile.GpuLayers }
	if ($null -ne $Profile.CtxSize -and $TxtCtxSize)     { $TxtCtxSize.Text = [string]$Profile.CtxSize }
	if ($null -ne $Profile.BatchSize -and $TxtBatchSize) { $TxtBatchSize.Text = [string]$Profile.BatchSize }
	if ($null -ne $Profile.UbatchSize -and $TxtUbatchSize){ $TxtUbatchSize.Text = [string]$Profile.UbatchSize }

	if ($Profile.CacheTypeK -and $CmbCacheTypeK) {
		foreach ($item in $CmbCacheTypeK.Items) {
			if ($item.Tag -eq $Profile.CacheTypeK) {
				$CmbCacheTypeK.SelectedItem = $item
				break
			}
		}
	}
	if ($Profile.CacheTypeV -and $CmbCacheTypeV) {
		foreach ($item in $CmbCacheTypeV.Items) {
			if ($item.Tag -eq $Profile.CacheTypeV) {
				$CmbCacheTypeV.SelectedItem = $item
				break
			}
		}
	}

	if ($null -ne $Profile.FlashAttn -and $ChkFlashAttn)     { $ChkFlashAttn.IsChecked = [bool]$Profile.FlashAttn }
	if ($null -ne $Profile.Mlock -and $ChkMlock)             { $ChkMlock.IsChecked = [bool]$Profile.Mlock }
	if ($null -ne $Profile.Mmap -and $ChkMmap)               { $ChkMmap.IsChecked = [bool]$Profile.Mmap }
	if ($null -ne $Profile.CpuAffinity -and $ChkCpuAffinity) { $ChkCpuAffinity.IsChecked = [bool]$Profile.CpuAffinity }
	elseif ($null -ne $Profile.PinCcd0 -and $ChkCpuAffinity) { $ChkCpuAffinity.IsChecked = [bool]$Profile.PinCcd0 }
	if ($Profile.CpuAffinityMask -and $TxtCpuAffinity)       { $TxtCpuAffinity.Text = [string]$Profile.CpuAffinityMask }
	if ($null -ne $Profile.Dflash -and $ChkDflash)           { $ChkDflash.IsChecked = [bool]$Profile.Dflash }
	if ($null -ne $Profile.GdnReplay -and $ChkGdnReplay)     { $ChkGdnReplay.IsChecked = [bool]$Profile.GdnReplay }

	Write-LogMessage (Get-LocalizedText -Key "ProfileApplied" -FormatArgs @($Profile.Name))
}

function Show-ProfileManagerDialog {
	param(
		[PSCustomObject]$PreFillData = $null,
		[string]$SelectProfileName = ""
	)

	if (-not (Test-Path -Path $profileDlgPath)) {
		[System.Windows.MessageBox]::Show("ProfileDialog.xaml not found in:`n$profileDlgPath", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
		return
	}

	try {
		$dlgXmlReader = [System.Xml.XmlReader]::Create($profileDlgPath)
		$dlgWindow    = [System.Windows.Markup.XamlReader]::Load($dlgXmlReader)
		$dlgXmlReader.Close()
	}
	catch {
		[System.Windows.MessageBox]::Show("Failed to load ProfileDialog.xaml:`n$($_.Exception.Message)", "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
		return
	}

	$dlgWindow.Owner = $Window

	# Find Controls in Dialog
	$LblDlgTitle            = $dlgWindow.FindName("LblDlgTitle")
	$LblDlgSubtitle         = $dlgWindow.FindName("LblDlgSubtitle")
	$GrpProfileList         = $dlgWindow.FindName("GrpProfileList")
	$BtnNewProfile          = $dlgWindow.FindName("BtnNewProfile")
	$BtnDuplicateProfile    = $dlgWindow.FindName("BtnDuplicateProfile")
	$BtnDeleteProfile       = $dlgWindow.FindName("BtnDeleteProfile")
	$LstProfiles            = $dlgWindow.FindName("LstProfiles")

	$GrpProfIdentity        = $dlgWindow.FindName("GrpProfIdentity")
	$LblProfName            = $dlgWindow.FindName("LblProfName")
	$TxtProfName            = $dlgWindow.FindName("TxtProfName")
	$LblProfDesc            = $dlgWindow.FindName("LblProfDesc")
	$TxtProfDesc            = $dlgWindow.FindName("TxtProfDesc")

	$GrpProfCore            = $dlgWindow.FindName("GrpProfCore")
	$LblProfThreads         = $dlgWindow.FindName("LblProfThreads")
	$TxtProfThreads         = $dlgWindow.FindName("TxtProfThreads")
	$LblProfGpuLayers       = $dlgWindow.FindName("LblProfGpuLayers")
	$TxtProfGpuLayers       = $dlgWindow.FindName("TxtProfGpuLayers")
	$LblProfCtxSize         = $dlgWindow.FindName("LblProfCtxSize")
	$TxtProfCtxSize         = $dlgWindow.FindName("TxtProfCtxSize")

	$GrpProfBatch           = $dlgWindow.FindName("GrpProfBatch")
	$LblProfBatch           = $dlgWindow.FindName("LblProfBatch")
	$TxtProfBatch           = $dlgWindow.FindName("TxtProfBatch")
	$LblProfUbatch          = $dlgWindow.FindName("LblProfUbatch")
	$TxtProfUbatch          = $dlgWindow.FindName("TxtProfUbatch")
	$LblProfCacheK          = $dlgWindow.FindName("LblProfCacheK")
	$CmbProfCacheK          = $dlgWindow.FindName("CmbProfCacheK")
	$LblProfCacheV          = $dlgWindow.FindName("LblProfCacheV")
	$CmbProfCacheV          = $dlgWindow.FindName("CmbProfCacheV")

	$GrpProfFlags           = $dlgWindow.FindName("GrpProfFlags")
	$ChkProfFlashAttn       = $dlgWindow.FindName("ChkProfFlashAttn")
	$ChkProfMlock           = $dlgWindow.FindName("ChkProfMlock")
	$ChkProfMmap            = $dlgWindow.FindName("ChkProfMmap")
	$ChkProfAffinity        = $dlgWindow.FindName("ChkProfAffinity")
	$TxtProfAffinityMask    = $dlgWindow.FindName("TxtProfAffinityMask")
	$LblProfAffinityHint    = $dlgWindow.FindName("LblProfAffinityHint")
	$ChkProfDflash          = $dlgWindow.FindName("ChkProfDflash")
	$ChkProfGdnReplay       = $dlgWindow.FindName("ChkProfGdnReplay")

	$TxtDlgStatus           = $dlgWindow.FindName("TxtDlgStatus")
	$BtnSaveProfileChanges  = $dlgWindow.FindName("BtnSaveProfileChanges")
	$BtnApplyAndClose       = $dlgWindow.FindName("BtnApplyAndClose")
	$BtnCloseDialog         = $dlgWindow.FindName("BtnCloseDialog")

	# Localize Dialog
	$dict = if ($global:Localization.ContainsKey($global:CurrentLang)) { $global:Localization[$global:CurrentLang] } else { @{} }
	if ($dict.Count -gt 0) {
		if ($LblDlgTitle -and $dict.ContainsKey("DlgTitle"))                 { $LblDlgTitle.Text = $dict["DlgTitle"] }
		if ($LblDlgSubtitle -and $dict.ContainsKey("DlgSubtitle"))           { $LblDlgSubtitle.Text = $dict["DlgSubtitle"] }
		if ($GrpProfileList -and $dict.ContainsKey("GrpProfileList"))         { $GrpProfileList.Header = $dict["GrpProfileList"] }
		if ($BtnNewProfile -and $dict.ContainsKey("BtnNewProfile"))           { $BtnNewProfile.Content = $dict["BtnNewProfile"] }
		if ($BtnDuplicateProfile -and $dict.ContainsKey("BtnDuplicateProfile")) { $BtnDuplicateProfile.Content = $dict["BtnDuplicateProfile"] }
		if ($BtnDeleteProfile -and $dict.ContainsKey("BtnDeleteProfile"))     { $BtnDeleteProfile.Content = $dict["BtnDeleteProfile"] }
		if ($GrpProfIdentity -and $dict.ContainsKey("GrpProfIdentity"))       { $GrpProfIdentity.Header = $dict["GrpProfIdentity"] }
		if ($LblProfName -and $dict.ContainsKey("LblProfName"))               { $LblProfName.Text = $dict["LblProfName"] }
		if ($LblProfDesc -and $dict.ContainsKey("LblProfDesc"))               { $LblProfDesc.Text = $dict["LblProfDesc"] }
		if ($GrpProfCore -and $dict.ContainsKey("GrpProfCore"))               { $GrpProfCore.Header = $dict["GrpProfCore"] }
		if ($LblProfThreads -and $dict.ContainsKey("Threads"))               { $LblProfThreads.Text = $dict["Threads"] }
		if ($LblProfGpuLayers -and $dict.ContainsKey("GpuLayers"))           { $LblProfGpuLayers.Text = $dict["GpuLayers"] }
		if ($LblProfCtxSize -and $dict.ContainsKey("CtxSize"))               { $LblProfCtxSize.Text = $dict["CtxSize"] }
		if ($GrpProfBatch -and $dict.ContainsKey("GrpProfBatch"))             { $GrpProfBatch.Header = $dict["GrpProfBatch"] }
		if ($LblProfBatch -and $dict.ContainsKey("BatchSize"))               { $LblProfBatch.Text = $dict["BatchSize"] }
		if ($LblProfUbatch -and $dict.ContainsKey("UbatchSize"))             { $LblProfUbatch.Text = $dict["UbatchSize"] }
		if ($LblProfCacheK -and $dict.ContainsKey("CacheTypeK"))             { $LblProfCacheK.Text = $dict["CacheTypeK"] }
		if ($LblProfCacheV -and $dict.ContainsKey("CacheTypeV"))             { $LblProfCacheV.Text = $dict["CacheTypeV"] }
		if ($GrpProfFlags -and $dict.ContainsKey("GrpProfFlags"))             { $GrpProfFlags.Header = $dict["GrpProfFlags"] }
		if ($ChkProfFlashAttn -and $dict.ContainsKey("FlashAttention"))       { $ChkProfFlashAttn.Content = $dict["FlashAttention"] }
		if ($ChkProfMlock -and $dict.ContainsKey("MemoryLock"))               { $ChkProfMlock.Content = $dict["MemoryLock"] }
		if ($ChkProfMmap -and $dict.ContainsKey("MemoryMap"))                 { $ChkProfMmap.Content = $dict["MemoryMap"] }
		if ($ChkProfAffinity -and $dict.ContainsKey("CpuAffinity"))           { $ChkProfAffinity.Content = $dict["CpuAffinity"] }
		if ($LblProfAffinityHint -and $dict.ContainsKey("AffinityHint"))     { $LblProfAffinityHint.Text = $dict["AffinityHint"] }
		if ($ChkProfDflash -and $dict.ContainsKey("DFlashSpec"))             { $ChkProfDflash.Content = $dict["DFlashSpec"] }
		if ($ChkProfGdnReplay -and $dict.ContainsKey("GdnReplayMtp"))         { $ChkProfGdnReplay.Content = $dict["GdnReplayMtp"] }
		if ($BtnSaveProfileChanges -and $dict.ContainsKey("BtnSaveProfileChanges")) { $BtnSaveProfileChanges.Content = $dict["BtnSaveProfileChanges"] }
		if ($BtnApplyAndClose -and $dict.ContainsKey("BtnApplyAndClose"))     { $BtnApplyAndClose.Content = $dict["BtnApplyAndClose"] }
		if ($BtnCloseDialog -and $dict.ContainsKey("BtnCloseDialog"))         { $BtnCloseDialog.Content = $dict["BtnCloseDialog"] }
	}

	$localProfiles = Get-AvailableProfiles

	$fnPopulateForm = {
		param([PSCustomObject]$p)
		if (-not $p) { return }
		$TxtProfName.Text         = [string]$p.Name
		$TxtProfDesc.Text         = [string]$p.Description
		$TxtProfThreads.Text      = if ($null -ne $p.Threads) { [string]$p.Threads } else { "8" }
		$TxtProfGpuLayers.Text    = if ($null -ne $p.GpuLayers) { [string]$p.GpuLayers } else { "99" }
		$TxtProfCtxSize.Text      = if ($null -ne $p.CtxSize) { [string]$p.CtxSize } else { "8192" }
		$TxtProfBatch.Text        = if ($null -ne $p.BatchSize) { [string]$p.BatchSize } else { "2048" }
		$TxtProfUbatch.Text       = if ($null -ne $p.UbatchSize) { [string]$p.UbatchSize } else { "512" }

		if ($p.CacheTypeK -and $CmbProfCacheK) {
			foreach ($item in $CmbProfCacheK.Items) {
				if ($item.Tag -eq $p.CacheTypeK) { $CmbProfCacheK.SelectedItem = $item; break }
			}
		}
		if ($p.CacheTypeV -and $CmbProfCacheV) {
			foreach ($item in $CmbProfCacheV.Items) {
				if ($item.Tag -eq $p.CacheTypeV) { $CmbProfCacheV.SelectedItem = $item; break }
			}
		}

		$ChkProfFlashAttn.IsChecked = if ($null -ne $p.FlashAttn) { [bool]$p.FlashAttn } else { $true }
		$ChkProfMlock.IsChecked     = if ($null -ne $p.Mlock) { [bool]$p.Mlock } else { $true }
		$ChkProfMmap.IsChecked      = if ($null -ne $p.Mmap) { [bool]$p.Mmap } else { $true }
		$ChkProfAffinity.IsChecked  = if ($null -ne $p.CpuAffinity) { [bool]$p.CpuAffinity } elseif ($null -ne $p.PinCcd0) { [bool]$p.PinCcd0 } else { $false }
		$TxtProfAffinityMask.Text   = if (-not [string]::IsNullOrWhiteSpace($p.CpuAffinityMask)) { [string]$p.CpuAffinityMask } else { "0xFF" }
		$ChkProfDflash.IsChecked    = if ($null -ne $p.Dflash) { [bool]$p.Dflash } else { $false }
		$ChkProfGdnReplay.IsChecked = if ($null -ne $p.GdnReplay) { [bool]$p.GdnReplay } else { $false }
	}

	$fnReadForm = {
		$threads = 8;    [int]::TryParse($TxtProfThreads.Text, [ref]$threads) | Out-Null
		$gpu = 99;        [int]::TryParse($TxtProfGpuLayers.Text, [ref]$gpu) | Out-Null
		$ctx = 8192;      [int]::TryParse($TxtProfCtxSize.Text, [ref]$ctx) | Out-Null
		$batch = 2048;    [int]::TryParse($TxtProfBatch.Text, [ref]$batch) | Out-Null
		$ubatch = 512;    [int]::TryParse($TxtProfUbatch.Text, [ref]$ubatch) | Out-Null
		$ctk = if ($CmbProfCacheK.SelectedItem) { [string]$CmbProfCacheK.SelectedItem.Tag } else { "f16" }
		$ctv = if ($CmbProfCacheV.SelectedItem) { [string]$CmbProfCacheV.SelectedItem.Tag } else { "f16" }
		$name = $TxtProfName.Text.Trim()
		if ([string]::IsNullOrWhiteSpace($name)) { $name = "Custom Profile" }

		return [PSCustomObject]@{
			Name            = $name
			Description     = $TxtProfDesc.Text.Trim()
			Threads         = $threads
			GpuLayers       = $gpu
			CtxSize         = $ctx
			BatchSize       = $batch
			UbatchSize      = $ubatch
			CacheTypeK      = $ctk
			CacheTypeV      = $ctv
			FlashAttn       = [bool]$ChkProfFlashAttn.IsChecked
			Mlock           = [bool]$ChkProfMlock.IsChecked
			Mmap            = [bool]$ChkProfMmap.IsChecked
			CpuAffinity     = [bool]$ChkProfAffinity.IsChecked
			CpuAffinityMask = $TxtProfAffinityMask.Text.Trim()
			Dflash          = [bool]$ChkProfDflash.IsChecked
			GdnReplay       = [bool]$ChkProfGdnReplay.IsChecked
		}
	}

	$script:isInternalSelect = $false
	$fnRefreshList = {
		param([string]$targetName = "")
		$script:isInternalSelect = $true
		$LstProfiles.ItemsSource = $null
		$LstProfiles.ItemsSource = $localProfiles
		$selIdx = 0
		if ($targetName) {
			for ($i = 0; $i -lt $localProfiles.Count; $i++) {
				if ($localProfiles[$i].Name -eq $targetName) { $selIdx = $i; break }
			}
		}
		if ($localProfiles.Count -gt 0) {
			$LstProfiles.SelectedIndex = $selIdx
			& $fnPopulateForm $localProfiles[$selIdx]
		}
		$script:isInternalSelect = $false
	}

	if ($PreFillData) {
		[void]$localProfiles.Add($PreFillData)
		& $fnRefreshList $PreFillData.Name
	} else {
		$initTarget = if ($SelectProfileName) { $SelectProfileName } elseif ($CmbProfiles.SelectedItem) { [string]$CmbProfiles.SelectedItem.Content } else { "" }
		& $fnRefreshList $initTarget
	}

	$LstProfiles.Add_SelectionChanged({
		if ($script:isInternalSelect) { return }
		if ($LstProfiles.SelectedItem) {
			& $fnPopulateForm $LstProfiles.SelectedItem
		}
	})

	$BtnNewProfile.Add_Click({
		$newP = [PSCustomObject]@{
			Name            = "New Profile $($localProfiles.Count + 1)"
			Description     = "Custom hardware configuration"
			Threads         = 8
			GpuLayers       = 99
			CtxSize         = 8192
			BatchSize       = 2048
			UbatchSize      = 512
			CacheTypeK      = "f16"
			CacheTypeV      = "f16"
			FlashAttn       = $true
			Mlock           = $true
			Mmap            = $true
			CpuAffinity     = $false
			CpuAffinityMask = "0xFF"
			Dflash          = $false
			GdnReplay       = $false
		}
		[void]$localProfiles.Add($newP)
		& $fnRefreshList $newP.Name
		$TxtProfName.Focus()
	})

	$BtnDuplicateProfile.Add_Click({
		if (-not $LstProfiles.SelectedItem) { return }
		$current = & $fnReadForm
		$copyP = [PSCustomObject]@{
			Name            = "$($current.Name) (Copy)"
			Description     = $current.Description
			Threads         = $current.Threads
			GpuLayers       = $current.GpuLayers
			CtxSize         = $current.CtxSize
			BatchSize       = $current.BatchSize
			UbatchSize      = $current.UbatchSize
			CacheTypeK      = $current.CacheTypeK
			CacheTypeV      = $current.CacheTypeV
			FlashAttn       = $current.FlashAttn
			Mlock           = $current.Mlock
			Mmap            = $current.Mmap
			CpuAffinity     = $current.CpuAffinity
			CpuAffinityMask = $current.CpuAffinityMask
			Dflash          = $current.Dflash
			GdnReplay       = $current.GdnReplay
		}
		[void]$localProfiles.Add($copyP)
		& $fnRefreshList $copyP.Name
	})

	$BtnDeleteProfile.Add_Click({
		if (-not $LstProfiles.SelectedItem) { return }
		$idx = $LstProfiles.SelectedIndex
		if ($idx -ge 0 -and $idx -lt $localProfiles.Count) {
			$delName = $localProfiles[$idx].Name
			$localProfiles.RemoveAt($idx)
			Save-ProfilesToFile -ProfilesList $localProfiles | Out-Null
			& $fnRefreshList
			$TxtDlgStatus.Text = Get-LocalizedText -Key "ProfileDeleted" -FormatArgs @($delName)
		}
	})

	$fnSaveCurrent = {
		$updated = & $fnReadForm
		$found = $false
		for ($i = 0; $i -lt $localProfiles.Count; $i++) {
			if ($localProfiles[$i].Name -eq $updated.Name) {
				$localProfiles[$i] = $updated
				$found = $true
				break
			}
		}
		if (-not $found) {
			$currSel = $LstProfiles.SelectedIndex
			if ($currSel -ge 0 -and $currSel -lt $localProfiles.Count) {
				$localProfiles[$currSel] = $updated
			} else {
				[void]$localProfiles.Add($updated)
			}
		}
		Save-ProfilesToFile -ProfilesList $localProfiles | Out-Null
		& $fnRefreshList $updated.Name
		$TxtDlgStatus.Text = "Saved '$($updated.Name)' successfully."
		return $updated
	}

	$BtnSaveProfileChanges.Add_Click({
		$null = & $fnSaveCurrent
	})

	$BtnApplyAndClose.Add_Click({
		$saved = & $fnSaveCurrent
		Update-ProfilesDropdown -SelectProfileName $saved.Name
		Apply-ProfileObject -Profile $saved
		$dlgWindow.Close()
	})

	$BtnCloseDialog.Add_Click({
		Update-ProfilesDropdown
		$dlgWindow.Close()
	})

	$dlgWindow.ShowDialog() | Out-Null
	Update-ProfilesDropdown
}

# --- Dynamic Mode Switching ---
function Update-ModeVisibility {
	$selectedTag = "builds"
	if ($CmbBenchmarkMode.SelectedItem) {
		$selectedTag = [string]$CmbBenchmarkMode.SelectedItem.Tag
	}

	switch ($selectedTag) {
		"builds" {
			# Compare Builds: 1 Model, Base Params, N Builds
			$LblSingleCli.Visibility       = [System.Windows.Visibility]::Collapsed
			$TxtSingleCli.Visibility       = [System.Windows.Visibility]::Collapsed
			$BtnBrowseSingleCli.Visibility = [System.Windows.Visibility]::Collapsed

			$LblModelPath.Visibility       = [System.Windows.Visibility]::Visible
			$TxtModelPath.Visibility       = [System.Windows.Visibility]::Visible
			$BtnBrowseModel.Visibility     = [System.Windows.Visibility]::Visible

			$GridBaseParams.Visibility     = [System.Windows.Visibility]::Visible

			$GrpBuilds.Visibility          = [System.Windows.Visibility]::Visible
			$GrpModels.Visibility          = [System.Windows.Visibility]::Collapsed
			$GrpParams.Visibility          = [System.Windows.Visibility]::Collapsed
		}
		"models" {
			# Compare Models: 1 Build, Base Params, N Models
			$LblSingleCli.Visibility       = [System.Windows.Visibility]::Visible
			$TxtSingleCli.Visibility       = [System.Windows.Visibility]::Visible
			$BtnBrowseSingleCli.Visibility = [System.Windows.Visibility]::Visible

			$LblModelPath.Visibility       = [System.Windows.Visibility]::Collapsed
			$TxtModelPath.Visibility       = [System.Windows.Visibility]::Collapsed
			$BtnBrowseModel.Visibility     = [System.Windows.Visibility]::Collapsed

			$GridBaseParams.Visibility     = [System.Windows.Visibility]::Visible

			$GrpBuilds.Visibility          = [System.Windows.Visibility]::Collapsed
			$GrpModels.Visibility          = [System.Windows.Visibility]::Visible
			$GrpParams.Visibility          = [System.Windows.Visibility]::Collapsed
		}
		"params" {
			# Parameter Sweep: 1 Build, 1 Model, N Param Configs
			$LblSingleCli.Visibility       = [System.Windows.Visibility]::Visible
			$TxtSingleCli.Visibility       = [System.Windows.Visibility]::Visible
			$BtnBrowseSingleCli.Visibility = [System.Windows.Visibility]::Visible

			$LblModelPath.Visibility       = [System.Windows.Visibility]::Visible
			$TxtModelPath.Visibility       = [System.Windows.Visibility]::Visible
			$BtnBrowseModel.Visibility     = [System.Windows.Visibility]::Visible

			$GridBaseParams.Visibility     = [System.Windows.Visibility]::Collapsed

			$GrpBuilds.Visibility          = [System.Windows.Visibility]::Collapsed
			$GrpModels.Visibility          = [System.Windows.Visibility]::Collapsed
			$GrpParams.Visibility          = [System.Windows.Visibility]::Visible
		}
	}
}

$CmbBenchmarkMode.Add_SelectionChanged({
	Update-ModeVisibility
})

# --- Interface Language System ---
function Set-InterfaceLanguage {
	param([string]$LangKey)
	if (-not $global:Localization.ContainsKey($LangKey)) { return }
	$global:CurrentLang = $LangKey
	$dict = $global:Localization[$LangKey]

	$Window.Title              = $dict["Title"]
	if ($LblAppTitle)        { $LblAppTitle.Text = $dict["Title"] }
	$LblBenchmarkMode.Text     = $dict["BenchmarkMode"]
	$LblLanguage.Text          = $dict["Language"]
	$GrpSetup.Header           = $dict["SetupGroup"]
	$LblSingleCli.Text         = $dict["SingleCliPath"]
	$LblModelPath.Text         = $dict["ModelPath"]
	$BtnBrowseModel.Content    = $dict["Browse"]
	$BtnBrowseSingleCli.Content= $dict["Browse"]
	$LblThreads.Text           = $dict["Threads"]
	$LblGpuLayers.Text         = $dict["GpuLayers"]
	$LblCtxSize.Text           = $dict["CtxSize"]
	if ($LblGpuDevice)         { $LblGpuDevice.Text = $dict["GpuDevice"] }
	if ($BtnRefreshGpu)        { $BtnRefreshGpu.Content = $dict["RefreshGpu"] }
	if ($LblRepetitions)       { $LblRepetitions.Text = $dict["Repetitions"] }
	if ($CmbGpuDevice) {
		foreach ($item in $CmbGpuDevice.Items) {
			if ($item.Tag -eq "auto") { $item.Content = $dict["AutoDevice"] }
			elseif ($item.Tag -eq "cpu") { $item.Content = $dict["CpuOnlyDevice"] }
		}
	}
	$LblChatTemplate.Text      = $dict["ChatTemplate"]
	$BtnBrowseTemplate.Content = $dict["Browse"]
	if ($BtnBenchmarkTemplate){ $BtnBenchmarkTemplate.Content = $dict["UseBenchmarkJinja"] }

	# Profiles Bar
	if ($LblProfiles)          { $LblProfiles.Text = $dict["ProfilesLabel"] }
	if ($BtnApplyProfile)      { $BtnApplyProfile.Content = $dict["ApplyProfile"] }
	if ($BtnManageProfiles)    { $BtnManageProfiles.Content = $dict["ManageProfiles"] }
	if ($BtnSaveCurrentProfile){ $BtnSaveCurrentProfile.Content = $dict["SaveProfile"] }

	# Advanced Performance Tuning
	if ($ExpAdvancedParams)    { $ExpAdvancedParams.Header = $dict["AdvParamsExpander"] }
	if ($LblBatchSize)         { $LblBatchSize.Text = $dict["BatchSize"] }
	if ($LblUbatchSize)        { $LblUbatchSize.Text = $dict["UbatchSize"] }
	if ($LblCacheTypeK)        { $LblCacheTypeK.Text = $dict["CacheTypeK"] }
	if ($LblCacheTypeV)        { $LblCacheTypeV.Text = $dict["CacheTypeV"] }
	if ($ChkFlashAttn)         { $ChkFlashAttn.Content = $dict["FlashAttention"] }
	if ($ChkMlock)             { $ChkMlock.Content = $dict["MemoryLock"] }
	if ($ChkMmap)              { $ChkMmap.Content = $dict["MemoryMap"] }
	if ($ChkCpuAffinity)       { $ChkCpuAffinity.Content = $dict["CpuAffinity"] }
	if ($ChkDflash)            { $ChkDflash.Content = $dict["DFlashSpec"] }
	if ($ChkGdnReplay)         { $ChkGdnReplay.Content = $dict["GdnReplayMtp"] }

	# Mode items text
	if ($CmbBenchmarkMode.Items.Count -ge 3) {
		$CmbBenchmarkMode.Items[0].Content = $dict["ModeBuilds"]
		$CmbBenchmarkMode.Items[1].Content = $dict["ModeModels"]
		$CmbBenchmarkMode.Items[2].Content = $dict["ModeParams"]
	}

	# Mode Panels
	$GrpBuilds.Header          = $dict["BuildsGroup"]
	$BtnAddBuild.Content       = $dict["AddBuild"]
	$BtnRemoveBuild.Content    = $dict["RemoveBuild"]
	$BtnClearBuilds.Content    = $dict["ClearBuilds"]

	$GrpModels.Header          = $dict["ModelsGroup"]
	$BtnAddModels.Content      = $dict["AddModels"]
	$BtnRemoveModel.Content    = $dict["RemoveModel"]
	$BtnClearModels.Content    = $dict["ClearModels"]

	$GrpParams.Header          = $dict["ParamsGroup"]
	$BtnAddCustomParam.Content = $dict["AddParam"]
	$LblQuickSweep.Text        = $dict["QuickSweep"]
	$BtnApplyQuickSweep.Content= $dict["AddSweep"]
	if ($CmbQuickSweep.Items.Count -ge 6) {
		$CmbQuickSweep.Items[0].Content = $dict["SweepThreads"]
		$CmbQuickSweep.Items[1].Content = $dict["SweepGpu"]
		$CmbQuickSweep.Items[2].Content = $dict["SweepContext"]
		$CmbQuickSweep.Items[3].Content = $dict["SweepKvCache"]
		$CmbQuickSweep.Items[4].Content = $dict["SweepFlashAttn"]
		$CmbQuickSweep.Items[5].Content = $dict["SweepBatch"]
	}
	$BtnRemoveParam.Content    = $dict["RemoveParam"]
	$BtnClearParams.Content    = $dict["ClearParams"]

	# Scenarios
	$GrpSuite.Header           = $dict["SuiteGroup"]
	if ($ChkWarmup)            { $ChkWarmup.Content = $dict["WarmupOption"] }
	$ChkScenShort.Content      = $dict["ScenShort"]
	$ChkScenReason.Content     = $dict["ScenReason"]
	$ChkScenPrefill.Content    = $dict["ScenPrefill"]
	if ($ChkScenStress)        { $ChkScenStress.Content = $dict["ScenStress"] }
	$bullet = "$([char]0x2022) "
	if ($LblScenEvalHeader)    { $LblScenEvalHeader.Text = $dict["ScenariosEvaluate"] }
	if ($LblScenPromptSpeed)   { $LblScenPromptSpeed.Text = $bullet + $dict["ScenPromptSpeed"] }
	if ($LblScenGenSpeed)      { $LblScenGenSpeed.Text = $bullet + $dict["ScenGenSpeed"] }
	if ($LblScenLoadTime)      { $LblScenLoadTime.Text = $bullet + $dict["ScenLoadTime"] }

	$BtnRun.Content            = $dict["RunBtn"]
	$BtnReport.Content         = $dict["ReportBtn"]
	$GrpLog.Header             = $dict["LogHeader"]
	$TxtStatus.Text            = $dict["StatusReady"]
}

# Populate Language ComboBox
$CmbLanguage.Items.Clear()
foreach ($code in ($global:Localization.Keys | Sort-Object)) {
	$cbi = New-Object System.Windows.Controls.ComboBoxItem
	$cbi.Tag = $code
	$cbi.Content = if ($code -eq "de") { "Deutsch" } elseif ($code -eq "en") { "English" } else { $code.ToUpper() }
	[void]$CmbLanguage.Items.Add($cbi)
	if ($code -eq $global:CurrentLang) {
		$CmbLanguage.SelectedItem = $cbi
	}
}

$CmbLanguage.Add_SelectionChanged({
	$item = $CmbLanguage.SelectedItem
	if ($null -ne $item) {
		Set-InterfaceLanguage -LangKey ([string]$item.Tag)
	}
})

# --- UI Event Handlers ---
$BtnRefreshGpu.Add_Click({
	$cliToUse = ""
	if ($TxtSingleCli -and (-not [string]::IsNullOrWhiteSpace($TxtSingleCli.Text))) {
		$singleCandidate = $TxtSingleCli.Text.Trim()
		if (-not [string]::IsNullOrWhiteSpace($singleCandidate) -and (Test-Path -Path $singleCandidate)) {
			$cliToUse = $singleCandidate
		}
	}
	if ([string]::IsNullOrWhiteSpace($cliToUse) -and $LstBuilds -and $LstBuilds.Items.Count -gt 0) {
		$candidate = [string]$LstBuilds.Items[0]
		if (-not [string]::IsNullOrWhiteSpace($candidate) -and (Test-Path -Path $candidate)) {
			$cliToUse = $candidate
		}
	}
	Update-GpuDeviceList -CliPath $cliToUse
	Write-LogMessage "GPU accelerators refreshed."
})

$BtnBrowseSingleCli.Add_Click({
	$dlg = New-Object System.Windows.Forms.OpenFileDialog
	$dlg.Title = Get-LocalizedText -Key "DialogSelectBuildTitle"
	$dlg.Filter = "Executables (*.exe)|*.exe|All Files (*.*)|*.*"
	if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
		$TxtSingleCli.Text = $dlg.FileName
		Update-GpuDeviceList -CliPath $dlg.FileName
	}
})

$BtnBrowseModel.Add_Click({
	$dlg = New-Object System.Windows.Forms.OpenFileDialog
	$dlg.Title = Get-LocalizedText -Key "DialogSelectModelTitle"
	$dlg.Filter = "GGUF Model Files (*.gguf)|*.gguf|All Files (*.*)|*.*"
	if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
		$TxtModelPath.Text = $dlg.FileName
	}
})

$BtnBrowseTemplate.Add_Click({
	$dlg = New-Object System.Windows.Forms.OpenFileDialog
	$dlg.Title = Get-LocalizedText -Key "DialogSelectTemplateTitle"
	$dlg.Filter = "Jinja Template Files (*.jinja;*.jinja2)|*.jinja;*.jinja2|All Files (*.*)|*.*"
	if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
		$TxtChatTemplate.Text = $dlg.FileName
	}
})

$BtnBenchmarkTemplate.Add_Click({
	if (Test-Path -Path $jinjaPath) {
		$TxtChatTemplate.Text = $jinjaPath
		Write-LogMessage "Loaded bundled benchmark chat template: $jinjaPath"
	}
})

# Builds List Events
$BtnAddBuild.Add_Click({
	$dlg = New-Object System.Windows.Forms.OpenFileDialog
	$dlg.Title = Get-LocalizedText -Key "DialogSelectBuildTitle"
	$dlg.Filter = "Executables (*.exe)|*.exe|All Files (*.*)|*.*"
	$dlg.Multiselect = $true
	if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
		foreach ($file in $dlg.FileNames) {
			if (-not $LstBuilds.Items.Contains($file)) {
				[void]$LstBuilds.Items.Add($file)
			}
		}
		if ($LstBuilds.Items.Count -gt 0) {
			Update-GpuDeviceList -CliPath ([string]$LstBuilds.Items[0])
		}
	}
})

$BtnRemoveBuild.Add_Click({
	$selected = @($LstBuilds.SelectedItems)
	foreach ($item in $selected) {
		$LstBuilds.Items.Remove($item)
	}
})

$BtnClearBuilds.Add_Click({
	$LstBuilds.Items.Clear()
})

# Models List Events
$BtnAddModels.Add_Click({
	$dlg = New-Object System.Windows.Forms.OpenFileDialog
	$dlg.Title = Get-LocalizedText -Key "DialogSelectModelTitle"
	$dlg.Filter = "GGUF Model Files (*.gguf)|*.gguf|All Files (*.*)|*.*"
	$dlg.Multiselect = $true
	if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
		foreach ($file in $dlg.FileNames) {
			if (-not $LstModels.Items.Contains($file)) {
				[void]$LstModels.Items.Add($file)
			}
		}
	}
})

$BtnRemoveModel.Add_Click({
	$selected = @($LstModels.SelectedItems)
	foreach ($item in $selected) {
		$LstModels.Items.Remove($item)
	}
})

$BtnClearModels.Add_Click({
	$LstModels.Items.Clear()
})

# --- Profile Button Handlers ---
$BtnApplyProfile.Add_Click({
	if ($CmbProfiles.SelectedItem -and $CmbProfiles.SelectedItem.Tag) {
		Apply-ProfileObject -Profile $CmbProfiles.SelectedItem.Tag
	}
})

$BtnManageProfiles.Add_Click({
	$curName = if ($CmbProfiles.SelectedItem) { [string]$CmbProfiles.SelectedItem.Content } else { "" }
	Show-ProfileManagerDialog -SelectProfileName $curName
})

$BtnSaveCurrentProfile.Add_Click({
	$threads = 8;    [int]::TryParse($TxtThreads.Text, [ref]$threads) | Out-Null
	$gpu = 99;        [int]::TryParse($TxtGpuLayers.Text, [ref]$gpu) | Out-Null
	$ctx = 8192;      [int]::TryParse($TxtCtxSize.Text, [ref]$ctx) | Out-Null
	$batch = 2048;    [int]::TryParse($TxtBatchSize.Text, [ref]$batch) | Out-Null
	$ubatch = 512;    [int]::TryParse($TxtUbatchSize.Text, [ref]$ubatch) | Out-Null
	$ctk = if ($CmbCacheTypeK.SelectedItem) { [string]$CmbCacheTypeK.SelectedItem.Tag } else { "f16" }
	$ctv = if ($CmbCacheTypeV.SelectedItem) { [string]$CmbCacheTypeV.SelectedItem.Tag } else { "f16" }
	$affMask = if ($TxtCpuAffinity) { $TxtCpuAffinity.Text.Trim() } else { "0xFF" }

	$currentData = [PSCustomObject]@{
		Name            = "Custom Profile $(Get-Date -Format 'HH:mm')"
		Description     = "Profile created from current settings on $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
		Threads         = $threads
		GpuLayers       = $gpu
		CtxSize         = $ctx
		BatchSize       = $batch
		UbatchSize      = $ubatch
		CacheTypeK      = $ctk
		CacheTypeV      = $ctv
		FlashAttn       = [bool]$ChkFlashAttn.IsChecked
		Mlock           = [bool]$ChkMlock.IsChecked
		Mmap            = [bool]$ChkMmap.IsChecked
		CpuAffinity     = [bool]$ChkCpuAffinity.IsChecked
		CpuAffinityMask = $affMask
		Dflash          = [bool]$ChkDflash.IsChecked
		GdnReplay       = [bool]$ChkGdnReplay.IsChecked
	}
	Show-ProfileManagerDialog -PreFillData $currentData
})

# Parameter Sweep Events
function Add-ParamConfigItem {
	param(
		[string]$Name,
		[int]$Threads = 8,
		[int]$Gpu = 99,
		[int]$Ctx = 4096,
		[int]$Batch = 2048,
		[int]$Ubatch = 512,
		[string]$CacheK = "f16",
		[string]$CacheV = "f16",
		[bool]$FlashAttn = $true,
		[bool]$Mlock = $true,
		[bool]$Mmap = $true,
		[bool]$CpuAffinity = $false,
		[string]$CpuAffinityMask = "0xFF",
		[bool]$Dflash = $false,
		[bool]$GdnReplay = $false
	)
	$cfgObj = [PSCustomObject]@{
		Name            = $Name
		Threads         = $Threads
		GpuLayers       = $Gpu
		CtxSize         = $Ctx
		BatchSize       = $Batch
		UbatchSize      = $Ubatch
		CacheTypeK      = $CacheK
		CacheTypeV      = $CacheV
		FlashAttn       = $FlashAttn
		Mlock           = $Mlock
		Mmap            = $Mmap
		CpuAffinity     = $CpuAffinity
		CpuAffinityMask = $CpuAffinityMask
		Dflash          = $Dflash
		GdnReplay       = $GdnReplay
		DisplayText     = "${Name} (${Threads}T | ${Gpu}NGL | Ctx:${Ctx} | K:${CacheK} V:${CacheV} | FA:${FlashAttn})"
	}
	[void]$Script:ParamConfigs.Add($cfgObj)
	[void]$LstParams.Items.Add($cfgObj.DisplayText)
}

$BtnAddCustomParam.Add_Click({
	$name = $TxtNewParamName.Text.Trim()
	$threads = 8;    [int]::TryParse($TxtNewParamThreads.Text, [ref]$threads) | Out-Null
	$gpu = 99;        [int]::TryParse($TxtNewParamGpu.Text, [ref]$gpu) | Out-Null
	$ctx = 4096;      [int]::TryParse($TxtNewParamCtx.Text, [ref]$ctx) | Out-Null
	$batch = 2048;    [int]::TryParse($TxtBatchSize.Text, [ref]$batch) | Out-Null
	$ubatch = 512;    [int]::TryParse($TxtUbatchSize.Text, [ref]$ubatch) | Out-Null
	$ctk = if ($CmbCacheTypeK.SelectedItem) { [string]$CmbCacheTypeK.SelectedItem.Tag } else { "f16" }
	$ctv = if ($CmbCacheTypeV.SelectedItem) { [string]$CmbCacheTypeV.SelectedItem.Tag } else { "f16" }
	$affMask = if ($TxtCpuAffinity) { $TxtCpuAffinity.Text.Trim() } else { "0xFF" }

	if ([string]::IsNullOrWhiteSpace($name)) {
		$name = "Config-${threads}T-${gpu}NGL-${ctk}"
	}

	Add-ParamConfigItem `
		-Name $name `
		-Threads $threads `
		-Gpu $gpu `
		-Ctx $ctx `
		-Batch $batch `
		-Ubatch $ubatch `
		-CacheK $ctk `
		-CacheV $ctv `
		-FlashAttn [bool]$ChkFlashAttn.IsChecked `
		-Mlock [bool]$ChkMlock.IsChecked `
		-Mmap [bool]$ChkMmap.IsChecked `
		-CpuAffinity [bool]$ChkCpuAffinity.IsChecked `
		-CpuAffinityMask $affMask `
		-Dflash [bool]$ChkDflash.IsChecked `
		-GdnReplay [bool]$ChkGdnReplay.IsChecked

	$TxtNewParamName.Text = ""
})

$BtnApplyQuickSweep.Add_Click({
	$sweepType = if ($CmbQuickSweep.SelectedItem) { [string]$CmbQuickSweep.SelectedItem.Tag } else { "threads" }

	switch ($sweepType) {
		"threads" {
			Add-ParamConfigItem -Name "Threads-02T" -Threads 2  -Gpu 99 -Ctx 4096
			Add-ParamConfigItem -Name "Threads-04T" -Threads 4  -Gpu 99 -Ctx 4096
			Add-ParamConfigItem -Name "Threads-08T" -Threads 8  -Gpu 99 -Ctx 4096
			Add-ParamConfigItem -Name "Threads-12T" -Threads 12 -Gpu 99 -Ctx 4096
			Add-ParamConfigItem -Name "Threads-16T" -Threads 16 -Gpu 99 -Ctx 4096
		}
		"gpu" {
			Add-ParamConfigItem -Name "GPU-00 (Pure CPU)"      -Threads 8 -Gpu 0  -Ctx 4096
			Add-ParamConfigItem -Name "GPU-16 (Partial 16ngl)" -Threads 8 -Gpu 16 -Ctx 4096
			Add-ParamConfigItem -Name "GPU-33 (Partial 33ngl)" -Threads 8 -Gpu 33 -Ctx 4096
			Add-ParamConfigItem -Name "GPU-99 (Full Offload)"  -Threads 8 -Gpu 99 -Ctx 4096
		}
		"context" {
			Add-ParamConfigItem -Name "Context-1024" -Threads 8 -Gpu 99 -Ctx 1024
			Add-ParamConfigItem -Name "Context-2048" -Threads 8 -Gpu 99 -Ctx 2048
			Add-ParamConfigItem -Name "Context-4096" -Threads 8 -Gpu 99 -Ctx 4096
			Add-ParamConfigItem -Name "Context-8192" -Threads 8 -Gpu 99 -Ctx 8192
		}
		"kvcache" {
			Add-ParamConfigItem -Name "Cache-F16 (Default)" -Threads 8 -Gpu 99 -Ctx 8192 -CacheK "f16"    -CacheV "f16"
			Add-ParamConfigItem -Name "Cache-Q8_0"          -Threads 8 -Gpu 99 -Ctx 8192 -CacheK "q8_0"   -CacheV "q8_0"
			Add-ParamConfigItem -Name "Cache-Q4_0"          -Threads 8 -Gpu 99 -Ctx 8192 -CacheK "q4_0"   -CacheV "q4_0"
			Add-ParamConfigItem -Name "Cache-Turbo4"        -Threads 8 -Gpu 99 -Ctx 8192 -CacheK "turbo4" -CacheV "turbo4"
			Add-ParamConfigItem -Name "Cache-Turbo2"        -Threads 8 -Gpu 99 -Ctx 8192 -CacheK "turbo2" -CacheV "turbo2"
		}
		"flashattn" {
			Add-ParamConfigItem -Name "FlashAttn-Off" -Threads 8 -Gpu 99 -Ctx 8192 -FlashAttn $false
			Add-ParamConfigItem -Name "FlashAttn-On"  -Threads 8 -Gpu 99 -Ctx 8192 -FlashAttn $true
		}
		"batch" {
			Add-ParamConfigItem -Name "Batch-512 (ub256)"   -Threads 8 -Gpu 99 -Ctx 4096 -Batch 512  -Ubatch 256
			Add-ParamConfigItem -Name "Batch-2048 (ub512)"  -Threads 8 -Gpu 99 -Ctx 4096 -Batch 2048 -Ubatch 512
			Add-ParamConfigItem -Name "Batch-4096 (ub1024)" -Threads 8 -Gpu 99 -Ctx 4096 -Batch 4096 -Ubatch 1024
		}
	}
})

$BtnRemoveParam.Add_Click({
	$indices = @($LstParams.SelectedIndices | Sort-Object -Descending)
	foreach ($idx in $indices) {
		if ($idx -ge 0 -and $idx -lt $Script:ParamConfigs.Count) {
			$Script:ParamConfigs.RemoveAt($idx)
			$LstParams.Items.RemoveAt($idx)
		}
	}
})

$BtnClearParams.Add_Click({
	$Script:ParamConfigs.Clear()
	$LstParams.Items.Clear()
})

# Initial State
Update-ProfilesDropdown
if ($CmbProfiles.Items.Count -gt 0) {
	Apply-ProfileObject -Profile $CmbProfiles.Items[0].Tag
}
Set-InterfaceLanguage -LangKey $global:CurrentLang
Update-ModeVisibility
Update-GpuDeviceList

# --- Offline Assets & Reporting ---
function Ensure-ChartJsLocal {
	param([string]$DestinationDir)
	$assetsDir = Join-Path -Path $DestinationDir -ChildPath "assets"
	if (-not (Test-Path -Path $assetsDir)) {
		[void](New-Item -ItemType Directory -Path $assetsDir -Force)
	}
	$targetFile = Join-Path -Path $assetsDir -ChildPath "chart.umd.min.js"
	if (-not (Test-Path -Path $targetFile)) {
		Write-LogMessage (Get-LocalizedText -Key "GeneratingReport")
		$downloadUrl = "https://cdn.jsdelivr.net/npm/chart.js/dist/chart.umd.min.js"
		try {
			[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
			Invoke-WebRequest -Uri $downloadUrl -OutFile $targetFile -UseBasicParsing
			Write-LogMessage "Chart.js downloaded successfully."
		}
		catch {
			$errMsg = $_.Exception.Message
			Write-LogMessage "Warning: Failed to download Chart.js ($errMsg). Visual charts may require internet connectivity."
		}
	}
	return $targetFile
}

function New-HtmlBenchmarkReport {
	param(
		[string]$OutputDir,
		[string]$ModeTitle,
		[string]$PrimaryMeta,
		[string]$TargetColumnHeader,
		[array]$TargetNames,
		[array]$ActiveScenarios,
		[array]$BenchmarkResults
	)

	[void](Ensure-ChartJsLocal -DestinationDir $OutputDir)

	if (-not (Test-Path -Path $templatePath)) {
		Write-LogMessage "Error: Report template not found at $templatePath"
		return ""
	}

	$reportTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"
	$reportFileName  = "llama_benchmark_report_${reportTimestamp}.html"
	$reportFilePath  = Join-Path -Path $OutputDir -ChildPath $reportFileName

	# Scenario labels
	$scenarioNames = @()
	foreach ($scen in $ActiveScenarios) {
		$scenarioNames += $scen["Name"]
	}
	$chartJsLabels = ($scenarioNames | ForEach-Object { "'$($_)'" }) -join ", "

	# Catppuccin color palette
	$palette = @("#89B4FA", "#A6E3A1", "#F9E2AF", "#F38BA8", "#CBA6F7", "#FAB387", "#94E2D5")

	$genDatasets    = @()
	$promptDatasets = @()
	$colorIndex     = 0

	for ($tIdx = 0; $tIdx -lt $TargetNames.Count; $tIdx++) {
		$targetName   = $TargetNames[$tIdx]
		$currentColor = $palette[$colorIndex % $palette.Count]
		$colorIndex++

		$genSpeeds    = @()
		$promptSpeeds = @()

		foreach ($scen in $ActiveScenarios) {
			$scenId = $scen["Id"]
			$entry  = $BenchmarkResults | Where-Object { $_.TargetName -eq $targetName -and $_.ScenarioId -eq $scenId }
			if ($null -ne $entry) {
				$genSpeeds    += [string]$entry.EvalSpeed
				$promptSpeeds += [string]$entry.PromptSpeed
			} else {
				$genSpeeds    += "0"
				$promptSpeeds += "0"
			}
		}

		$genDataStr    = $genSpeeds -join ", "
		$promptDataStr = $promptSpeeds -join ", "

		$genDatasets    += "{ label: '${targetName}', data: [${genDataStr}], backgroundColor: '${currentColor}' }"
		$promptDatasets += "{ label: '${targetName}', data: [${promptDataStr}], backgroundColor: '${currentColor}' }"
	}

	$genDatasetJs    = $genDatasets -join ",`r`n"
	$promptDatasetJs = $promptDatasets -join ",`r`n"

	# Build Load Time Datasets
	$loadLabels = ($TargetNames | ForEach-Object { "'$($_)'" }) -join ", "
	$loadValues = @()
	for ($tIdx = 0; $tIdx -lt $TargetNames.Count; $tIdx++) {
		$targetName = $TargetNames[$tIdx]
		$entries    = $BenchmarkResults | Where-Object { $_.TargetName -eq $targetName }
		$avgLoad    = 0.0
		if ($entries.Count -gt 0) {
			$sum     = ($entries | Measure-Object -Property LoadTime -Average).Average
			$avgLoad = [Math]::Round($sum, 2)
		}
		$loadValues += [string]$avgLoad
	}
	$loadValuesJs = $loadValues -join ", "

	# Build HTML Table Rows
	$tableRowsHtml = ""
	foreach ($row in $BenchmarkResults) {
		$tDisplay = $row.TargetName
		$sName    = $row.ScenarioName
		$lTime    = $row.LoadTime
		$pTokens  = $row.PromptTokens
		$pSpeed   = $row.PromptSpeed
		$eTokens  = $row.EvalTokens
		$eSpeed   = $row.EvalSpeed

		$tableRowsHtml += "<tr><td><strong>${tDisplay}</strong></td><td>${sName}</td><td>${pTokens}</td><td><strong>${pSpeed}</strong></td><td>${eTokens}</td><td><strong>${eSpeed}</strong></td><td>${lTime}</td></tr>`r`n"
	}

	$reportDateStr = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

	# Substitute values into template
	$renderedHtml = Get-Content -Path $templatePath -Raw -Encoding UTF8
	$renderedHtml = $renderedHtml.Replace("{{COMPARISON_MODE}}", $ModeTitle)
	$renderedHtml = $renderedHtml.Replace("{{PRIMARY_META}}", $PrimaryMeta)
	$renderedHtml = $renderedHtml.Replace("{{TARGET_COLUMN_HEADER}}", $TargetColumnHeader)
	$renderedHtml = $renderedHtml.Replace("{{EXECUTION_DATE}}", $reportDateStr)
	$renderedHtml = $renderedHtml.Replace("{{AUTHOR}}", "Adromir")
	$renderedHtml = $renderedHtml.Replace("{{CHART_LABELS}}", $chartJsLabels)
	$renderedHtml = $renderedHtml.Replace("{{GEN_DATASETS}}", $genDatasetJs)
	$renderedHtml = $renderedHtml.Replace("{{PROMPT_DATASETS}}", $promptDatasetJs)
	$renderedHtml = $renderedHtml.Replace("{{LOAD_LABELS}}", $loadLabels)
	$renderedHtml = $renderedHtml.Replace("{{LOAD_VALUES}}", $loadValuesJs)
	$renderedHtml = $renderedHtml.Replace("{{TABLE_ROWS}}", $tableRowsHtml)

	[System.IO.File]::WriteAllText($reportFilePath, $renderedHtml, [System.Text.Encoding]::UTF8)
	return $reportFilePath
}

# --- Core Benchmarking Engine ---
function Invoke-LlamaCliBenchmark {
	param(
		[string]$CliPath,
		[string]$ModelPath,
		[int]$Threads,
		[int]$GpuLayers,
		[int]$CtxSize,
		[int]$BatchSize = 2048,
		[int]$UbatchSize = 512,
		[string]$CacheTypeK = "f16",
		[string]$CacheTypeV = "f16",
		[bool]$FlashAttn = $true,
		[bool]$Mlock = $true,
		[bool]$Mmap = $true,
		[bool]$CpuAffinity = $false,
		[string]$CpuAffinityMask = "0xFF",
		[bool]$Dflash = $false,
		[bool]$GdnReplay = $false,
		[string]$ChatTemplate,
		[hashtable]$Scenario,
		[string]$TargetIdentifier,
		[PSCustomObject]$GpuDevice = $null,
		[switch]$IsWarmup
	)

	$promptText   = $Scenario["Prompt"]
	$predictCount = $Scenario["TokensToPredict"]

	# Process GPU Device Selection
	$effectiveGpuLayers = $GpuLayers
	$deviceArgs = @()

	if ($GpuDevice) {
		if ($GpuDevice.Id -eq "cpu") {
			$effectiveGpuLayers = 0
		}
		elseif ($GpuDevice.Backend -notin @("ROCM", "CUDA", "AUTO")) {
			$deviceArgs = @("-dev", $GpuDevice.Id)
		}
	}

	$argList = @(
		"-m", "`"${ModelPath}`"",
		"-t", "${Threads}",
		"-ngl", "${effectiveGpuLayers}",
		"-c", "${CtxSize}",
		"-n", "${predictCount}",
		"-p", "`"$((($promptText -replace "`r?`n", ' ') -replace '"', '\"'))`"",
		"--single-turn",
		"--simple-io",
		"--show-timings"
	)

	# Batching
	if ($BatchSize -gt 0) {
		$argList += @("-b", "${BatchSize}")
	}
	if ($UbatchSize -gt 0) {
		$argList += @("-ub", "${UbatchSize}")
	}

	# KV-Cache Quantization
	if (-not [string]::IsNullOrWhiteSpace($CacheTypeK) -and $CacheTypeK -ne "f16") {
		$argList += @("-ctk", "${CacheTypeK}")
	}
	if (-not [string]::IsNullOrWhiteSpace($CacheTypeV) -and $CacheTypeV -ne "f16") {
		$argList += @("-ctv", "${CacheTypeV}")
	}

	# Flash Attention
	if ($FlashAttn) {
		$argList += @("-fa", "on")
	} else {
		$argList += @("-fa", "off")
	}

	# Memory Management
	if ($Mlock) {
		$argList += "--mlock"
	}
	if ($Mmap -eq $false) {
		$argList += "--no-mmap"
	}

	# Speculative & Experimental Features
	if ($Dflash) {
		$argList += "--dflash"
	}
	if ($GdnReplay) {
		$argList += "--gdn-replay"
	}

	if ($deviceArgs.Count -gt 0) {
		$argList += $deviceArgs
	}

	if (-not [string]::IsNullOrWhiteSpace($ChatTemplate)) {
		if (Test-Path -Path $ChatTemplate) {
			$argList += @("--chat-template-file", "`"${ChatTemplate}`"")
		} else {
			$argList += @("--chat-template", "`"${ChatTemplate}`"")
		}
	}

	$cliDir = Split-Path -Parent $CliPath
	$psi = New-Object System.Diagnostics.ProcessStartInfo
	$psi.FileName               = $CliPath
	$psi.Arguments              = ($argList -join " ")
	$psi.WorkingDirectory       = $cliDir
	$psi.UseShellExecute        = $false
	$psi.RedirectStandardOutput = $true
	$psi.RedirectStandardError  = $true
	$psi.CreateNoWindow         = $true

	# Ensure dependent DLL directories are on PATH (e.g. CLI directory and Git Mingw64 for OpenSSL)
	$extraPaths = @($cliDir)
	$gitMingw64 = "C:\Program Files\Git\mingw64\bin"
	if (Test-Path -Path $gitMingw64) {
		$extraPaths += $gitMingw64
	}
	$existingPath = [Environment]::GetEnvironmentVariable("PATH", "Process")
	$psi.EnvironmentVariables["PATH"] = ($extraPaths + @($existingPath) -join ";")

	# Device-specific isolation environment variables:
	if ($GpuDevice) {
		if ($GpuDevice.Id -eq "cpu") {
			$psi.EnvironmentVariables["HIP_VISIBLE_DEVICES"] = "-1"
			$psi.EnvironmentVariables["CUDA_VISIBLE_DEVICES"] = "-1"
		}
		elseif ($GpuDevice.Backend -eq "ROCM" -and $null -ne $GpuDevice.Index) {
			$psi.EnvironmentVariables["HIP_VISIBLE_DEVICES"] = "$($GpuDevice.Index)"
		}
		elseif ($GpuDevice.Backend -eq "CUDA" -and $null -ne $GpuDevice.Index) {
			$psi.EnvironmentVariables["CUDA_VISIBLE_DEVICES"] = "$($GpuDevice.Index)"
		}
	}

	$proc = New-Object System.Diagnostics.Process
	$proc.StartInfo = $psi

	$sw = [System.Diagnostics.Stopwatch]::StartNew()
	[void]$proc.Start()
	if ($CpuAffinity -and -not [string]::IsNullOrWhiteSpace($CpuAffinityMask)) {
		try {
			$maskPtr = Convert-AffinityMask -MaskStr $CpuAffinityMask
			if ($maskPtr -ne [IntPtr]::Zero) {
				$proc.ProcessorAffinity = $maskPtr
			}
		} catch { }
	}
	$stdout = $proc.StandardOutput.ReadToEnd()
	$stderr = $proc.StandardError.ReadToEnd()
	$proc.WaitForExit()
	$sw.Stop()
	$wallClockMs = $sw.ElapsedMilliseconds

	$fullOutput = "${stdout}`r`n${stderr}"

	# Check exit code
	if ($proc.ExitCode -ne 0) {
		$errDetails = ($stderr.Trim())
		if ([string]::IsNullOrWhiteSpace($errDetails)) {
			$errDetails = ($stdout.Trim())
		}
		if ($errDetails.Length -gt 300) {
			$errDetails = $errDetails.Substring(0, 300) + "..."
		}
		if (-not $IsWarmup) {
			Write-LogMessage (Get-LocalizedText -Key "ExecutionFailed" -FormatArgs @($proc.ExitCode, $errDetails))
		}
	}

	# Parse Metrics using robust regex matching
	$loadTime       = 0.0
	$promptEvalTime = 0.0
	$promptTokens   = 0
	$promptSpeed    = 0.0
	$evalTime       = 0.0
	$evalRuns       = 0
	$evalSpeed      = 0.0

	# Pattern 1: Modern llama-cli timing banner: [ Prompt: 93.0 t/s | Generation: 62.9 t/s ]
	if ($fullOutput -match '\[\s*Prompt:\s*([\d\.]+)\s*t/s\s*\|\s*Generation:\s*([\d\.]+)\s*t/s\s*\]') {
		$promptSpeed = [double]$Matches[1]
		$evalSpeed   = [double]$Matches[2]
	}

	# Pattern 2: Detailed timing logs
	if ($fullOutput -match 'prompt eval time\s*=\s*([\d\.]+)\s*ms\s*/\s*(\d+)\s*tokens.*?([\d\.]+)\s*tokens per second') {
		$promptEvalTime = [double]$Matches[1]
		$promptTokens   = [int]$Matches[2]
		$promptSpeed    = [double]$Matches[3]
	}
	elseif ($fullOutput -match 'prompt eval time\s*=\s*([\d\.]+)\s*ms\s*/\s*(\d+)\s*tokens') {
		$promptEvalTime = [double]$Matches[1]
		$promptTokens   = [int]$Matches[2]
		if ($promptEvalTime -gt 0 -and $promptSpeed -eq 0.0) {
			$promptSpeed = [Math]::Round(($promptTokens / ($promptEvalTime / 1000.0)), 2)
		}
	}

	if ($fullOutput -match 'eval time\s*=\s*([\d\.]+)\s*ms\s*/\s*(\d+)\s*(?:runs|tokens).*?([\d\.]+)\s*tokens per second') {
		$evalTime  = [double]$Matches[1]
		$evalRuns  = [int]$Matches[2]
		$evalSpeed = [double]$Matches[3]
	}
	elseif ($fullOutput -match 'eval time\s*=\s*([\d\.]+)\s*ms\s*/\s*(\d+)\s*(?:runs|tokens)') {
		$evalTime  = [double]$Matches[1]
		$evalRuns  = [int]$Matches[2]
		if ($evalTime -gt 0 -and $evalSpeed -eq 0.0) {
			$evalSpeed = [Math]::Round(($evalRuns / ($evalTime / 1000.0)), 2)
		}
	}

	if ($evalSpeed -gt 0 -and $evalRuns -eq 0) {
		$evalRuns = $predictCount
	}
	if ($promptSpeed -gt 0 -and $promptTokens -eq 0) {
		$promptTokens = [Math]::Max(1, [int]($promptText.Length / 4))
	}

	if ($fullOutput -match 'load time\s*=\s*([\d\.]+)\s*ms') {
		$loadTime = [double]$Matches[1]
	}
	else {
		# Calculate model loading & GPU runtime initialization from total wall-clock minus inference duration
		$inferenceMs = 0.0
		if ($promptEvalTime -gt 0) {
			$inferenceMs += $promptEvalTime
		}
		elseif ($promptSpeed -gt 0 -and $promptTokens -gt 0) {
			$inferenceMs += ($promptTokens / $promptSpeed) * 1000.0
		}
		if ($evalTime -gt 0) {
			$inferenceMs += $evalTime
		}
		elseif ($evalSpeed -gt 0 -and $evalRuns -gt 0) {
			$inferenceMs += ($evalRuns / $evalSpeed) * 1000.0
		}

		if ($wallClockMs -gt $inferenceMs) {
			$loadTime = [Math]::Round(($wallClockMs - $inferenceMs), 2)
		}
	}

	return [PSCustomObject]@{
		TargetName     = $TargetIdentifier
		ScenarioId     = $Scenario["Id"]
		ScenarioName   = $Scenario["Name"]
		LoadTime       = $loadTime
		PromptEvalTime = $promptEvalTime
		PromptTokens   = $promptTokens
		PromptSpeed    = $promptSpeed
		EvalTime       = $evalTime
		EvalTokens     = $evalRuns
		EvalSpeed      = $evalSpeed
		ExitCode       = $proc.ExitCode
	}
}

function Invoke-LlamaWarmup {
	param(
		[string]$CliPath,
		[string]$ModelPath,
		[int]$Threads,
		[int]$GpuLayers,
		[int]$CtxSize,
		[int]$BatchSize = 2048,
		[int]$UbatchSize = 512,
		[string]$CacheTypeK = "f16",
		[string]$CacheTypeV = "f16",
		[bool]$FlashAttn = $true,
		[bool]$Mlock = $true,
		[bool]$Mmap = $true,
		[bool]$CpuAffinity = $false,
		[string]$CpuAffinityMask = "0xFF",
		[bool]$Dflash = $false,
		[bool]$GdnReplay = $false,
		[string]$ChatTemplate,
		[string]$TargetIdentifier,
		[PSCustomObject]$GpuDevice = $null
	)
	Write-LogMessage (Get-LocalizedText -Key "WarmupExecuting" -FormatArgs @($TargetIdentifier))
	$warmupScenario = @{
		Id              = "warmup"
		Name            = "Warmup"
		TokensToPredict = 8
		Prompt          = "Warm up inference kernel and memory buffers."
	}
	$null = Invoke-LlamaCliBenchmark `
		-CliPath $CliPath `
		-ModelPath $ModelPath `
		-Threads $Threads `
		-GpuLayers $GpuLayers `
		-CtxSize $CtxSize `
		-BatchSize $BatchSize `
		-UbatchSize $UbatchSize `
		-CacheTypeK $CacheTypeK `
		-CacheTypeV $CacheTypeV `
		-FlashAttn $FlashAttn `
		-Mlock $Mlock `
		-Mmap $Mmap `
		-CpuAffinity $CpuAffinity `
		-CpuAffinityMask $CpuAffinityMask `
		-Dflash $Dflash `
		-GdnReplay $GdnReplay `
		-ChatTemplate $ChatTemplate `
		-Scenario $warmupScenario `
		-TargetIdentifier $TargetIdentifier `
		-GpuDevice $GpuDevice `
		-IsWarmup
	Write-LogMessage (Get-LocalizedText -Key "WarmupDone" -FormatArgs @($TargetIdentifier))
}

# --- Main Benchmark Execution Trigger ---
$BtnRun.Add_Click({
	$mode = if ($CmbBenchmarkMode.SelectedItem) { [string]$CmbBenchmarkMode.SelectedItem.Tag } else { "builds" }

	# Scenarios Check
	$activeScenarios = @()
	if ($ChkScenShort.IsChecked)  { $activeScenarios += $Scenarios[0] }
	if ($ChkScenReason.IsChecked) { $activeScenarios += $Scenarios[1] }
	if ($ChkScenPrefill.IsChecked){ $activeScenarios += $Scenarios[2] }
	if ($ChkScenStress -and $ChkScenStress.IsChecked) { $activeScenarios += $Scenarios[3] }

	if ($activeScenarios.Count -eq 0) {
		[System.Windows.MessageBox]::Show((Get-LocalizedText -Key "SelectScenMsg"), (Get-LocalizedText -Key "ValidationError"), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
		return
	}

	# Chat Template
	$chatTemplate = $TxtChatTemplate.Text.Trim()

	# Mode-specific parameters & validation
	$testQueue = @() # array of test items
	$targetDisplayNames = @()
	$reportModeTitle = ""
	$primaryMeta = ""
	$colHeader = ""

	# Advanced Performance Parameters from UI
	$batchSize  = 2048;  [int]::TryParse($TxtBatchSize.Text, [ref]$batchSize) | Out-Null
	$ubatchSize = 512;   [int]::TryParse($TxtUbatchSize.Text, [ref]$ubatchSize) | Out-Null
	$cacheK     = if ($CmbCacheTypeK.SelectedItem) { [string]$CmbCacheTypeK.SelectedItem.Tag } else { "f16" }
	$cacheV     = if ($CmbCacheTypeV.SelectedItem) { [string]$CmbCacheTypeV.SelectedItem.Tag } else { "f16" }
	$flashAttn       = [bool]$ChkFlashAttn.IsChecked
	$mlock           = [bool]$ChkMlock.IsChecked
	$mmap            = [bool]$ChkMmap.IsChecked
	$cpuAffinity     = [bool]$ChkCpuAffinity.IsChecked
	$cpuAffinityMask = if ($TxtCpuAffinity) { $TxtCpuAffinity.Text.Trim() } else { "0xFF" }
	$dflash          = [bool]$ChkDflash.IsChecked
	$gdnReplay       = [bool]$ChkGdnReplay.IsChecked

	switch ($mode) {
		"builds" {
			$modelPath = $TxtModelPath.Text.Trim()
			if ([string]::IsNullOrWhiteSpace($modelPath) -or (-not (Test-Path -Path $modelPath))) {
				[System.Windows.MessageBox]::Show((Get-LocalizedText -Key "SelectModelMsg"), (Get-LocalizedText -Key "ValidationError"), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
				return
			}
			if ($LstBuilds.Items.Count -eq 0) {
				[System.Windows.MessageBox]::Show((Get-LocalizedText -Key "SelectBuildsMsg"), (Get-LocalizedText -Key "ValidationError"), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
				return
			}

			$threads = 8; [int]::TryParse($TxtThreads.Text, [ref]$threads) | Out-Null
			$gpu = 99;     [int]::TryParse($TxtGpuLayers.Text, [ref]$gpu) | Out-Null
			$ctx = 4096;   [int]::TryParse($TxtCtxSize.Text, [ref]$ctx) | Out-Null

			$modelName = Split-Path -Path $modelPath -Leaf
			$reportModeTitle = Get-LocalizedText -Key "ReportModeBuilds"
			$primaryMeta = "Model: ${modelName} | Threads: ${threads} | GPU: ${gpu} | Context: ${ctx} | FA: ${flashAttn} | Batch: ${batchSize}/${ubatchSize} | KV: ${cacheK}/${cacheV}"
			$colHeader = Get-LocalizedText -Key "ColBuild"

			foreach ($buildPath in $LstBuilds.Items) {
				$bShort = Split-Path -Path $buildPath -Leaf
				$bDir   = Split-Path -Path (Split-Path -Path $buildPath -Parent) -Leaf
				$tName  = "${bDir}/${bShort}"
				$targetDisplayNames += $tName

				$testQueue += [PSCustomObject]@{
					CliPath          = [string]$buildPath
					ModelPath        = $modelPath
					Threads          = $threads
					GpuLayers        = $gpu
					CtxSize          = $ctx
					BatchSize        = $batchSize
					UbatchSize       = $ubatchSize
					CacheTypeK       = $cacheK
					CacheTypeV       = $cacheV
					FlashAttn        = $flashAttn
					Mlock            = $mlock
					Mmap             = $mmap
					CpuAffinity      = $cpuAffinity
					CpuAffinityMask  = $cpuAffinityMask
					Dflash           = $dflash
					GdnReplay        = $gdnReplay
					TargetIdentifier = $tName
				}
			}
		}

		"models" {
			$cliPath = $TxtSingleCli.Text.Trim()
			if ([string]::IsNullOrWhiteSpace($cliPath) -or (-not (Test-Path -Path $cliPath))) {
				[System.Windows.MessageBox]::Show((Get-LocalizedText -Key "SelectCliMsg"), (Get-LocalizedText -Key "ValidationError"), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
				return
			}
			if ($LstModels.Items.Count -eq 0) {
				[System.Windows.MessageBox]::Show((Get-LocalizedText -Key "SelectModelsMsg"), (Get-LocalizedText -Key "ValidationError"), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
				return
			}

			$threads = 8; [int]::TryParse($TxtThreads.Text, [ref]$threads) | Out-Null
			$gpu = 99;     [int]::TryParse($TxtGpuLayers.Text, [ref]$gpu) | Out-Null
			$ctx = 4096;   [int]::TryParse($TxtCtxSize.Text, [ref]$ctx) | Out-Null

			$cliName = Split-Path -Path $cliPath -Leaf
			$reportModeTitle = Get-LocalizedText -Key "ReportModeModels"
			$primaryMeta = "Build: ${cliName} | Threads: ${threads} | GPU: ${gpu} | Context: ${ctx} | FA: ${flashAttn} | Batch: ${batchSize}/${ubatchSize} | KV: ${cacheK}/${cacheV}"
			$colHeader = Get-LocalizedText -Key "ColModel"

			foreach ($modelFile in $LstModels.Items) {
				$mName = Split-Path -Path $modelFile -Leaf
				$targetDisplayNames += $mName

				$testQueue += [PSCustomObject]@{
					CliPath          = $cliPath
					ModelPath        = [string]$modelFile
					Threads          = $threads
					GpuLayers        = $gpu
					CtxSize          = $ctx
					BatchSize        = $batchSize
					UbatchSize       = $ubatchSize
					CacheTypeK       = $cacheK
					CacheTypeV       = $cacheV
					FlashAttn        = $flashAttn
					Mlock            = $mlock
					Mmap             = $mmap
					CpuAffinity      = $cpuAffinity
					CpuAffinityMask  = $cpuAffinityMask
					Dflash           = $dflash
					GdnReplay        = $gdnReplay
					TargetIdentifier = $mName
				}
			}
		}

		"params" {
			$cliPath = $TxtSingleCli.Text.Trim()
			if ([string]::IsNullOrWhiteSpace($cliPath) -or (-not (Test-Path -Path $cliPath))) {
				[System.Windows.MessageBox]::Show((Get-LocalizedText -Key "SelectCliMsg"), (Get-LocalizedText -Key "ValidationError"), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
				return
			}
			$modelPath = $TxtModelPath.Text.Trim()
			if ([string]::IsNullOrWhiteSpace($modelPath) -or (-not (Test-Path -Path $modelPath))) {
				[System.Windows.MessageBox]::Show((Get-LocalizedText -Key "SelectModelMsg"), (Get-LocalizedText -Key "ValidationError"), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
				return
			}
			if ($Script:ParamConfigs.Count -eq 0) {
				[System.Windows.MessageBox]::Show((Get-LocalizedText -Key "SelectParamsMsg"), (Get-LocalizedText -Key "ValidationError"), [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
				return
			}

			$cliName   = Split-Path -Path $cliPath -Leaf
			$modelName = Split-Path -Path $modelPath -Leaf
			$reportModeTitle = Get-LocalizedText -Key "ReportModeParams"
			$primaryMeta = "Build: ${cliName} | Model: ${modelName}"
			$colHeader = Get-LocalizedText -Key "ColParam"

			foreach ($cfg in $Script:ParamConfigs) {
				$targetDisplayNames += $cfg.Name
				$testQueue += [PSCustomObject]@{
					CliPath          = $cliPath
					ModelPath        = $modelPath
					Threads          = $cfg.Threads
					GpuLayers        = $cfg.GpuLayers
					CtxSize          = $cfg.CtxSize
					BatchSize        = (if ($null -ne $cfg.BatchSize) { $cfg.BatchSize } else { $batchSize })
					UbatchSize       = (if ($null -ne $cfg.UbatchSize) { $cfg.UbatchSize } else { $ubatchSize })
					CacheTypeK       = (if ($null -ne $cfg.CacheTypeK) { $cfg.CacheTypeK } else { $cacheK })
					CacheTypeV       = (if ($null -ne $cfg.CacheTypeV) { $cfg.CacheTypeV } else { $cacheV })
					FlashAttn        = (if ($null -ne $cfg.FlashAttn) { $cfg.FlashAttn } else { $flashAttn })
					Mlock            = (if ($null -ne $cfg.Mlock) { $cfg.Mlock } else { $mlock })
					Mmap             = (if ($null -ne $cfg.Mmap) { $cfg.Mmap } else { $mmap })
					CpuAffinity      = (if ($null -ne $cfg.CpuAffinity) { $cfg.CpuAffinity } else { $cpuAffinity })
					CpuAffinityMask  = (if ($null -ne $cfg.CpuAffinityMask) { $cfg.CpuAffinityMask } else { $cpuAffinityMask })
					Dflash           = (if ($null -ne $cfg.Dflash) { $cfg.Dflash } else { $dflash })
					GdnReplay        = (if ($null -ne $cfg.GdnReplay) { $cfg.GdnReplay } else { $gdnReplay })
					TargetIdentifier = $cfg.Name
				}
			}
		}
	}

	# Repetitions & Hardware Device Selection
	$repetitions = 10
	if ($CmbRepetitions.SelectedItem) {
		[int]::TryParse([string]$CmbRepetitions.SelectedItem.Tag, [ref]$repetitions) | Out-Null
	}
	elseif ($CmbRepetitions.Text) {
		[int]::TryParse($CmbRepetitions.Text.Trim(), [ref]$repetitions) | Out-Null
	}
	if ($repetitions -lt 1) { $repetitions = 1 }

	$selectedGpuObj = $null
	if ($CmbGpuDevice.SelectedItem -and $CmbGpuDevice.SelectedItem.DataContext) {
		$selectedGpuObj = $CmbGpuDevice.SelectedItem.DataContext
	}
	$gpuNameDisplay = if ($selectedGpuObj) { $selectedGpuObj.Name } else { "Auto" }
	$primaryMeta = "Device: ${gpuNameDisplay} | Runs: ${repetitions} | " + $primaryMeta

	$totalSteps  = $testQueue.Count * $activeScenarios.Count
	$currentStep = 0

	# Lock UI during execution
	$BtnRun.IsEnabled    = $false
	$BtnReport.IsEnabled = $false
	$PrgStatus.Value     = 0

	Write-LogMessage (Get-LocalizedText -Key "StartingBenchmark" -FormatArgs @($totalSteps))

	$benchmarkResults = @()

	try {
		foreach ($testItem in $testQueue) {
			$targetName = $testItem.TargetIdentifier

			# Model Warmup Phase (if enabled)
			if ($ChkWarmup -and $ChkWarmup.IsChecked) {
				$statusPrefix = Get-LocalizedText -Key "StatusRunning"
				$TxtStatus.Text = "${statusPrefix}${targetName} (Warmup)"
				Update-WpfEvents
				Invoke-LlamaWarmup `
					-CliPath $testItem.CliPath `
					-ModelPath $testItem.ModelPath `
					-Threads $testItem.Threads `
					-GpuLayers $testItem.GpuLayers `
					-CtxSize $testItem.CtxSize `
					-BatchSize $testItem.BatchSize `
					-UbatchSize $testItem.UbatchSize `
					-CacheTypeK $testItem.CacheTypeK `
					-CacheTypeV $testItem.CacheTypeV `
					-FlashAttn $testItem.FlashAttn `
					-Mlock $testItem.Mlock `
					-Mmap $testItem.Mmap `
					-CpuAffinity $testItem.CpuAffinity `
					-CpuAffinityMask $testItem.CpuAffinityMask `
					-Dflash $testItem.Dflash `
					-GdnReplay $testItem.GdnReplay `
					-ChatTemplate $chatTemplate `
					-TargetIdentifier $targetName `
					-GpuDevice $selectedGpuObj
				Update-WpfEvents
			}

			foreach ($scenario in $activeScenarios) {
				$scenName = $scenario["Name"]
				$statusPrefix = Get-LocalizedText -Key "StatusRunning"
				$TxtStatus.Text = "${statusPrefix}${targetName} (${scenName})"
				Write-LogMessage (Get-LocalizedText -Key "ExecutingScenario" -FormatArgs @($targetName, $scenName))
				Update-WpfEvents

				$runResults = @()
				for ($r = 1; $r -le $repetitions; $r++) {
					$runRes = Invoke-LlamaCliBenchmark `
						-CliPath $testItem.CliPath `
						-ModelPath $testItem.ModelPath `
						-Threads $testItem.Threads `
						-GpuLayers $testItem.GpuLayers `
						-CtxSize $testItem.CtxSize `
						-BatchSize $testItem.BatchSize `
						-UbatchSize $testItem.UbatchSize `
						-CacheTypeK $testItem.CacheTypeK `
						-CacheTypeV $testItem.CacheTypeV `
						-FlashAttn $testItem.FlashAttn `
						-Mlock $testItem.Mlock `
						-Mmap $testItem.Mmap `
						-CpuAffinity $testItem.CpuAffinity `
						-CpuAffinityMask $testItem.CpuAffinityMask `
						-Dflash $testItem.Dflash `
						-GdnReplay $testItem.GdnReplay `
						-ChatTemplate $chatTemplate `
						-Scenario $scenario `
						-TargetIdentifier $targetName `
						-GpuDevice $selectedGpuObj

					$runResults += $runRes

					if ($repetitions -gt 1) {
						Write-LogMessage (Get-LocalizedText -Key "SingleRunMetrics" -FormatArgs @($r, $repetitions, $runRes.PromptSpeed, $runRes.EvalSpeed))
					}
					Update-WpfEvents
				}

				# Calculate averages across all runs
				$avgPromptSpeed = 0.0
				$avgEvalSpeed   = 0.0
				$avgLoadTime    = 0.0
				$validRuns = @($runResults | Where-Object { $_.ExitCode -eq 0 })
				if ($validRuns.Count -gt 0) {
					$avgPromptSpeed = [Math]::Round(($validRuns | Measure-Object -Property PromptSpeed -Average).Average, 2)
					$avgEvalSpeed   = [Math]::Round(($validRuns | Measure-Object -Property EvalSpeed -Average).Average, 2)
					$avgLoadTime    = [Math]::Round(($validRuns | Measure-Object -Property LoadTime -Average).Average, 2)
				}

				$lastRes = $runResults[-1]
				$res = [PSCustomObject]@{
					TargetName     = $targetName
					ScenarioId     = $scenario["Id"]
					ScenarioName   = $scenario["Name"]
					LoadTime       = $avgLoadTime
					PromptEvalTime = $lastRes.PromptEvalTime
					PromptTokens   = $lastRes.PromptTokens
					PromptSpeed    = $avgPromptSpeed
					EvalTime       = $lastRes.EvalTime
					EvalTokens     = $lastRes.EvalTokens
					EvalSpeed      = $avgEvalSpeed
					ExitCode       = $lastRes.ExitCode
					Runs           = $repetitions
				}

				$benchmarkResults += $res

				if ($repetitions -gt 1) {
					Write-LogMessage (Get-LocalizedText -Key "AvgResultMetrics" -FormatArgs @($repetitions, $avgPromptSpeed, $avgEvalSpeed, $avgLoadTime))
				} else {
					Write-LogMessage (Get-LocalizedText -Key "ResultMetrics" -FormatArgs @($avgPromptSpeed, $avgEvalSpeed, $avgLoadTime))
				}

				$currentStep++
				$PrgStatus.Value = [Math]::Round(($currentStep / $totalSteps) * 100)
				Update-WpfEvents
			}
		}

		# Generate Report
		Write-LogMessage (Get-LocalizedText -Key "GeneratingReport")
		$reportFile = New-HtmlBenchmarkReport `
			-OutputDir $scriptDir `
			-ModeTitle $reportModeTitle `
			-PrimaryMeta $primaryMeta `
			-TargetColumnHeader $colHeader `
			-TargetNames $targetDisplayNames `
			-ActiveScenarios $activeScenarios `
			-BenchmarkResults $benchmarkResults

		$Script:GeneratedReportPath = $reportFile
		if (-not [string]::IsNullOrWhiteSpace($reportFile)) {
			Write-LogMessage (Get-LocalizedText -Key "ReportGenerated" -FormatArgs @($reportFile))
			$BtnReport.IsEnabled = $true
		}

		$TxtStatus.Text = Get-LocalizedText -Key "StatusDone"
	}
	catch {
		$errMsg = $_.Exception.Message
		Write-LogMessage (Get-LocalizedText -Key "ExecutionError" -FormatArgs @($errMsg))
		$TxtStatus.Text = Get-LocalizedText -Key "StatusError"
	}
	finally {
		$BtnRun.IsEnabled = $true
	}
})

# --- Open Report Button ---
$BtnReport.Add_Click({
	$rep = $Script:GeneratedReportPath
	if (-not [string]::IsNullOrWhiteSpace($rep) -and (Test-Path -Path $rep)) {
		Start-Process -FilePath $rep
	}
})

# --- Show GUI Window ---
$null = $Window.ShowDialog()
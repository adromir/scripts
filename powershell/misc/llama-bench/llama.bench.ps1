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

# --- Path Resolution ---
$scriptDir = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptDir)) {
	$scriptDir = Split-Path -Parent $PSCommandPath
}
if ([string]::IsNullOrWhiteSpace($scriptDir)) {
	$scriptDir = (Get-Location).Path
}

$xamlPath     = Join-Path -Path $scriptDir -ChildPath "MainWindow.xaml"
$langDir      = Join-Path -Path $scriptDir -ChildPath "lang"
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
		Name            = "Scenario 1: Short Query"
		TokensToPredict = 64
		Prompt          = "Explain the technical concept of zero-cost abstractions in systems programming in two concise sentences."
	},
	@{
		Id              = "reasoning"
		Name            = "Scenario 2: Code & Logic"
		TokensToPredict = 128
		Prompt          = "Write a thread-safe singleton implementation in C++ using std::call_once. Explain why double-checked locking requires explicit memory barriers on weakly-ordered CPU architectures."
	},
	@{
		Id              = "prefill"
		Name            = "Scenario 3: Long Context Prefill"
		TokensToPredict = 32
		Prompt          = "The storage architecture employs a shared-nothing cluster layout where every physical node maintains independent shard ownership using log-structured merge trees. Incoming write operations append to a non-volatile write-ahead log (WAL) before updating an in-memory mutable memtable. Upon reaching fixed memory thresholds, immutable snapshots are flushed asynchronously to level-zero SSTable files on NVMe storage. Read amplification across levels is mitigated through Bloom filters configured for a one-percent false positive probability alongside an LRU block cache. Inter-node coordination uses Multi-Paxos with leased leadership leases to eliminate split-brain hazards and prevent leader-election latency spikes during network jitter. Network partitions trigger quorum isolation where client mutations require acknowledgments from a strict majority of voting replicas prior to commit confirmation. Tombstones created by deletions persist until the compaction watermark guarantees that no concurrent scanning iterators require visibility of historical states. Summarize the critical write bottlenecks and fault recovery procedures outlined above."
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

$LblChatTemplate       = $Window.FindName("LblChatTemplate")
$TxtChatTemplate       = $Window.FindName("TxtChatTemplate")
$BtnBrowseTemplate     = $Window.FindName("BtnBrowseTemplate")
$BtnBenchmarkTemplate  = $Window.FindName("BtnBenchmarkTemplate")

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
$ChkScenShort          = $Window.FindName("ChkScenShort")
$ChkScenReason         = $Window.FindName("ChkScenReason")
$ChkScenPrefill        = $Window.FindName("ChkScenPrefill")
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
	$LblChatTemplate.Text      = $dict["ChatTemplate"]
	$BtnBrowseTemplate.Content = $dict["Browse"]
	if ($BtnBenchmarkTemplate){ $BtnBenchmarkTemplate.Content = $dict["UseBenchmarkJinja"] }

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
	if ($CmbQuickSweep.Items.Count -ge 3) {
		$CmbQuickSweep.Items[0].Content = $dict["SweepThreads"]
		$CmbQuickSweep.Items[1].Content = $dict["SweepGpu"]
		$CmbQuickSweep.Items[2].Content = $dict["SweepContext"]
	}
	$BtnRemoveParam.Content    = $dict["RemoveParam"]
	$BtnClearParams.Content    = $dict["ClearParams"]

	# Scenarios
	$GrpSuite.Header           = $dict["SuiteGroup"]
	$ChkScenShort.Content      = $dict["ScenShort"]
	$ChkScenReason.Content     = $dict["ScenReason"]
	$ChkScenPrefill.Content    = $dict["ScenPrefill"]
	if ($LblScenEvalHeader)    { $LblScenEvalHeader.Text = $dict["ScenariosEvaluate"] }
	if ($LblScenPromptSpeed)   { $LblScenPromptSpeed.Text = "• " + $dict["ScenPromptSpeed"] }
	if ($LblScenGenSpeed)      { $LblScenGenSpeed.Text = "• " + $dict["ScenGenSpeed"] }
	if ($LblScenLoadTime)      { $LblScenLoadTime.Text = "• " + $dict["ScenLoadTime"] }

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
$BtnBrowseSingleCli.Add_Click({
	$dlg = New-Object System.Windows.Forms.OpenFileDialog
	$dlg.Title = Get-LocalizedText -Key "DialogSelectBuildTitle"
	$dlg.Filter = "Executables (*.exe)|*.exe|All Files (*.*)|*.*"
	if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
		$TxtSingleCli.Text = $dlg.FileName
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

# Parameter Sweep Events
function Add-ParamConfigItem {
	param([string]$Name, [int]$Threads, [int]$Gpu, [int]$Ctx)
	$cfgObj = [PSCustomObject]@{
		Name      = $Name
		Threads   = $Threads
		GpuLayers = $Gpu
		CtxSize   = $Ctx
		DisplayText = "${Name}  (Threads: ${Threads} | GPU: ${Gpu} | Context: ${Ctx})"
	}
	[void]$Script:ParamConfigs.Add($cfgObj)
	[void]$LstParams.Items.Add($cfgObj.DisplayText)
}

$BtnAddCustomParam.Add_Click({
	$name = $TxtNewParamName.Text.Trim()
	$threads = 8
	[int]::TryParse($TxtNewParamThreads.Text, [ref]$threads) | Out-Null
	$gpu = 99
	[int]::TryParse($TxtNewParamGpu.Text, [ref]$gpu) | Out-Null
	$ctx = 4096
	[int]::TryParse($TxtNewParamCtx.Text, [ref]$ctx) | Out-Null

	if ([string]::IsNullOrWhiteSpace($name)) {
		$name = "Config-${threads}T-${gpu}NGL"
	}

	Add-ParamConfigItem -Name $name -Threads $threads -Gpu $gpu -Ctx $ctx
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
Set-InterfaceLanguage -LangKey $global:CurrentLang
Update-ModeVisibility

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
		[string]$ChatTemplate,
		[hashtable]$Scenario,
		[string]$TargetIdentifier
	)

	$promptText   = $Scenario["Prompt"]
	$predictCount = $Scenario["TokensToPredict"]

	$argList = @(
		"-m", "`"${ModelPath}`"",
		"-t", "${Threads}",
		"-ngl", "${GpuLayers}",
		"-c", "${CtxSize}",
		"-n", "${predictCount}",
		"-p", "`"${promptText}`"",
		"--show-timings"
	)

	if (-not [string]::IsNullOrWhiteSpace($ChatTemplate)) {
		if (Test-Path -Path $ChatTemplate) {
			$argList += @("--chat-template-file", "`"${ChatTemplate}`"")
		} else {
			$argList += @("--chat-template", "`"${ChatTemplate}`"")
		}
	}

	$psi = New-Object System.Diagnostics.ProcessStartInfo
	$psi.FileName               = $CliPath
	$psi.Arguments              = ($argList -join " ")
	$psi.UseShellExecute        = $false
	$psi.RedirectStandardOutput = $true
	$psi.RedirectStandardError  = $true
	$psi.CreateNoWindow         = $true

	$proc = New-Object System.Diagnostics.Process
	$proc.StartInfo = $psi

	[void]$proc.Start()
	$stdout = $proc.StandardOutput.ReadToEnd()
	$stderr = $proc.StandardError.ReadToEnd()
	$proc.WaitForExit()

	$fullOutput = "${stdout}`r`n${stderr}"

	# Parse Metrics using robust regex matching
	$loadTime       = 0.0
	$promptEvalTime = 0.0
	$promptTokens   = 0
	$promptSpeed    = 0.0
	$evalTime       = 0.0
	$evalRuns       = 0
	$evalSpeed      = 0.0

	if ($fullOutput -match 'load time\s*=\s*([\d\.]+)\s*ms') {
		$loadTime = [double]$Matches[1]
	}

	if ($fullOutput -match 'prompt eval time\s*=\s*([\d\.]+)\s*ms\s*/\s*(\d+)\s*tokens.*?([\d\.]+)\s*tokens per second') {
		$promptEvalTime = [double]$Matches[1]
		$promptTokens   = [int]$Matches[2]
		$promptSpeed    = [double]$Matches[3]
	}
	elseif ($fullOutput -match 'prompt eval time\s*=\s*([\d\.]+)\s*ms\s*/\s*(\d+)\s*tokens') {
		$promptEvalTime = [double]$Matches[1]
		$promptTokens   = [int]$Matches[2]
		if ($promptEvalTime -gt 0) {
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
		if ($evalTime -gt 0) {
			$evalSpeed = [Math]::Round(($evalRuns / ($evalTime / 1000.0)), 2)
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

# --- Main Benchmark Execution Trigger ---
$BtnRun.Add_Click({
	$mode = if ($CmbBenchmarkMode.SelectedItem) { [string]$CmbBenchmarkMode.SelectedItem.Tag } else { "builds" }

	# Scenarios Check
	$activeScenarios = @()
	if ($ChkScenShort.IsChecked)  { $activeScenarios += $Scenarios[0] }
	if ($ChkScenReason.IsChecked) { $activeScenarios += $Scenarios[1] }
	if ($ChkScenPrefill.IsChecked){ $activeScenarios += $Scenarios[2] }

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
			$primaryMeta = "Model: ${modelName} | Threads: ${threads} | GPU: ${gpu} | Context: ${ctx}"
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
			$primaryMeta = "Build: ${cliName} | Threads: ${threads} | GPU: ${gpu} | Context: ${ctx}"
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
					TargetIdentifier = $cfg.Name
				}
			}
		}
	}

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

			foreach ($scenario in $activeScenarios) {
				$scenName = $scenario["Name"]
				$statusPrefix = Get-LocalizedText -Key "StatusRunning"
				$TxtStatus.Text = "${statusPrefix}${targetName} (${scenName})"
				Write-LogMessage (Get-LocalizedText -Key "ExecutingScenario" -FormatArgs @($targetName, $scenName))
				Update-WpfEvents

				$res = Invoke-LlamaCliBenchmark `
					-CliPath $testItem.CliPath `
					-ModelPath $testItem.ModelPath `
					-Threads $testItem.Threads `
					-GpuLayers $testItem.GpuLayers `
					-CtxSize $testItem.CtxSize `
					-ChatTemplate $chatTemplate `
					-Scenario $scenario `
					-TargetIdentifier $targetName

				$benchmarkResults += $res

				Write-LogMessage (Get-LocalizedText -Key "ResultMetrics" -FormatArgs @($res.PromptSpeed, $res.EvalSpeed, $res.LoadTime))

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
# ==============================================================================
# llama.cpp Benchmark Suite
# Author: Adromir ([https://github.com/adromir](https://github.com/adromir))
# Description: Automated real-world performance benchmark for llama.cpp builds.
# ==============================================================================

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms

# Localization dictionary supporting English and German
$Localization = @{
	"en" = @{
		"Title"            = "llama.cpp Build Benchmark Suite"
		"Language"         = "Language:"
		"ModelGroup"       = "Model & Parameters"
		"ModelPath"        = "GGUF Model Path:"
		"Browse"           = "Browse..."
		"Threads"          = "Threads (-t):"
		"GpuLayers"        = "GPU Layers (-ngl):"
		"CtxSize"          = "Context Size (-c):"
		"ChatTemplate"     = "Chat Template (Jinja File or Identifier):"
		"BuildsGroup"      = "llama.cpp Executables (llama-cli.exe)"
		"AddBuild"         = "Add Build..."
		"RemoveBuild"      = "Remove Selected"
		"ClearBuilds"      = "Clear All"
		"SuiteGroup"       = "Test Suite Scenarios"
		"ScenShort"        = "Scenario 1: Short Query (Latency / Quick Q&A)"
		"ScenReason"       = "Scenario 2: Code & Logic (Balanced Inference)"
		"ScenPrefill"      = "Scenario 3: Long Context (Prefill Throughput)"
		"RunBtn"           = "Start Benchmark"
		"ReportBtn"        = "Open HTML Report"
		"StatusReady"      = "Ready"
		"StatusRunning"    = "Running benchmark on: "
		"StatusDone"       = "Benchmark completed successfully."
		"LogHeader"        = "Execution Log"
		"SelectModelMsg"   = "Please select a valid GGUF model file."
		"SelectBuildsMsg"  = "Please add at least one llama-cli.exe executable."
		"SelectScenMsg"    = "Please select at least one benchmark scenario."
	}
	"de" = @{
		"Title"            = "llama.cpp Build Benchmark Suite"
		"Language"         = "Sprache:"
		"ModelGroup"       = "Modell & Parameter"
		"ModelPath"        = "GGUF-Modellpfad:"
		"Browse"           = "Durchsuchen..."
		"Threads"          = "Threads (-t):"
		"GpuLayers"        = "GPU-Layers (-ngl):"
		"CtxSize"          = "Kontextgröße (-c):"
		"ChatTemplate"     = "Chat-Template (Jinja-Datei oder Kennung):"
		"BuildsGroup"      = "llama.cpp Executables (llama-cli.exe)"
		"AddBuild"         = "Build hinzufügen..."
		"RemoveBuild"      = "Auswahl entfernen"
		"ClearBuilds"      = "Alle leeren"
		"SuiteGroup"       = "Test-Suite Szenarien"
		"ScenShort"        = "Szenario 1: Kurzabfrage (Latenz / Quick Q&A)"
		"ScenReason"       = "Szenario 2: Code & Logik (Ausgewogene Inferenz)"
		"ScenPrefill"      = "Szenario 3: Langer Kontext (Prefill-Durchsatz)"
		"RunBtn"           = "Benchmark starten"
		"ReportBtn"        = "HTML-Report öffnen"
		"StatusReady"      = "Bereit"
		"StatusRunning"    = "Benchmark läuft auf: "
		"StatusDone"       = "Benchmark erfolgreich abgeschlossen."
		"LogHeader"        = "Ausführungs-Log"
		"SelectModelMsg"   = "Bitte wählen Sie eine gültige GGUF-Modelldatei aus."
		"SelectBuildsMsg"  = "Bitte fügen Sie mindestens eine llama-cli.exe hinzu."
		"SelectScenMsg"    = "Bitte wählen Sie mindestens ein Benchmark-Szenario aus."
	}
}

# Test Suite scenario definitions
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

# WPF XAML Interface Definition
[xml]$Xaml = @'
<Window Background="#1E1E2E" FontFamily="Segoe UI" FontSize="13" Foreground="#CDD6F4" Height="780" Title="llama.cpp Build Benchmark Suite" Width="960" WindowStartupLocation="CenterScreen" xmlns="[http://schemas.microsoft.com/winfx/2006/xaml/presentation](http://schemas.microsoft.com/winfx/2006/xaml/presentation)" xmlns:x="[http://schemas.microsoft.com/winfx/2006/xaml](http://schemas.microsoft.com/winfx/2006/xaml)">
	<Grid Margin="16">
		<Grid.RowDefinitions>
			<RowDefinition Height="Auto"/>
			<RowDefinition Height="Auto"/>
			<RowDefinition Height="*"/>
			<RowDefinition Height="Auto"/>
			<RowDefinition Height="180"/>
			<RowDefinition Height="Auto"/>
		</Grid.RowDefinitions>

		<!-- Top Bar: Title and Language Selector -->
		<DockPanel Grid.Row="0" Margin="0,0,0,12">
			<TextBlock FontSize="18" FontWeight="Bold" Foreground="#89B4FA" Text="llama.cpp Build Benchmark Suite" VerticalAlignment="Center"/>
			<StackPanel HorizontalAlignment="Right" Orientation="Horizontal">
				<TextBlock Foreground="#A6ADC8" Margin="0,0,8,0" Text="Language:" VerticalAlignment="Center" x:Name="LblLanguage"/>
				<ComboBox Height="26" SelectedIndex="0" Width="100" x:Name="CmbLanguage">
					<ComboBoxItem Content="English" Tag="en"/>
					<ComboBoxItem Content="Deutsch" Tag="de"/>
				</ComboBox>
			</StackPanel>
		</DockPanel>

		<!-- Model & Parameters -->
		<GroupBox BorderBrush="#45475A" Foreground="#89B4FA" Grid.Row="1" Header="Model &amp; Parameters" Margin="0,0,0,12" Padding="10" x:Name="GrpModel">
			<Grid>
				<Grid.RowDefinitions>
					<RowDefinition Height="Auto"/>
					<RowDefinition Height="Auto"/>
					<RowDefinition Height="Auto"/>
				</Grid.RowDefinitions>
				<Grid.ColumnDefinitions>
					<ColumnDefinition Width="140"/>
					<ColumnDefinition Width="*"/>
					<ColumnDefinition Width="90"/>
				</Grid.ColumnDefinitions>

				<!-- Model Path -->
				<TextBlock Foreground="#CDD6F4" Grid.Column="0" Grid.Row="0" Text="GGUF Model Path:" VerticalAlignment="Center" x:Name="LblModelPath"/>
				<TextBox Background="#313244" BorderBrush="#585B70" Foreground="#CDD6F4" Grid.Column="1" Grid.Row="0" Height="26" Margin="0,2,8,2" x:Name="TxtModelPath"/>
				<Button Background="#45475A" BorderBrush="#585B70" Content="Browse..." Foreground="#CDD6F4" Grid.Column="2" Grid.Row="0" Height="26" x:Name="BtnBrowseModel"/>

				<!-- Parameters -->
				<Grid Grid.Column="0" Grid.ColumnSpan="3" Grid.Row="1" Margin="0,8,0,0">
					<Grid.ColumnDefinitions>
						<ColumnDefinition Width="140"/>
						<ColumnDefinition Width="80"/>
						<ColumnDefinition Width="30"/>
						<ColumnDefinition Width="120"/>
						<ColumnDefinition Width="80"/>
						<ColumnDefinition Width="30"/>
						<ColumnDefinition Width="120"/>
						<ColumnDefinition Width="80"/>
					</Grid.ColumnDefinitions>
					<TextBlock Foreground="#CDD6F4" Grid.Column="0" Text="Threads (-t):" VerticalAlignment="Center" x:Name="LblThreads"/>
					<TextBox Background="#313244" BorderBrush="#585B70" Foreground="#CDD6F4" Grid.Column="1" Height="26" HorizontalContentAlignment="Center" Text="8" x:Name="TxtThreads"/>

					<TextBlock Foreground="#CDD6F4" Grid.Column="3" Text="GPU Layers (-ngl):" VerticalAlignment="Center" x:Name="LblGpuLayers"/>
					<TextBox Background="#313244" BorderBrush="#585B70" Foreground="#CDD6F4" Grid.Column="4" Height="26" HorizontalContentAlignment="Center" Text="99" x:Name="TxtGpuLayers"/>

					<TextBlock Foreground="#CDD6F4" Grid.Column="6" Text="Context Size (-c):" VerticalAlignment="Center" x:Name="LblCtxSize"/>
					<TextBox Background="#313244" BorderBrush="#585B70" Foreground="#CDD6F4" Grid.Column="7" Height="26" HorizontalContentAlignment="Center" Text="4096" x:Name="TxtCtxSize"/>
				</Grid>

				<!-- Chat Template -->
				<TextBlock Foreground="#CDD6F4" Grid.Column="0" Grid.Row="2" Margin="0,8,0,0" Text="Chat Template:" VerticalAlignment="Center" x:Name="LblChatTemplate"/>
				<TextBox Background="#313244" BorderBrush="#585B70" Foreground="#CDD6F4" Grid.Column="1" Grid.Row="2" Height="26" Margin="0,8,8,0" ToolTip="Leave blank for GGUF default, enter template name (e.g., chatml) or path to .jinja file" x:Name="TxtChatTemplate"/>
				<Button Background="#45475A" BorderBrush="#585B70" Content="Browse..." Foreground="#CDD6F4" Grid.Column="2" Grid.Row="2" Height="26" Margin="0,8,0,0" x:Name="BtnBrowseTemplate"/>
			</Grid>
		</GroupBox>

		<!-- Middle: Builds and Test Scenarios -->
		<Grid Grid.Row="2" Margin="0,0,0,12">
			<Grid.ColumnDefinitions>
				<ColumnDefinition Width="*"/>
				<ColumnDefinition Width="12"/>
				<ColumnDefinition Width="340"/>
			</Grid.ColumnDefinitions>

			<!-- Builds ListBox -->
			<GroupBox BorderBrush="#45475A" Foreground="#89B4FA" Grid.Column="0" Header="llama.cpp Executables (llama-cli.exe)" Padding="10" x:Name="GrpBuilds">
				<DockPanel>
					<StackPanel DockPanel.Dock="Bottom" HorizontalAlignment="Right" Margin="0,8,0,0" Orientation="Horizontal">
						<Button Background="#45475A" BorderBrush="#585B70" Content="Add Build..." Foreground="#CDD6F4" Height="28" Margin="0,0,8,0" Width="110" x:Name="BtnAddBuild"/>
						<Button Background="#45475A" BorderBrush="#585B70" Content="Remove Selected" Foreground="#CDD6F4" Height="28" Margin="0,0,8,0" Width="130" x:Name="BtnRemoveBuild"/>
						<Button Background="#45475A" BorderBrush="#585B70" Content="Clear All" Foreground="#CDD6F4" Height="28" Width="90" x:Name="BtnClearBuilds"/>
					</StackPanel>
					<ListBox Background="#181825" BorderBrush="#585B70" Foreground="#CDD6F4" SelectionMode="Extended" x:Name="LstBuilds"/>
				</DockPanel>
			</GroupBox>

			<!-- Test Suite Scenarios -->
			<GroupBox BorderBrush="#45475A" Foreground="#89B4FA" Grid.Column="2" Header="Test Suite Scenarios" Padding="10" x:Name="GrpSuite">
				<StackPanel>
					<CheckBox Content="Scenario 1: Short Query (Quick Q&amp;A)" Foreground="#CDD6F4" IsChecked="True" Margin="0,8,0,8" x:Name="ChkScenShort"/>
					<CheckBox Content="Scenario 2: Code &amp; Logic (Balanced)" Foreground="#CDD6F4" IsChecked="True" Margin="0,0,0,8" x:Name="ChkScenReason"/>
					<CheckBox Content="Scenario 3: Long Context (Prefill)" Foreground="#CDD6F4" IsChecked="True" Margin="0,0,0,8" x:Name="ChkScenPrefill"/>
					<TextBlock FontWeight="Bold" Foreground="#A6ADC8" Margin="0,16,0,4" Text="Scenarios evaluate:"/>
					<TextBlock Foreground="#A6ADC8" Margin="8,0,0,2" Text="• Prompt evaluation throughput (tokens/sec)"/>
					<TextBlock Foreground="#A6ADC8" Margin="8,0,0,2" Text="• Generation throughput (tokens/sec)"/>
					<TextBlock Foreground="#A6ADC8" Margin="8,0,0,2" Text="• Cold model load time (milliseconds)"/>
				</StackPanel>
			</GroupBox>
		</Grid>

		<!-- Actions and Progress -->
		<DockPanel Grid.Row="3" Margin="0,0,0,8">
			<Button Background="#A6E3A1" BorderThickness="0" Content="Start Benchmark" FontWeight="Bold" Foreground="#11111B" Height="32" Margin="0,0,10,0" Width="150" x:Name="BtnRun"/>
			<Button Background="#89B4FA" BorderThickness="0" Content="Open HTML Report" FontWeight="Bold" Foreground="#11111B" Height="32" IsEnabled="False" Margin="0,0,10,0" Width="150" x:Name="BtnReport"/>
			<ProgressBar Background="#313244" BorderBrush="#585B70" Foreground="#89B4FA" Height="32" Maximum="100" Minimum="0" Value="0" x:Name="PrgStatus"/>
		</DockPanel>

		<!-- Log Output -->
		<GroupBox BorderBrush="#45475A" Foreground="#89B4FA" Grid.Row="4" Header="Execution Log" Padding="6" x:Name="GrpLog">
			<TextBox Background="#11111B" BorderThickness="0" FontFamily="Consolas" FontSize="11" Foreground="#A6ADC8" HorizontalScrollBarVisibility="Auto" IsReadOnly="True" VerticalScrollBarVisibility="Auto" x:Name="TxtLog"/>
		</GroupBox>

		<!-- Status Bar -->
		<StatusBar Background="#181825" Foreground="#A6ADC8" Grid.Row="5" Margin="0,6,0,0">
			<StatusBarItem>
				<TextBlock Text="Ready" x:Name="TxtStatus"/>
			</StatusBarItem>
		</StatusBar>
	</Grid>
</Window>
'@

# Read XAML into Window object
$Reader = New-Object System.Xml.XmlNodeReader($Xaml)
$Window = [System.Windows.Markup.XamlReader]::Load($Reader)

# Map UI Controls
$CmbLanguage       =$Window.FindName("CmbLanguage")
$LblLanguage       =$Window.FindName("LblLanguage")
$GrpModel          =$Window.FindName("GrpModel")
$LblModelPath      =$Window.FindName("LblModelPath")
$TxtModelPath      =$Window.FindName("TxtModelPath")
$BtnBrowseModel    =$Window.FindName("BtnBrowseModel")
$LblThreads        =$Window.FindName("LblThreads")
$TxtThreads        =$Window.FindName("TxtThreads")
$LblGpuLayers      =$Window.FindName("LblGpuLayers")
$TxtGpuLayers      =$Window.FindName("TxtGpuLayers")
$LblCtxSize        =$Window.FindName("LblCtxSize")
$TxtCtxSize        =$Window.FindName("TxtCtxSize")
$LblChatTemplate   =$Window.FindName("LblChatTemplate")
$TxtChatTemplate   =$Window.FindName("TxtChatTemplate")
$BtnBrowseTemplate =$Window.FindName("BtnBrowseTemplate")
$GrpBuilds         =$Window.FindName("GrpBuilds")
$LstBuilds         =$Window.FindName("LstBuilds")
$BtnAddBuild       =$Window.FindName("BtnAddBuild")
$BtnRemoveBuild    =$Window.FindName("BtnRemoveBuild")
$BtnClearBuilds    =$Window.FindName("BtnClearBuilds")
$GrpSuite          =$Window.FindName("GrpSuite")
$ChkScenShort      =$Window.FindName("ChkScenShort")
$ChkScenReason     =$Window.FindName("ChkScenReason")
$ChkScenPrefill    =$Window.FindName("ChkScenPrefill")
$BtnRun            =$Window.FindName("BtnRun")
$BtnReport         =$Window.FindName("BtnReport")
$PrgStatus         =$Window.FindName("PrgStatus")
$GrpLog            =$Window.FindName("GrpLog")
$TxtLog            =$Window.FindName("TxtLog")
$TxtStatus         =$Window.FindName("TxtStatus")

# Script-wide storage for last generated report path
$Script:GeneratedReportPath = ""

# Helper to process pending WPF UI events and keep window responsive
function Update-WpfEvents {
	[System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
}

# Helper to append log messages safely
function Write-LogMessage {
	param([string]$Message)$timestamp = Get-Date -Format "HH:mm:ss"
	$TxtLog.AppendText("[${timestamp}]${Message}`r`n")
	$TxtLog.ScrollToEnd()
	Update-WpfEvents
}

# Apply localized strings to UI controls
function Set-InterfaceLanguage {
	param([string]$LangKey)$dict = $Localization[$LangKey]
	$Window.Title              =$dict["Title"]
	$LblLanguage.Text          =$dict["Language"]
	$GrpModel.Header           =$dict["ModelGroup"]
	$LblModelPath.Text         =$dict["ModelPath"]
	$BtnBrowseModel.Content    =$dict["Browse"]
	$LblThreads.Text           =$dict["Threads"]
	$LblGpuLayers.Text         =$dict["GpuLayers"]
	$LblCtxSize.Text           =$dict["CtxSize"]
	$LblChatTemplate.Text      =$dict["ChatTemplate"]
	$BtnBrowseTemplate.Content =$dict["Browse"]
	$GrpBuilds.Header          =$dict["BuildsGroup"]
	$BtnAddBuild.Content       =$dict["AddBuild"]
	$BtnRemoveBuild.Content    =$dict["RemoveBuild"]
	$BtnClearBuilds.Content    =$dict["ClearBuilds"]
	$GrpSuite.Header           =$dict["SuiteGroup"]
	$ChkScenShort.Content      =$dict["ScenShort"]
	$ChkScenReason.Content     =$dict["ScenReason"]
	$ChkScenPrefill.Content    =$dict["ScenPrefill"]
	$BtnRun.Content            =$dict["RunBtn"]
	$BtnReport.Content         =$dict["ReportBtn"]
	$GrpLog.Header             =$dict["LogHeader"]
	$TxtStatus.Text            =$dict["StatusReady"]
}

# Language switcher event
$CmbLanguage.Add_SelectionChanged({
	$selectedItem =$CmbLanguage.SelectedItem
	if ($null -ne$selectedItem) {
		$selectedTag = [string]$selectedItem.Tag
		Set-InterfaceLanguage -LangKey "${selectedTag}"
	}
})

# Model file browser dialog
$BtnBrowseModel.Add_Click({$dlg = New-Object System.Windows.Forms.OpenFileDialog
	$dlg.Title = "Select GGUF Model File"
	$dlg.Filter = "GGUF Model Files (*.gguf)|*.gguf|All Files (*.*)|*.*"
	if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
		$TxtModelPath.Text =$dlg.FileName
	}
})

# Chat Template file browser dialog
$BtnBrowseTemplate.Add_Click({$dlg = New-Object System.Windows.Forms.OpenFileDialog
	$dlg.Title = "Select Jinja Chat Template File"
	$dlg.Filter = "Jinja Template Files (*.jinja;*.jinja2)|*.jinja;*.jinja2|All Files (*.*)|*.*"
	if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
		$TxtChatTemplate.Text =$dlg.FileName
	}
})

# Add Build executable dialog
$BtnAddBuild.Add_Click({$dlg = New-Object System.Windows.Forms.OpenFileDialog
	$dlg.Title = "Select llama-cli.exe Executable"
	$dlg.Filter = "Executables (*.exe)|*.exe|All Files (*.*)|*.*"
	$dlg.Multiselect =$true
	if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
		foreach ($file in$dlg.FileNames) {
			if (-not $LstBuilds.Items.Contains($file)) {$null = $LstBuilds.Items.Add($file)
			}
		}
	}
})

# Remove selected Build
$BtnRemoveBuild.Add_Click({
	$selected = @($LstBuilds.SelectedItems)
	foreach ($item in$selected) {
		$LstBuilds.Items.Remove($item)
	}
})

# Clear all Builds
$BtnClearBuilds.Add_Click({$LstBuilds.Items.Clear()
})

# Ensure Chart.js is downloaded locally for offline reporting
function Ensure-ChartJsLocal {
	param([string]$DestinationDir)
	$assetsDir = Join-Path -Path "${DestinationDir}" -ChildPath "assets"
	if (-not (Test-Path -Path "${assetsDir}")) {
		$null = New-Item -ItemType Directory -Path "${assetsDir}" -Force
	}
	$targetFile = Join-Path -Path "${assetsDir}" -ChildPath "chart.umd.min.js"
	if (-not (Test-Path -Path "${targetFile}")) {
		Write-LogMessage "Downloading chart.umd.min.js for offline HTML reporting..."
		$downloadUrl = "[https://cdn.jsdelivr.net/npm/chart.js/dist/chart.umd.min.js](https://cdn.jsdelivr.net/npm/chart.js/dist/chart.umd.min.js)"
		try {
			[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
			Invoke-WebRequest -Uri "${downloadUrl}" -OutFile "${targetFile}" -UseBasicParsing
			Write-LogMessage "Chart.js downloaded successfully."
		}
		catch {
			$errMsg =$_.Exception.Message
			Write-LogMessage "Warning: Failed to download Chart.js (${errMsg}). Visual charts may require internet connectivity."
		}
	}
	return $targetFile
}

# Generate offline HTML report with Chart.js
function New-HtmlBenchmarkReport {
	param(
		[string]$OutputDir,
		[string]$ModelPath,
		[array]$BuildsList,
		[array]$ActiveScenarios,
		[array]$BenchmarkResults
	)

	$null = Ensure-ChartJsLocal -DestinationDir "${OutputDir}"
	$reportTimestamp = Get-Date -Format "yyyyMMdd_HHmmss"
	$reportFileName = "llama_benchmark_report_${reportTimestamp}.html"
	$reportFilePath = Join-Path -Path "${OutputDir}" -ChildPath "${reportFileName}"

	# Prepare labels and datasets for Chart.js
	$buildNames = @()
	foreach ($b in$BuildsList) {
		$parentDir = Split-Path -Path (Split-Path -Path "${b}" -Parent) -Leaf
		$fileName = Split-Path -Path "${b}" -Leaf
		$buildNames += "${parentDir}/${fileName}"
	}

	$scenarioNames = @()
	foreach ($scen in$ActiveScenarios) {
		$scenarioNames +=$scen["Name"]
	}

	# Build data structures for charts
	$chartJsLabels = ($scenarioNames | ForEach-Object { "'$($_)'" }) -join ", "

	# Colors palette for builds
	$palette = @("#89B4FA", "#A6E3A1", "#F9E2AF", "#F38BA8", "#CBA6F7", "#FAB387", "#94E2D5")

	# Generation Speed Datasets
	$genDatasets = @()
	$promptDatasets = @()$colorIndex = 0

	for ($bIdx = 0; $bIdx -lt$BuildsList.Count; $bIdx++) {$currentBuild = $BuildsList[$bIdx]
		$buildLabel =$buildNames[$bIdx]$currentColor = $palette[$colorIndex % $palette.Count]$colorIndex++

		$genSpeeds = @()$promptSpeeds = @()

		foreach ($scen in$ActiveScenarios) {
			$scenId =$scen["Id"]
			$entry =$BenchmarkResults | Where-Object { $_.Build -eq "${currentBuild}" -and $_.ScenarioId -eq "${scenId}" }
			if ($null -ne$entry) {
				$genSpeeds += [string]$entry.EvalSpeed
				$promptSpeeds += [string]$entry.PromptSpeed
			} else {
				$genSpeeds += "0"
				$promptSpeeds += "0"
			}
		}

		$genDataStr =$genSpeeds -join ", "
		$promptDataStr =$promptSpeeds -join ", "

		$genDatasets += "{ label: '${buildLabel}', data: [${genDataStr}], backgroundColor: '${currentColor}' }"
		$promptDatasets += "{ label: '${buildLabel}', data: [${promptDataStr}], backgroundColor: '${currentColor}' }"
	}

	$genDatasetJs =$genDatasets -join ",`r`n"
	$promptDatasetJs =$promptDatasets -join ",`r`n"

	# Build Load Time Datasets
	$loadLabels = ($buildNames | ForEach-Object { "'$($_)'" }) -join ", "
	$loadValues = @()
	for ($bIdx = 0; $bIdx -lt$BuildsList.Count; $bIdx++) {$currentBuild = $BuildsList[$bIdx]
		$buildEntries =$BenchmarkResults | Where-Object { $_.Build -eq "${currentBuild}" }
		$avgLoad = 0.0
		if ($buildEntries.Count -gt 0) {
			$sum = ($buildEntries | Measure-Object -Property LoadTime -Average).Average
			$avgLoad = [Math]::Round($sum, 2)
		}
		$loadValues += [string]$avgLoad
	}
	$loadValuesJs =$loadValues -join ", "

	# Build HTML Table Rows
	$tableRowsHtml = ""
	foreach ($row in $BenchmarkResults) {$bShort = Split-Path -Path $row.Build -Leaf$bDir = Split-Path -Path (Split-Path -Path $row.Build -Parent) -Leaf$displayBuild = "${bDir}/${bShort}"
		$sName =$row.ScenarioName
		$lTime =$row.LoadTime
		$pTokens =$row.PromptTokens
		$pSpeed =$row.PromptSpeed
		$eTokens =$row.EvalTokens
		$eSpeed =$row.EvalSpeed

		$tableRowsHtml += "<tr><td>${displayBuild}</td><td>${sName}</td><td>${pTokens}</td><td><strong>${pSpeed}</strong></td><td>${eTokens}</td><td><strong>${eSpeed}</strong></td><td>${lTime}</td></tr>"
	}

	$modelFileName = Split-Path -Path "${ModelPath}" -Leaf
	$reportDateStr = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

	$htmlTemplate = @"
<!DOCTYPE html>
<html lang="en">
<head>
	<meta charset="UTF-8">
	<meta name="viewport" content="width=device-width, initial-scale=1.0">
	<title>llama.cpp Benchmark Report</title>
	<script src="assets/chart.umd.min.js"></script>
	<style>
		:root {
			--bg: #1e1e2e;
			--surface: #252538;
			--card: #181825;
			--border: #313244;
			--text: #cdd6f4;
			--subtext: #a6adc8;
			--accent: #89b4fa;
			--success: #a6e3a1;
		}
		body {
			font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
			background-color: var(--bg);
			color: var(--text);
			margin: 0;
			padding: 24px;
		}
		.container {
			max-width: 1200px;
			margin: 0 auto;
		}
		header {
			border-bottom: 2px solid var(--border);
			padding-bottom: 16px;
			margin-bottom: 24px;
		}
		h1 {
			margin: 0 0 8px 0;
			color: var(--accent);
		}
		.meta {
			color: var(--subtext);
			font-size: 14px;
		}
		.chart-grid {
			display: grid;
			grid-template-columns: repeat(auto-fit, minmax(500px, 1fr));
			gap: 20px;
			margin-bottom: 30px;
		}
		.card {
			background-color: var(--surface);
			border: 1px solid var(--border);
			border-radius: 8px;
			padding: 16px;
			box-shadow: 0 4px 6px rgba(0,0,0,0.3);
		}
		.card h2 {
			margin-top: 0;
			font-size: 16px;
			color: var(--accent);
			border-bottom: 1px solid var(--border);
			padding-bottom: 8px;
		}
		table {
			width: 100%;
			border-collapse: collapse;
			margin-top: 10px;
			font-size: 13px;
		}
		th, td {
			padding: 10px 12px;
			text-align: left;
			border-bottom: 1px solid var(--border);
		}
		th {
			background-color: var(--card);
			color: var(--accent);
		}
		tr:hover {
			background-color: rgba(137, 180, 250, 0.05);
		}
		footer {
			margin-top: 40px;
			text-align: center;
			font-size: 12px;
			color: var(--subtext);
		}
	</style>
</head>
<body>
	<div class="container">
		<header>
			<h1>llama.cpp Realworld Benchmark Report</h1>
			<div class="meta">
				<span><strong>Model:</strong> ${modelFileName}</span> |
				<span><strong>Execution Date:</strong> ${reportDateStr}</span> |
				<span><strong>Author:</strong> Adromir</span>
			</div>
		</header>

		<div class="chart-grid">
			<div class="card">
				<h2>Generation Speed (Tokens/s - Higher is Better)</h2>
				<canvas id="chartGen"></canvas>
			</div>
			<div class="card">
				<h2>Prompt Processing Speed (Tokens/s - Higher is Better)</h2>
				<canvas id="chartPrompt"></canvas>
			</div>
		</div>

		<div class="card" style="margin-bottom: 30px;">
			<h2>Cold Model Load Time (ms - Lower is Better)</h2>
			<canvas id="chartLoad" style="max-height: 250px;"></canvas>
		</div>

		<div class="card">
			<h2>Detailed Benchmark Results</h2>
			<table>
				<thead>
					<tr>
						<th>Build Executable</th>
						<th>Scenario</th>
						<th>Prompt Tokens</th>
						<th>Prompt Speed (t/s)</th>
						<th>Eval Tokens</th>
						<th>Generation Speed (t/s)</th>
						<th>Load Time (ms)</th>
					</tr>
				</thead>
				<tbody>
					${tableRowsHtml}
				</tbody>
			</table>
		</div>

		<footer>
			Generated by llama.cpp Benchmark Suite &bull; Author: Adromir ([https://github.com/adromir](https://github.com/adromir))
		</footer>
	</div>

	<script>
		const defaultChartOptions = {
			responsive: true,
			plugins: {
				legend: { labels: { color: '#cdd6f4' } }
			},
			scales: {
				x: { ticks: { color: '#a6adc8' }, grid: { color: '#313244' } },
				y: { ticks: { color: '#a6adc8' }, grid: { color: '#313244' } }
			}
		};

		// Generation Chart
		new Chart(document.getElementById('chartGen'), {
			type: 'bar',
			data: {
				labels: [${chartJsLabels}],
				datasets: [
					${genDatasetJs}
				]
			},
			options: defaultChartOptions
		});

		// Prompt Processing Chart
		new Chart(document.getElementById('chartPrompt'), {
			type: 'bar',
			data: {
				labels: [${chartJsLabels}],
				datasets: [
					${promptDatasetJs}
				]
			},
			options: defaultChartOptions
		});

		// Load Time Chart
		new Chart(document.getElementById('chartLoad'), {
			type: 'bar',
			data: {
				labels: [${loadLabels}],
				datasets: [{
					label: 'Load Time (ms)',
					data: [${loadValuesJs}],
					backgroundColor: '#F38BA8'
				}]
			},
			options: defaultChartOptions
		});
	</script>
</body>
</html>
"@

	[System.IO.File]::WriteAllText("${reportFilePath}", $htmlTemplate, [System.Text.Encoding]::UTF8)
	return $reportFilePath
}

# Execute benchmark process and parse stderr / stdout timings
function Invoke-LlamaCliBenchmark {
	param(
		[string]$CliPath,
		[string]$ModelPath,
		[int]$Threads,
		[int]$GpuLayers,
		[int]$CtxSize,
		[string]$ChatTemplate,
		[hashtable]$Scenario
	)

	$promptText = $Scenario["Prompt"]
	$predictCount = $Scenario["TokensToPredict"]

	# Build CLI argument string
	$argList = @(
		"-m", "`"${ModelPath}`"",
		"-t", "${Threads}",
		"-ngl", "${GpuLayers}",
		"-c", "${CtxSize}",
		"-n", "${predictCount}",
		"-p", "`"${promptText}`"",
		"--show-timings"
	)

	# Handle chat template if provided
	if (-not [string]::IsNullOrWhiteSpace("${ChatTemplate}")) {
		if (Test-Path -Path "${ChatTemplate}") {
			$argList += @("--chat-template-file", "`"${ChatTemplate}`"")
		} else {
			$argList += @("--chat-template", "`"${ChatTemplate}`"")
		}
	}

	$psi = New-Object System.Diagnostics.ProcessStartInfo
	$psi.FileName = "${CliPath}"
	$psi.Arguments = ($argList -join " ")
	$psi.UseShellExecute = $false
	$psi.RedirectStandardOutput = $true
	$psi.RedirectStandardError = $true
	$psi.CreateNoWindow = $true

	$proc = New-Object System.Diagnostics.Process
	$proc.StartInfo = $psi

	$null = $proc.Start()
	$stdout = $proc.StandardOutput.ReadToEnd()
	$stderr = $proc.StandardError.ReadToEnd()
	$proc.WaitForExit()

	$fullOutput = "${stdout}`r`n${stderr}"

	# Parse Metrics using robust regex patterns
	$loadTime = 0.0
	$promptEvalTime = 0.0
	$promptTokens = 0
	$promptSpeed = 0.0
	$evalTime = 0.0
	$evalRuns = 0
	$evalSpeed = 0.0

	# Load Time
	if ($fullOutput -match 'load time\s*=\s*([\d\.]+)\s*ms') {
		$loadTime = [double]$Matches[1]
	}

	# Prompt Eval Time & Speed
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

	# Eval Time & Speed
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

	$result = [PSCustomObject]@{
		Build          = $CliPath
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

	return $result
}

# Main Benchmark Execution Trigger
$BtnRun.Add_Click({
	$curLang = [string]($CmbLanguage.SelectedItem.Tag)
	$dict = $Localization[$curLang]

	# Validation
	$modelPath = $TxtModelPath.Text.Trim()
	if ([string]::IsNullOrWhiteSpace("${modelPath}") -or (-not (Test-Path -Path "${modelPath}"))) {
		[System.Windows.MessageBox]::Show($dict["SelectModelMsg"], "Validation Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
		return
	}

	if ($LstBuilds.Items.Count -eq 0) {
		[System.Windows.MessageBox]::Show($dict["SelectBuildsMsg"], "Validation Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
		return
	}

	# Determine active scenarios
	$activeScenarios = @()
	if ($ChkScenShort.IsChecked)  { $activeScenarios += $Scenarios[0] }
	if ($ChkScenReason.IsChecked) { $activeScenarios += $Scenarios[1] }
	if ($ChkScenPrefill.IsChecked){ $activeScenarios += $Scenarios[2] }

	if ($activeScenarios.Count -eq 0) {
		[System.Windows.MessageBox]::Show($dict["SelectScenMsg"], "Validation Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
		return
	}

	# Parse Parameters
	$threads = 8
	[int]::TryParse($TxtThreads.Text, [ref]$threads) | Out-Null
	$gpuLayers = 99
	[int]::TryParse($TxtGpuLayers.Text, [ref]$gpuLayers) | Out-Null
	$ctxSize = 4096
	[int]::TryParse($TxtCtxSize.Text, [ref]$ctxSize) | Out-Null
	$chatTemplate = $TxtChatTemplate.Text.Trim()

	$buildList = @($LstBuilds.Items)
	$totalSteps = $buildList.Count * $activeScenarios.Count
	$currentStep = 0

	# Disable UI controls during benchmark
	$BtnRun.IsEnabled = $false
	$BtnReport.IsEnabled = $false
	$PrgStatus.Value = 0

	Write-LogMessage "Starting benchmark suite across ${totalSteps} test runs..."

	$benchmarkResults = @()

	try {
		foreach ($buildPath in $buildList) {
			$buildShort = Split-Path -Path "${buildPath}" -Leaf
			$buildDir = Split-Path -Path (Split-Path -Path "${buildPath}" -Parent) -Leaf
			$displayBuild = "${buildDir}/${buildShort}"

			foreach ($scenario in $activeScenarios) {
				$scenName = $scenario["Name"]
				$statusPrefix = $dict["StatusRunning"]
				$TxtStatus.Text = "${statusPrefix}${displayBuild} (${scenName})"
				Write-LogMessage "Executing: ${displayBuild} -> ${scenName}..."
				Update-WpfEvents

				$res = Invoke-LlamaCliBenchmark `
					-CliPath "${buildPath}" `
					-ModelPath "${modelPath}" `
					-Threads $threads `
					-GpuLayers $gpuLayers `
					-CtxSize $ctxSize `
					-ChatTemplate "${chatTemplate}" `
					-Scenario $scenario

				$benchmarkResults += $res

				$pSpeed = $res.PromptSpeed
				$eSpeed = $res.EvalSpeed
				$lTime = $res.LoadTime
				Write-LogMessage "Result: Prompt Speed = ${pSpeed} t/s | Eval Speed = ${eSpeed} t/s | Load = ${lTime} ms"

				$currentStep++
				$PrgStatus.Value = [Math]::Round(($currentStep / $totalSteps) * 100)
				Update-WpfEvents
			}
		}

		# Generate Report
		$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
		if ([string]::IsNullOrWhiteSpace("${scriptDir}")) {
			$scriptDir = [System.Environment]::CurrentDirectory
		}

		Write-LogMessage "Generating offline HTML report with Chart.js..."
		$reportFile = New-HtmlBenchmarkReport `
			-OutputDir "${scriptDir}" `
			-ModelPath "${modelPath}" `
			-BuildsList $buildList `
			-ActiveScenarios $activeScenarios `
			-BenchmarkResults $benchmarkResults

		$Script:GeneratedReportPath = $reportFile
		Write-LogMessage "Report successfully generated: ${reportFile}"

		$TxtStatus.Text = $dict["StatusDone"]
		$BtnReport.IsEnabled = $true
	}
	catch {
		$err = $_.Exception.Message
		Write-LogMessage "Error during benchmark execution: ${err}"
		$TxtStatus.Text = "Error encountered."
	}
	finally {
		$BtnRun.IsEnabled = $true
	}
})

# Open HTML Report Button
$BtnReport.Add_Click({
	$rep = $Script:GeneratedReportPath
	if (-not [string]::IsNullOrWhiteSpace("${rep}") -and (Test-Path -Path "${rep}")) {
		Start-Process -FilePath "${rep}"
	}
})

# Show the GUI Window
$null = $Window.ShowDialog()
#region Configuration Defaults & File Handling
# ================== CONFIGURATION DEFAULTS & FILE HANDLING ==================

# Default values (used if config file not found or value missing)
$defaultConfig = @{
    dawarichApiUrl           = "https://your-api-host.com/api/v1/points"
    dawarichApiKey           = "YOUR_API_KEY"
    photonApiUrl             = "https://photon.komoot.io"
    defaultTimeWindowSeconds = 60
    exiftoolPath             = "exiftool.exe"
    overwriteExisting        = $false
    alwaysQueryPhoton        = $false
    theme                    = "Dark"
    language                 = "en"
    lastTargetFolder         = ""
    fallbackMethod           = "Filename"
    filenamePatterns         = "PXL_(\d{8})_(\d{6})\d*`nIMG_(\d{8})_(\d{6})\d*`nVID_(\d{8})_(\d{6})\d*`nScreenshot_(\d{8})-(\d{6})`nSignal-(\d{4}-\d{2}-\d{2})-(\d{6})`nWhatsApp Image (\d{4}-\d{2}-\d{2}) at (\d{2}\.\d{2}\.\d{2})`nIMG-(\d{8})-WA\d+`n(\d{8})_(\d{6})\d*`n(\d{6})_(\d{9})"
    # New feature config keys
    recursive                = $false
    dryRun                   = $false
    photonOnly               = $false
    filterDateFrom           = ""
    filterDateTo             = ""
    fileExtensions           = ".jpg,.jpeg,.png,.tiff,.heic,.heif,.gif,.cr2,.dng,.arw,.orf,.webp,.mp4,.mov"
    apiRetryCount            = 3
    apiTimeoutSeconds        = 120
    minimizeTray             = $false
}

# Configuration file path
if ($PSScriptRoot) {
    $configFilePath = Join-Path -Path $PSScriptRoot -ChildPath "config.json"
}
else {
    $configFilePath = Join-Path -Path (Get-Location) -ChildPath "config.json"
    Write-Warning "Variable `$PSScriptRoot not found. Using current directory for config file: $configFilePath"
}

# Global variable to hold the current configuration
$script:currentConfig = $null

function Load-Configuration {
    param(
        [string]$FilePath,
        [hashtable]$Defaults
    )
    $config = $Defaults.Clone()
    $loadedConfig = $null
    if (Test-Path -Path $FilePath -PathType Leaf) {
        Write-Verbose "Loading configuration from $FilePath"
        try {
            $loadedConfig = Get-Content -Path $FilePath -Raw | ConvertFrom-Json -ErrorAction Stop
        }
        catch {
            Write-Warning "Failed to load or parse configuration file '$FilePath'. Using defaults. Error: $($_.Exception.Message)"
        }
    }
    else {
        Write-Verbose "Configuration file '$FilePath' not found. Using defaults."
    }

    if ($loadedConfig -ne $null) {
        if ($loadedConfig.PSObject.Properties.Name -contains 'dawarichApiUrl') { $config.dawarichApiUrl = $loadedConfig.dawarichApiUrl }
        elseif ($loadedConfig.PSObject.Properties.Name -contains 'gpsApiUrl') { $config.dawarichApiUrl = $loadedConfig.gpsApiUrl; Write-Verbose "Using old key 'gpsApiUrl'." }
        if ($loadedConfig.PSObject.Properties.Name -contains 'dawarichApiKey') { $config.dawarichApiKey = $loadedConfig.dawarichApiKey }
        elseif ($loadedConfig.PSObject.Properties.Name -contains 'gpsApiKey') { $config.dawarichApiKey = $loadedConfig.gpsApiKey; Write-Verbose "Using old key 'gpsApiKey'." }
        if ($loadedConfig.PSObject.Properties.Name -contains 'photonApiUrl') { $config.photonApiUrl = $loadedConfig.photonApiUrl }
        elseif ($loadedConfig.PSObject.Properties.Name -contains 'komootApiUrl') { $config.photonApiUrl = $loadedConfig.komootApiUrl; Write-Verbose "Using old key 'komootApiUrl'." }

        if ($null -ne $loadedConfig.PSObject.Properties['defaultTimeWindowSeconds']) { $config.defaultTimeWindowSeconds = $loadedConfig.defaultTimeWindowSeconds }
        if ($null -ne $loadedConfig.PSObject.Properties['exiftoolPath']) { $config.exiftoolPath = $loadedConfig.exiftoolPath }
        if ($null -ne $loadedConfig.PSObject.Properties['overwriteExisting']) { $config.overwriteExisting = $loadedConfig.overwriteExisting }
        if ($null -ne $loadedConfig.PSObject.Properties['alwaysQueryPhoton']) { $config.alwaysQueryPhoton = $loadedConfig.alwaysQueryPhoton }
        if ($null -ne $loadedConfig.PSObject.Properties['theme']) { $config.theme = $loadedConfig.theme }
        if ($null -ne $loadedConfig.PSObject.Properties['language']) { $config.language = $loadedConfig.language }
        if ($null -ne $loadedConfig.PSObject.Properties['lastTargetFolder']) { $config.lastTargetFolder = $loadedConfig.lastTargetFolder }
        if ($null -ne $loadedConfig.PSObject.Properties['fallbackMethod']) { $config.fallbackMethod = $loadedConfig.fallbackMethod }
        if ($null -ne $loadedConfig.PSObject.Properties['filenamePatterns']) { $config.filenamePatterns = $loadedConfig.filenamePatterns }
        # New keys
        if ($null -ne $loadedConfig.PSObject.Properties['recursive']) { $config.recursive = $loadedConfig.recursive }
        if ($null -ne $loadedConfig.PSObject.Properties['dryRun']) { $config.dryRun = $loadedConfig.dryRun }
        if ($null -ne $loadedConfig.PSObject.Properties['photonOnly']) { $config.photonOnly = $loadedConfig.photonOnly }
        if ($null -ne $loadedConfig.PSObject.Properties['filterDateFrom']) { $config.filterDateFrom = $loadedConfig.filterDateFrom }
        if ($null -ne $loadedConfig.PSObject.Properties['filterDateTo']) { $config.filterDateTo = $loadedConfig.filterDateTo }
        if ($null -ne $loadedConfig.PSObject.Properties['fileExtensions']) { $config.fileExtensions = $loadedConfig.fileExtensions }
        if ($null -ne $loadedConfig.PSObject.Properties['apiRetryCount']) { $config.apiRetryCount = $loadedConfig.apiRetryCount }
        if ($null -ne $loadedConfig.PSObject.Properties['apiTimeoutSeconds']) { $config.apiTimeoutSeconds = $loadedConfig.apiTimeoutSeconds }
        if ($null -ne $loadedConfig.PSObject.Properties['minimizeTray']) { $config.minimizeTray = $loadedConfig.minimizeTray }
    }

    try { $config.defaultTimeWindowSeconds = [int]$config.defaultTimeWindowSeconds } catch { Write-Warning "Invalid defaultTimeWindowSeconds. Using default."; $config.defaultTimeWindowSeconds = [int]$Defaults.defaultTimeWindowSeconds }
    try { $config.overwriteExisting = [bool]::Parse($config.overwriteExisting.ToString()) } catch { Write-Warning "Invalid overwriteExisting. Using default."; $config.overwriteExisting = [bool]$Defaults.overwriteExisting }
    try { $config.alwaysQueryPhoton = [bool]::Parse($config.alwaysQueryPhoton.ToString()) } catch { Write-Warning "Invalid alwaysQueryPhoton. Using default."; $config.alwaysQueryPhoton = [bool]$Defaults.alwaysQueryPhoton }

    return $config
}

function Save-Configuration {
    param(
        [string]$FilePath,
        [hashtable]$ConfigData
    )
    Write-Verbose "Saving configuration to $FilePath"
    try {
        # Backup existing config before overwriting
        if (Test-Path -Path $FilePath -PathType Leaf) {
            $backupPath = [System.IO.Path]::ChangeExtension($FilePath, '.backup.json')
            Copy-Item -Path $FilePath -Destination $backupPath -Force -ErrorAction SilentlyContinue
        }

        $dataToSave = $ConfigData.Clone()
        if ($dataToSave.ContainsKey('saveConfig')) { $dataToSave.Remove('saveConfig') }
        if ($dataToSave.ContainsKey('exiftoolTimeoutMs')) { $dataToSave.Remove('exiftoolTimeoutMs') }

        foreach ($key in $defaultConfig.Keys) {
            if (-not $dataToSave.ContainsKey($key)) {
                $dataToSave[$key] = $defaultConfig[$key]
            }
        }
        $dataToSave.Remove('gpsApiUrl') | Out-Null
        $dataToSave.Remove('gpsApiKey') | Out-Null
        $dataToSave.Remove('komootApiUrl') | Out-Null

        $dataToSave | ConvertTo-Json -Depth 3 | Set-Content -Path $FilePath -Encoding UTF8 -ErrorAction Stop
        Write-Host "Configuration saved to '$FilePath' (backup: config.backup.json)." -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to save configuration file '$FilePath'. Error: $($_.Exception.Message)"
    }
}
#endregion

#region Localization Dictionary
# ================== LOCALIZATION DICTIONARY ==================
$script:Lang = @{}
$langDir = Join-Path -Path $PSScriptRoot -ChildPath "lang"
if (Test-Path $langDir) {
    $jsonFiles = Get-ChildItem -Path $langDir -Filter "*.json"
    foreach ($file in $jsonFiles) {
        $langCode = $file.BaseName
        try {
            $jsonContent = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json
            $script:Lang[$langCode] = $jsonContent
        }
        catch {
            Write-Warning "Failed to load language file $($file.Name): $($_.Exception.Message)"
        }
    }
}
if ($script:Lang.Keys.Count -eq 0) {
    Write-Warning "No language files found in $langDir. UI will be empty."
}
#endregion

# Load assemblies once at startup
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Web

# Compiled C# handler for async stderr collection.
# .NET DataReceivedEventHandler fires on the ThreadPool, NOT the PowerShell pipeline thread,
# so it works even when the PS runspace is busy processing files.
if (-not ([System.Management.Automation.PSTypeName]'ExifStderrCollector').Type) {
    Add-Type -TypeDefinition @"
using System;
using System.Collections.Concurrent;
using System.Diagnostics;
using System.Text;

public class ExifStderrCollector {
    public ConcurrentQueue<string> Lines = new ConcurrentQueue<string>();

    // Pre-built delegate so PowerShell never needs to cast PSMethod -> Delegate
    public DataReceivedEventHandler Delegate {
        get { return new DataReceivedEventHandler(Handler); }
    }

    public void Handler(object sender, DataReceivedEventArgs e) {
        if (e.Data != null) {
            Lines.Enqueue(e.Data);
        }
    }

    public string DrainAll() {
        var sb = new StringBuilder();
        string line;
        while (Lines.TryDequeue(out line)) {
            if (sb.Length > 0) sb.Append("\n");
            sb.Append(line);
        }
        return sb.ToString();
    }
}
"@
}

#region GUI Functions
# ================== Main GUI FUNCTION (WPF) ==================

function Show-MainGui {
    $xamlPath = Join-Path -Path $PSScriptRoot -ChildPath "MainWindow.xaml"
    if (-not (Test-Path $xamlPath)) {
        Write-Error "MainWindow.xaml not found in $PSScriptRoot"
        return
    }

    $xaml = [System.IO.File]::ReadAllText($xamlPath, [System.Text.Encoding]::UTF8)
    $stringReader = New-Object System.IO.StringReader($xaml)
    $xmlReader = [System.Xml.XmlReader]::Create($stringReader)
    $mainAppWindow = [System.Windows.Markup.XamlReader]::Load($xmlReader)

    # UI Element Bindings
    $script:DawarichApiUrlTextBox = $mainAppWindow.FindName("DawarichApiUrlTextBox")
    $script:DawarichApiKeyTextBox = $mainAppWindow.FindName("DawarichApiKeyTextBox")
    $script:PhotonApiUrlTextBox = $mainAppWindow.FindName("PhotonApiUrlTextBox")
    $script:TimeWindowTextBox = $mainAppWindow.FindName("TimeWindowTextBox")
    $script:ExiftoolPathTextBox = $mainAppWindow.FindName("ExiftoolPathTextBox")
    $script:OverwriteCheckBox = $mainAppWindow.FindName("OverwriteCheckBox")
    $script:AlwaysQueryPhotonCheckBox = $mainAppWindow.FindName("AlwaysQueryPhotonCheckBox")
    $script:FallbackMethodComboBox = $mainAppWindow.FindName("FallbackMethodComboBox")
    $script:FilenamePatternTextBox = $mainAppWindow.FindName("FilenamePatternTextBox")
    $script:SaveSettingsButton = $mainAppWindow.FindName("SaveSettingsButton")
    $script:SaveSettingsStatus = $mainAppWindow.FindName("SaveSettingsStatus")
    $script:ThemeToggleButton = $mainAppWindow.FindName("ThemeToggleButton")
    $script:TargetFolderTextBox = $mainAppWindow.FindName("TargetFolderTextBox")
    $script:BrowseFolderButton = $mainAppWindow.FindName("BrowseFolderButton")
    $script:StartProcessingButton = $mainAppWindow.FindName("StartProcessingButton")
    $script:LogParagraph = $mainAppWindow.FindName("LogParagraph")
    $script:LogRichTextBox = $mainAppWindow.FindName("LogRichTextBox")
    $script:MainProgressBar = $mainAppWindow.FindName("MainProgressBar")
    $script:ProgressStatusText = $mainAppWindow.FindName("ProgressStatusText")
    $script:ProgressPercentText = $mainAppWindow.FindName("ProgressPercentText")
    $script:ExiftoolVersionBar = $mainAppWindow.FindName("ExiftoolVersionBar")
    $script:StatusBarText = $mainAppWindow.FindName("StatusBarText")

    # Language UI Bindings
    $script:SettingsTitleText = $mainAppWindow.FindName("SettingsTitleText")
    $script:DawarichUrlLabel = $mainAppWindow.FindName("DawarichUrlLabel")
    $script:DawarichKeyLabel = $mainAppWindow.FindName("DawarichKeyLabel")
    $script:PhotonUrlLabel = $mainAppWindow.FindName("PhotonUrlLabel")
    $script:TimeWindowLabel = $mainAppWindow.FindName("TimeWindowLabel")
    $script:ExiftoolPathLabel = $mainAppWindow.FindName("ExiftoolPathLabel")
    $script:LanguageLabel = $mainAppWindow.FindName("LanguageLabel")
    $script:LanguageComboBox = $mainAppWindow.FindName("LanguageComboBox")
    $script:WorkspaceTitleText = $mainAppWindow.FindName("WorkspaceTitleText")
    $script:TargetFolderLabel = $mainAppWindow.FindName("TargetFolderLabel")
    $script:FallbackMethodLabel = $mainAppWindow.FindName("FallbackMethodLabel")
    $script:FallbackMethodComboBox = $mainAppWindow.FindName("FallbackMethodComboBox")
    $script:FilenamePatternLabel = $mainAppWindow.FindName("FilenamePatternLabel")
    $script:FilenamePatternTextBox = $mainAppWindow.FindName("FilenamePatternTextBox")
    
    # New UI Bindings
    $script:TestDawarichButton = $mainAppWindow.FindName("TestDawarichButton")
    $script:TestPhotonButton = $mainAppWindow.FindName("TestPhotonButton")
    $script:BrowseExiftoolButton = $mainAppWindow.FindName("BrowseExiftoolButton")
    $script:DawarichStatusDot = $mainAppWindow.FindName("DawarichStatusDot")
    $script:PhotonStatusDot = $mainAppWindow.FindName("PhotonStatusDot")
    $script:RecursiveCheckBox = $mainAppWindow.FindName("RecursiveCheckBox")
    $script:DryRunCheckBox = $mainAppWindow.FindName("DryRunCheckBox")
    $script:PhotonOnlyCheckBox = $mainAppWindow.FindName("PhotonOnlyCheckBox")
    $script:LogFilterAllBtn = $mainAppWindow.FindName("LogFilterAllBtn")
    $script:LogFilterWarnBtn = $mainAppWindow.FindName("LogFilterWarnBtn")
    $script:LogFilterErrBtn = $mainAppWindow.FindName("LogFilterErrBtn")
    $script:LogFilterSkipBtn = $mainAppWindow.FindName("LogFilterSkipBtn")
    $script:ExportReportButton = $mainAppWindow.FindName("ExportReportButton")
    $script:StatUpdatedVal = $mainAppWindow.FindName("StatUpdatedVal")
    $script:StatWarningsVal = $mainAppWindow.FindName("StatWarningsVal")
    $script:StatSkippedVal = $mainAppWindow.FindName("StatSkippedVal")
    $script:StatRemainingVal = $mainAppWindow.FindName("StatRemainingVal")
    $script:StatUpdatedLbl = $mainAppWindow.FindName("StatUpdatedLbl")
    $script:StatWarningsLbl = $mainAppWindow.FindName("StatWarningsLbl")
    $script:StatSkippedLbl = $mainAppWindow.FindName("StatSkippedLbl")
    $script:StatRemainingLbl = $mainAppWindow.FindName("StatRemainingLbl")
    $script:ExiftoolVersionBar = $mainAppWindow.FindName("ExiftoolVersionBar")
    $script:ExiftoolVersionText = $mainAppWindow.FindName("ExiftoolVersionText")
    $script:ApiTimeoutTextBox = $mainAppWindow.FindName("ApiTimeoutTextBox")
    $script:RetryCountTextBox = $mainAppWindow.FindName("RetryCountTextBox")
    $script:MinimizeTrayCheckBox = $mainAppWindow.FindName("MinimizeTrayCheckBox")
    $script:DateFromPicker = $mainAppWindow.FindName("DateFromPicker")
    $script:DateToPicker = $mainAppWindow.FindName("DateToPicker")
    $script:FileExtensionsTextBox = $mainAppWindow.FindName("FileExtensionsTextBox")
    $script:PatternTestInputBox = $mainAppWindow.FindName("PatternTestInputBox")
    $script:PatternTestButton = $mainAppWindow.FindName("PatternTestButton")
    $script:PatternTestResult = $mainAppWindow.FindName("PatternTestResult")
    $script:ExiftoolVersionLabel = $mainAppWindow.FindName("ExiftoolVersionLabel")
    $script:ApiTimeoutLabel = $mainAppWindow.FindName("ApiTimeoutLabel")
    $script:RetryCountLabel = $mainAppWindow.FindName("RetryCountLabel")
    $script:FileExtensionsLabel = $mainAppWindow.FindName("FileExtensionsLabel")
    $script:DateFromLabel = $mainAppWindow.FindName("DateFromLabel")
    $script:DateToLabel = $mainAppWindow.FindName("DateToLabel")
    $script:PatternTestLabel = $mainAppWindow.FindName("PatternTestLabel")
    $script:StartIcon = $mainAppWindow.FindName("StartIcon")
    $script:CancelProcessingButton = $mainAppWindow.FindName("CancelProcessingButton")
    $script:CancelProcessingText = $mainAppWindow.FindName("CancelProcessingText")

    # Populate Language ComboBox
    $script:LanguageComboBox.Items.Clear()
    $availableLangs = $script:Lang.Keys | Sort-Object
    foreach ($l in $availableLangs) {
        $item = New-Object System.Windows.Controls.ComboBoxItem
        $item.Content = $l.ToUpper()
        $item.Tag = $l
        $script:LanguageComboBox.Items.Add($item) | Out-Null
    }

    # Load initial config into UI
    $script:DawarichApiUrlTextBox.Text = $script:currentConfig.dawarichApiUrl
    $script:DawarichApiKeyTextBox.Text = $script:currentConfig.dawarichApiKey
    $script:PhotonApiUrlTextBox.Text = $script:currentConfig.photonApiUrl
    $script:TimeWindowTextBox.Text = $script:currentConfig.defaultTimeWindowSeconds.ToString()
    $script:ExiftoolPathTextBox.Text = $script:currentConfig.exiftoolPath
    $script:OverwriteCheckBox.IsChecked = $script:currentConfig.overwriteExisting
    $script:AlwaysQueryPhotonCheckBox.IsChecked = $script:currentConfig.alwaysQueryPhoton
    
    # Set Fallback Method
    $fallbackMethod = if ($script:currentConfig.fallbackMethod) { $script:currentConfig.fallbackMethod } else { "Filename" }
    foreach ($item in $script:FallbackMethodComboBox.Items) {
        if ($item.Tag -eq $fallbackMethod) {
            $script:FallbackMethodComboBox.SelectedItem = $item
            break
        }
    }
    $defaultPatterns = "PXL_(\d{8})_(\d{6})`nIMG_(\d{8})_(\d{6})`nVID_(\d{8})_(\d{6})`nScreenshot_(\d{8})-(\d{6})`nSignal-(\d{4}-\d{2}-\d{2})-(\d{6})`nWhatsApp Image (\d{4}-\d{2}-\d{2}) at (\d{2}\.\d{2}\.\d{2})`n(\d{8})_(\d{6})`n(\d{6})_(\d{9})"
    $script:FilenamePatternTextBox.Text = if ($script:currentConfig.filenamePatterns) { $script:currentConfig.filenamePatterns } else { $defaultPatterns }
    if ($script:currentConfig.lastTargetFolder -and (Test-Path $script:currentConfig.lastTargetFolder -PathType Container)) {
        $script:TargetFolderTextBox.Text = $script:currentConfig.lastTargetFolder
    }
    $script:FileExtensionsTextBox.Text = if ($script:currentConfig.fileExtensions) { $script:currentConfig.fileExtensions } else { ".jpg,.jpeg,.png,.tiff,.heic,.heif,.gif,.cr2,.dng,.arw,.orf,.webp,.mp4,.mov" }

    # Language logic
    $script:currentLanguage = if ($script:currentConfig.language -and $script:Lang.ContainsKey($script:currentConfig.language)) { $script:currentConfig.language } elseif ($availableLangs -contains "en") { "en" } elseif ($availableLangs.Count -gt 0) { $availableLangs[0] } else { "" }
    
    for ($i = 0; $i -lt $script:LanguageComboBox.Items.Count; $i++) {
        if ($script:LanguageComboBox.Items[$i].Tag -eq $script:currentLanguage) {
            $script:LanguageComboBox.SelectedIndex = $i
            break
        }
    }

    function Set-Language {
        param([string]$LangCode)
        $dict = $script:Lang[$LangCode]
        if ($null -eq $dict) { return }

        $script:SettingsTitleText.Text = $dict.SettingsTitle
        $script:DawarichUrlLabel.Content = $dict.DawarichUrl
        $script:DawarichKeyLabel.Content = $dict.DawarichKey
        $script:PhotonUrlLabel.Content = $dict.PhotonUrl
        $script:TimeWindowLabel.Content = $dict.TimeWindow
        $script:ExiftoolPathLabel.Content = $dict.ExiftoolPath
        $script:OverwriteCheckBox.Content = $dict.OverwriteCheck
        $script:AlwaysQueryPhotonCheckBox.Content = $dict.AlwaysQueryPhoton
        $script:LanguageLabel.Content = $dict.LanguageLbl
        $script:WorkspaceTitleText.Text = $dict.WorkspaceTitle
        $script:TargetFolderLabel.Content = $dict.TargetFolderLbl
        $script:SaveSettingsStatus.Text = $dict.SavedStatus
        $script:FallbackMethodLabel.Content = if ($dict.FallbackMethodLbl) { $dict.FallbackMethodLbl } else { "Fallback Date Source:" }
        $script:FilenamePatternLabel.Content = if ($dict.FilenamePatternLbl) { $dict.FilenamePatternLbl } else { "Filename Patterns (Regex):" }
        
        # Safe TextBlock translation for premium layout buttons (preserving vector icons)
        if ($null -ne $script:SaveSettingsBtnText) { $script:SaveSettingsBtnText.Text = $dict.SaveSettingsBtn }
        if ($null -ne $script:ThemeToggleText) { $script:ThemeToggleText.Text = $dict.ThemeToggleBtn }
        if ($null -ne $script:BrowseBtnText) { $script:BrowseBtnText.Text = $dict.BrowseBtn }
        if ($null -ne $script:StartProcessingText) { $script:StartProcessingText.Text = $dict.StartProcessingBtn }
        if ($null -ne $script:CancelProcessingText) { $script:CancelProcessingText.Text = $dict.CancelBtn }
        if ($null -ne $script:TestDawarichText) { $script:TestDawarichText.Text = $dict.TestApiBtn }
        if ($null -ne $script:TestPhotonText) { $script:TestPhotonText.Text = $dict.TestApiBtn }

        # Only set if it hasn't started yet
        if ($script:ProgressStatusText.Text -eq $script:Lang['en'].ReadyStatus -or $script:ProgressStatusText.Text -eq $script:Lang['de'].ReadyStatus) {
            $script:ProgressStatusText.Text = $dict.ReadyStatus
        }
    }
    Set-Language -LangCode $script:currentLanguage

    $script:LanguageComboBox.add_SelectionChanged({
            if ($script:LanguageComboBox.SelectedItem) {
                $script:currentLanguage = $script:LanguageComboBox.SelectedItem.Tag
                Set-Language -LangCode $script:currentLanguage
                $script:currentConfig.language = $script:currentLanguage
            }
        })

    # Pre-build cached theme brushes once — avoids allocating new objects on every theme toggle
    $script:ThemeBrushes = @{
        Light = @{
            BgColor      = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#F3F3F3"))
            PanelBgColor = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#FFFFFF"))
            FgColor      = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#1E1E1E"))
            BorderColor  = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#CCCCCC"))
            LogBgColor   = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#FAFAFA"))
        }
        Dark  = @{
            BgColor      = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#1E1E1E"))
            PanelBgColor = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#252526"))
            FgColor      = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#D4D4D4"))
            BorderColor  = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#3E3E42"))
            LogBgColor   = [System.Windows.Media.SolidColorBrush]::new([System.Windows.Media.ColorConverter]::ConvertFromString("#1E1E1E"))
        }
    }
    # Theme logic
    $script:currentTheme = if ($script:currentConfig.theme) { $script:currentConfig.theme } else { "Dark" }

    function Set-Theme {
        param([string]$Theme)
        $res = $mainAppWindow.Resources
        $brushes = $script:ThemeBrushes[$Theme]
        if (-not $brushes) { $brushes = $script:ThemeBrushes['Dark'] }
        foreach ($key in $brushes.Keys) {
            $res[$key] = $brushes[$key]
        }
    }
    Set-Theme -Theme $script:currentTheme

    $script:ThemeToggleButton.add_Click({
            $script:currentTheme = if ($script:currentTheme -eq "Dark") { "Light" } else { "Dark" }
            Set-Theme -Theme $script:currentTheme
            $script:currentConfig.theme = $script:currentTheme
        })

    # Save Settings Logic
    $script:SaveSettingsButton.add_Click({
            $timeWindowValue = 0
            if (-not ([int]::TryParse($script:TimeWindowTextBox.Text, [ref]$timeWindowValue) -and $timeWindowValue -ge 0)) {
                [System.Windows.MessageBox]::Show("Invalid Time Window. Must be non-negative integer.", "Input Error", 'OK', 'Error')
                return
            }

            $script:currentConfig.dawarichApiUrl = $script:DawarichApiUrlTextBox.Text
            $script:currentConfig.dawarichApiKey = $script:DawarichApiKeyTextBox.Text
            $script:currentConfig.photonApiUrl = $script:PhotonApiUrlTextBox.Text
            $script:currentConfig.defaultTimeWindowSeconds = $timeWindowValue
            $script:currentConfig.exiftoolPath = $script:ExiftoolPathTextBox.Text
            $script:currentConfig.overwriteExisting = [bool]$script:OverwriteCheckBox.IsChecked
            $script:currentConfig.alwaysQueryPhoton = [bool]$script:AlwaysQueryPhotonCheckBox.IsChecked
            $script:currentConfig.fallbackMethod = $script:FallbackMethodComboBox.SelectedItem.Tag
            $script:currentConfig.filenamePatterns = $script:FilenamePatternTextBox.Text
            $script:currentConfig.lastTargetFolder = $script:TargetFolderTextBox.Text
            $script:currentConfig.fileExtensions = $script:FileExtensionsTextBox.Text
        
            Save-Configuration -FilePath $script:configFilePath -ConfigData $script:currentConfig

            $script:SaveSettingsStatus.Visibility = 'Visible'
        
            # Async hide
            $timer = New-Object System.Windows.Threading.DispatcherTimer
            $timer.Interval = [TimeSpan]::FromSeconds(2)
            $timer.Add_Tick({
                    $script:SaveSettingsStatus.Visibility = 'Hidden'
                    $timer.Stop()
                }.GetNewClosure())
            $timer.Start()
        })

    # Browse Folder Logic
    $script:BrowseFolderButton.add_Click({
            $folder = Select-FolderDialog -Description $script:Lang[$script:currentLanguage].SelectFolderDesc -InitialDirectory $script:TargetFolderTextBox.Text
            if ($folder) {
                $script:TargetFolderTextBox.Text = $folder
            }
        })
    # Export Report Logic
    $script:ExportReportButton.add_Click({
            if (-not $script:LastProcessingResults -or $script:LastProcessingResults.Count -eq 0) {
                [System.Windows.MessageBox]::Show("No results found. Please run a job first.", "Export", 'OK', 'Information')
                return
            }

            $saveDialog = New-Object System.Windows.Forms.SaveFileDialog
            $saveDialog.Filter = "CSV File (*.csv)|*.csv|HTML Report (*.html)|*.html"
            $saveDialog.Title = "Export Processing Results"
            $saveDialog.FileName = "Geotag_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
            $saveDialog.InitialDirectory = if ($script:LastTargetFolder) { $script:LastTargetFolder } else { [Environment]::GetFolderPath("Desktop") }

            if ($saveDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                try {
                    if ($saveDialog.FileName -match '\.csv$') {
                        $script:LastProcessingResults | Export-Csv -Path $saveDialog.FileName -NoTypeInformation -Encoding UTF8
                    }
                    elseif ($saveDialog.FileName -match '\.html$') {
                        $htmlHead = "<style>body{font-family:sans-serif;background:#f4f4f4;color:#333;margin:20px;} table{border-collapse:collapse;width:100%;background:#fff;box-shadow:0 1px 3px rgba(0,0,0,0.2);} th,td{border:1px solid #ddd;padding:8px;text-align:left;} th{background:#0078D7;color:#fff;} tr:nth-child(even){background-color:#f9f9f9;}</style>"
                        $htmlPreContent = "<h2>Geotag Media - Processing Report</h2><p>Generated: $(Get-Date)</p>"
                        $script:LastProcessingResults | ConvertTo-Html -Head $htmlHead -PreContent $htmlPreContent | Out-File -FilePath $saveDialog.FileName -Encoding UTF8
                    }
                    [System.Windows.MessageBox]::Show("Export successful!", "Export", 'OK', 'Information')
                }
                catch {
                    [System.Windows.MessageBox]::Show("Export failed: $($_.Exception.Message)", "Error", 'OK', 'Error')
                }
            }
        })

    # Log Filter Logic
    $script:LogFilterAllBtn.add_Click({ $script:CurrentLogFilter = 'All'; Rebuild-LogDisplay })
    $script:LogFilterWarnBtn.add_Click({ $script:CurrentLogFilter = 'Warning'; Rebuild-LogDisplay })
    $script:LogFilterErrBtn.add_Click({ $script:CurrentLogFilter = 'Error'; Rebuild-LogDisplay })
    $script:LogFilterSkipBtn.add_Click({ $script:CurrentLogFilter = 'Skipped'; Rebuild-LogDisplay })

    # Pattern Tester Logic
    $script:PatternTestButton.add_Click({
            $testFilename = $script:PatternTestInputBox.Text
            $patternsText = $script:FilenamePatternTextBox.Text
            if ([string]::IsNullOrWhiteSpace($testFilename) -or [string]::IsNullOrWhiteSpace($patternsText)) {
                $script:PatternTestResult.Text = "Please enter both patterns and a filename."
                $script:PatternTestResult.Foreground = 'Orange'
                return
            }

            $patterns = $patternsText -split '`n' | Where-Object { $_.Trim() -ne "" }
            $matchFound = $false

            foreach ($pattern in $patterns) {
                $regex = $pattern.Trim()
                if ($testFilename -match $regex) {
                    $rawMatch = $matches[0]
                    # Strip all non-digit characters from the match
                    $digitsOnly = $rawMatch -replace '\D', ''
                
                    try {
                        $parsedDate = $null
                        if ($digitsOnly.Length -eq 14) {
                            $parsedDate = [datetime]::ParseExact($digitsOnly, "yyyyMMddHHmmss", [System.Globalization.CultureInfo]::InvariantCulture)
                        }
                        elseif ($digitsOnly.Length -ge 15) {
                            $parsedDate = [datetime]::ParseExact($digitsOnly.Substring(0, 14), "yyyyMMddHHmmss", [System.Globalization.CultureInfo]::InvariantCulture)
                        }

                        if ($parsedDate) {
                            $script:PatternTestResult.Text = "Match found! Pattern: $regex`nExtracted Date: $($parsedDate.ToString('yyyy-MM-dd HH:mm:ss'))"
                            $script:PatternTestResult.Foreground = 'LightGreen'
                            $matchFound = $true
                            break
                        }
                    }
                    catch {
                        # Continue checking other patterns
                    }
                }
            }

            if (-not $matchFound) {
                $script:PatternTestResult.Text = "No valid date matched from any pattern."
                $script:PatternTestResult.Foreground = 'OrangeRed'
            }
        })

    # Browse Exiftool Logic
    $script:BrowseExiftoolButton.add_Click({
            $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
            $openFileDialog.Filter = "Executable files (*.exe)|*.exe|All files (*.*)|*.*"
            $openFileDialog.Title = "Select exiftool.exe"
            if ($script:ExiftoolPathTextBox.Text -and (Test-Path $script:ExiftoolPathTextBox.Text)) {
                $openFileDialog.InitialDirectory = Split-Path -Path $script:ExiftoolPathTextBox.Text
            }
            if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $script:ExiftoolPathTextBox.Text = $openFileDialog.FileName
            }
        })

    # Test Dawarich API Logic
    $script:TestDawarichButton.add_Click({
            $url = $script:DawarichApiUrlTextBox.Text.TrimEnd('/')
            $key = $script:DawarichApiKeyTextBox.Text
            if (-not $url) { return }
            try {
                # Minimal endpoint check for Dawarich using the exact format the script uses
                $testUrl = "$url`?api_key=$key"
                $response = Invoke-RestMethod -Uri $testUrl -Method Get -ErrorAction Stop
                $script:DawarichStatusDot.Fill = [System.Windows.Media.Brushes]::Green
                [System.Windows.MessageBox]::Show($script:Lang[$script:currentLanguage].ApiTestSuccess, $script:Lang[$script:currentLanguage].ApiTestTitle, 'OK', 'Information')
            }
            catch {
                $script:DawarichStatusDot.Fill = [System.Windows.Media.Brushes]::Red
                $msg = $script:Lang[$script:currentLanguage].ApiTestFailed -f $_.Exception.Message
                [System.Windows.MessageBox]::Show($msg, $script:Lang[$script:currentLanguage].ApiTestTitle, 'OK', 'Error')
            }
        })

    # Test Photon API Logic
    $script:TestPhotonButton.add_Click({
            $url = $script:PhotonApiUrlTextBox.Text.TrimEnd('/')
            if (-not $url) { return }
            try {
                $response = Invoke-RestMethod -Uri "$url/api?q=Berlin" -Method Get -ErrorAction Stop
                $script:PhotonStatusDot.Fill = [System.Windows.Media.Brushes]::Green
                [System.Windows.MessageBox]::Show($script:Lang[$script:currentLanguage].ApiTestSuccess, $script:Lang[$script:currentLanguage].ApiTestTitle, 'OK', 'Information')
            }
            catch {
                $script:PhotonStatusDot.Fill = [System.Windows.Media.Brushes]::Red
                $msg = $script:Lang[$script:currentLanguage].ApiTestFailed -f $_.Exception.Message
                [System.Windows.MessageBox]::Show($msg, $script:Lang[$script:currentLanguage].ApiTestTitle, 'OK', 'Error')
            }
        })

    # Cancel Button Logic
    $script:CancelProcessingButton.add_Click({
        $script:CancelProcessing = $true
        $script:CancelProcessingButton.IsEnabled = $false
        $script:CancelProcessingText.Text = "Cancelling..."
    })

    # Start Processing Logic
    $script:StartProcessingButton.add_Click({
            $targetFolder = $script:TargetFolderTextBox.Text
            if (-not $targetFolder -or -not (Test-Path $targetFolder -PathType Container)) {
                [System.Windows.MessageBox]::Show("Please select a valid folder.", "Invalid Folder", 'OK', 'Warning')
                return
            }

            # Validate Exiftool
            $exiftoolPathToCheck = $script:ExiftoolPathTextBox.Text
            $exiftoolFound = $false
            $resolvedExiftoolPath = $exiftoolPathToCheck
            if (Test-Path $exiftoolPathToCheck -PathType Leaf) {
                $resolvedExiftoolPath = (Get-Item $exiftoolPathToCheck).FullName
                $exiftoolFound = $true
            }
            else {
                $chkPath = Get-Command $exiftoolPathToCheck -ErrorAction SilentlyContinue
                if ($chkPath) {
                    $resolvedExiftoolPath = $chkPath.Source 
                    $script:currentConfig.exiftoolPath = $resolvedExiftoolPath
                    $script:ExiftoolPathTextBox.Text = $resolvedExiftoolPath
                    $exiftoolFound = $true
                }
            }

            if (-not $exiftoolFound) {
                [System.Windows.MessageBox]::Show("Exiftool not found at '$exiftoolPathToCheck' or in PATH.", "Exiftool Error", 'OK', 'Error')
                return 
            }

            # Update Config from UI Checkboxes
            if ($null -ne $script:DryRunCheckBox) {
                $script:currentConfig.dryRun = [bool]$script:DryRunCheckBox.IsChecked
            }
            if ($null -ne $script:RecursiveCheckBox) {
                $script:currentConfig.recursive = [bool]$script:RecursiveCheckBox.IsChecked
            }
            if ($null -ne $script:PhotonOnlyCheckBox) {
                $script:currentConfig.photonOnly = [bool]$script:PhotonOnlyCheckBox.IsChecked
            }

            # Clear logs
            $script:LogParagraph.Inlines.Clear()
            if ($null -ne $script:LogEntries) { $script:LogEntries.Clear() }
        
            # Save config implicitly
            $script:currentConfig.lastTargetFolder = $targetFolder
            Save-Configuration -FilePath $script:configFilePath -ConfigData $script:currentConfig
        
            $script:StartProcessingButton.IsEnabled = $false
            $script:BrowseFolderButton.IsEnabled = $false
            $script:SaveSettingsButton.IsEnabled = $false
            
            # Enable Cancel button and reset text
            $script:CancelProcessingButton.IsEnabled = $true
            $dict = $script:Lang[$script:currentLanguage]
            $script:CancelProcessingText.Text = $dict.CancelBtn
            $script:CancelProcessing = $false
        
            # Process in UI thread but allow UI to update
            try {
                Invoke-FileProcessing -TargetFolder $targetFolder -Config $script:currentConfig
            }
            catch {
                Show-ConsoleProgress -StatusMessage "Fatal Error: $($_.Exception.Message)" -MessageColor Red
            }
            finally {
                $script:StartProcessingButton.IsEnabled = $true
                $script:BrowseFolderButton.IsEnabled = $true
                $script:SaveSettingsButton.IsEnabled = $true
                
                # Disable Cancel button and reset text
                $script:CancelProcessingButton.IsEnabled = $false
                $dict = $script:Lang[$script:currentLanguage]
                $script:CancelProcessingText.Text = $dict.CancelBtn
                
                if ($script:CancelProcessing) {
                    $script:ProgressStatusText.Text = $dict.ProcessingAborted
                } else {
                    $script:ProgressStatusText.Text = $dict.SummaryFinished
                }
            }
        })

    # Initial ExifTool check at startup
    $exiftoolPathToCheck = $script:currentConfig.exiftoolPath
    $chkPath = $null
    if (Test-Path $exiftoolPathToCheck -PathType Leaf) {
        $chkPath = Get-Item $exiftoolPathToCheck
    }
    else {
        $chkPath = Get-Command $exiftoolPathToCheck -ErrorAction SilentlyContinue
    }
    
    if ($chkPath) {
        try {
            $exePath = $null
            if ($null -ne $chkPath.FullName) {
                $exePath = $chkPath.FullName
            }
            elseif ($null -ne $chkPath.Source) {
                $exePath = $chkPath.Source
            }
            else {
                $exePath = $chkPath.ToString()
            }

            $verOutput = & $exePath -ver 2>&1
            if ($verOutput -match "^\d+\.\d+") {
                $verClean = $verOutput.Trim()
                $script:ExiftoolVersionBar.Text = "ExifTool: $verClean"
                $script:ExiftoolVersionBar.Foreground = $mainAppWindow.FindResource("FgColor")
                $script:ExiftoolVersionText.Text = $verClean
                $script:ExiftoolVersionText.Foreground = $mainAppWindow.FindResource("FgColor")
            }
            else {
                $script:ExiftoolVersionBar.Text = "ExifTool: Invalid"
                $script:ExiftoolVersionBar.Foreground = $mainAppWindow.FindResource("ErrorColor")
                $script:ExiftoolVersionText.Text = "Invalid Output"
                $script:ExiftoolVersionText.Foreground = $mainAppWindow.FindResource("ErrorColor")
            }
        }
        catch {
            $script:ExiftoolVersionBar.Text = "ExifTool: Error"
            $script:ExiftoolVersionBar.Foreground = $mainAppWindow.FindResource("ErrorColor")
            $script:ExiftoolVersionText.Text = "Execution Error"
            $script:ExiftoolVersionText.Foreground = $mainAppWindow.FindResource("ErrorColor")
        }
    }
    else {
        $script:ExiftoolVersionBar.Text = "ExifTool: Not Found"
        $script:ExiftoolVersionBar.Foreground = $mainAppWindow.FindResource("ErrorColor")
        $script:ExiftoolVersionText.Text = "Not Found"
        $script:ExiftoolVersionText.Foreground = $mainAppWindow.FindResource("ErrorColor")
    }

    $mainAppWindow.add_Closed({
            Stop-ExifDaemon
        })

    $mainAppWindow.ShowDialog() | Out-Null
}

# Log entry buffer — all entries stored here; rebuilt on filter change
$script:LogEntries = [System.Collections.Generic.List[hashtable]]::new()
$script:CurrentLogFilter = 'All'

function Show-ConsoleProgress {
    param(
        [int]$CurrentFileIndex = 0,
        [int]$TotalFiles = 0,
        [string]$StatusMessage = "",
        [string]$MessageColor = 'FgColor',
        [string]$Category = 'Info'  # Info | Warning | Error | Skipped
    )

    $timestamp = Get-Date -Format "HH:mm:ss"
    $fullMsg = "[$timestamp] $StatusMessage`n"

    $colorKey = switch ($MessageColor.ToLower()) {
        'red' { 'ErrorColor' }
        'yellow' { 'WarningColor' }
        'green' { 'SuccessColor' }
        default { 'FgColor' }
    }

    # Normalise category from colour if caller did not set it
    if ($Category -eq 'Info') {
        if ($MessageColor -eq 'Red') { $Category = 'Error' }
        elseif ($MessageColor -eq 'Yellow') { $Category = 'Warning' }
    }

    # Store in buffer
    $entry = @{ Text = $fullMsg; ColorKey = $colorKey; Category = $Category }
    if ($null -ne $script:LogEntries) { $script:LogEntries.Add($entry) }

    if (-not $script:LogParagraph) { Write-Host $StatusMessage; return }

    $action = [Action] {
        if ($TotalFiles -gt 0) {
            $pct = ($CurrentFileIndex / $TotalFiles) * 100
            $script:MainProgressBar.Value = $pct
            $script:ProgressPercentText.Text = "$([int]$pct)%"
            $script:ProgressStatusText.Text = "$CurrentFileIndex / $TotalFiles"
        }
        # Only add to FlowDocument if matches current filter
        $show = ($script:CurrentLogFilter -eq 'All') -or ($Category -eq $script:CurrentLogFilter)
        if ($show) {
            $run = New-Object System.Windows.Documents.Run($fullMsg)
            $run.SetResourceReference([System.Windows.Documents.TextElement]::ForegroundProperty, $colorKey)
            $script:LogParagraph.Inlines.Add($run)
            $script:LogRichTextBox.ScrollToEnd()
        }
    }
    $action.Invoke()
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke(
        [System.Windows.Threading.DispatcherPriority]::Background, [Action] {})
}

function Rebuild-LogDisplay {
    # Clears the FlowDocument and re-populates from the buffer using the current filter
    if (-not $script:LogParagraph) { return }
    $script:LogParagraph.Inlines.Clear()
    foreach ($entry in $script:LogEntries) {
        $show = ($script:CurrentLogFilter -eq 'All') -or ($entry.Category -eq $script:CurrentLogFilter)
        if ($show) {
            $run = New-Object System.Windows.Documents.Run($entry.Text)
            $run.SetResourceReference([System.Windows.Documents.TextElement]::ForegroundProperty, $entry.ColorKey)
            $script:LogParagraph.Inlines.Add($run)
        }
    }
    $script:LogRichTextBox.ScrollToEnd()
}

#region Helper Functions (Core Logic)
function Select-FolderDialog {
    param(
        [string]$Description = "Select Folder", 
        [string]$InitialDirectory = $null 
    )

    $folderBrowser = New-Object System.Windows.Forms.OpenFileDialog
    $folderBrowser.ValidateNames = $false
    $folderBrowser.CheckFileExists = $false
    $folderBrowser.CheckPathExists = $true
    $folderBrowser.FileName = "Folder Selection."
    $folderBrowser.Title = $Description
    if (-not [string]::IsNullOrEmpty($InitialDirectory) -and (Test-Path $InitialDirectory -PathType Container)) {
        $folderBrowser.InitialDirectory = $InitialDirectory
    }

    # Show the dialog directly without the hidden owner form
    $dialogResult = $folderBrowser.ShowDialog()

    if ($dialogResult -eq [System.Windows.Forms.DialogResult]::OK) {
        $selectedPath = Split-Path -Path $folderBrowser.FileName
        if (Test-Path $selectedPath -PathType Container) {
            return $selectedPath
        } else {
            return $null
        }
    }
    else {
        Write-Warning "Folder selection cancelled by user or failed."
        return $null 
    }
}

function Get-DiscoveryDate {
    param(
        [System.IO.FileInfo]$File,
        [PSObject]$ExifData,
        [string]$FallbackMethod,
        [string]$PatternsString
    )
    
    $foundDate = $null
    $source = "None"

    # Step 1: Always check EXIF first (EXIF is always the primary source)
    # Use explicit if-chain — PowerShell's -or returns a boolean, not the value
    $exifDate = $ExifData.DateTimeOriginal
    if ([string]::IsNullOrWhiteSpace($exifDate)) { $exifDate = $ExifData.CreateDate }
    if ([string]::IsNullOrWhiteSpace($exifDate)) { $exifDate = $ExifData.MediaCreateDate }
    if ([string]::IsNullOrWhiteSpace($exifDate)) { $exifDate = $ExifData.TrackCreateDate }
    
    if (-not [string]::IsNullOrWhiteSpace($exifDate)) {
        $foundDate = ConvertTo-ApiTimestamp -ExifDateTimeString $exifDate
        if ($foundDate) { $source = "Exif" }
    }
    
    # Step 2: Fallback if EXIF failed
    if ($null -eq $foundDate) {
        if ($FallbackMethod -eq "Filename" -and $PatternsString) {
            # Split by newlines (multi-line TextBox format)
            $patterns = $PatternsString -split "`r`n|`n|`r" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            foreach ($p in $patterns) {
                $p = $p.Trim()
                if ($File.Name -match $p) {
                    try {
                        if ($Matches.Count -ge 2) {
                            $dateStr = $Matches[1] -replace '\D', ''
                            $timeStr = (if ($Matches.Count -ge 3) { $Matches[2] } else { "000000" }) -replace '\D', ''
                            
                            $dateFmt = if ($dateStr.Length -eq 6) { "yyMMdd" } elseif ($dateStr.Length -eq 8) { "yyyyMMdd" } else { "yyyyMMdd" }
                            
                            # Truncate or pad time to 6 digits (HHmmss)
                            if ($timeStr.Length -gt 6) { $timeStr = $timeStr.Substring(0, 6) }
                            elseif ($timeStr.Length -lt 6) { $timeStr = $timeStr.PadRight(6, '0') }
                            
                            $dt = [datetime]::ParseExact("$dateStr$timeStr", "$dateFmt" + "HHmmss", $null)
                            $foundDate = $dt.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
                            $source = "Filename ($p)"
                            break
                        }
                    }
                    catch {
                        Write-Verbose "Filename date parse fail for pattern '$p': $($_.Exception.Message)"
                    }
                }
            }
        }
        elseif ($FallbackMethod -eq "FileSystem") {
            $foundDate = $File.CreationTime.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
            $source = "FileSystem"
        }
    }

    return @{ Date = $foundDate; Source = $source }
}

function ConvertTo-ApiTimestamp {
    param([string]$ExifDateTimeString)
    if ([string]::IsNullOrWhiteSpace($ExifDateTimeString)) { return $null }
    $ExifDateTimeString = $ExifDateTimeString -replace '([+-]\d{2}):(\d{2})$', '$1$2' 
    $cleanedString = $ExifDateTimeString.Split('.')[0] 
    $cleanedString = ($cleanedString -replace ":", "-") -replace " ", "T" 
    $formats = @("yyyy-MM-ddTHH-mm-ss", "yyyy-MM-ddTHH-mm-sszzz", "yyyy-MM-ddTHH-mm-ssZ"); $parsedDate = $null
    foreach ($format in $formats) { try { $style = [System.Globalization.DateTimeStyles]::None; if ($format.EndsWith("zzz")) { $style = [System.Globalization.DateTimeStyles]::AdjustToUniversal }elseif ($format.EndsWith("Z")) { $style = [System.Globalization.DateTimeStyles]::AssumeUniversal }; $parsedDate = [datetime]::ParseExact($cleanedString, $format, [System.Globalization.CultureInfo]::InvariantCulture, $style); break }catch { Write-Verbose "Parse fail '$cleanedString' fmt '$format': $($_.Exception.Message)" } }
    if ($parsedDate) { try { if ($parsedDate.Kind -eq [System.DateTimeKind]::Unspecified) { $parsedDate = [DateTime]::SpecifyKind($parsedDate, [DateTimeKind]::Local) }; return $parsedDate.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") }catch { Write-Warning "Date convert error '$ExifDateTimeString': $($_.Exception.Message)"; return $null } }else { Write-Warning "Cannot parse date '$ExifDateTimeString'"; return $null }
}

function Convert-SexagesimalToDecimal {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CoordinateString,
        [Parameter(Mandatory = $true)]
        [string]$Hemisphere # N, S, E, W
    )
    try {
        $cleanedString = $CoordinateString -replace "deg|'" -replace '"', ''
        $parts = $cleanedString -split '[^0-9\.]+' | Where-Object { $_ -ne "" }
        
        if ($parts.Count -lt 1) { 
            Write-Warning "Could not parse sexagesimal coordinate: $CoordinateString (cleaned: $cleanedString)"
            return $null 
        }

        $degrees = 0.0
        $minutes = 0.0
        $seconds = 0.0

        if ($parts.Count -ge 1) { [void][double]::TryParse($parts[0], [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$degrees) }
        if ($parts.Count -ge 2) { [void][double]::TryParse($parts[1], [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$minutes) }
        if ($parts.Count -ge 3) { [void][double]::TryParse($parts[2], [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$seconds) }

        $decimalDegrees = $degrees + ($minutes / 60.0) + ($seconds / 3600.0)

        if ($Hemisphere -eq 'S' -or $Hemisphere -eq 'W') {
            $decimalDegrees = - $decimalDegrees
        }
        return $decimalDegrees
    }
    catch {
        Write-Warning "Error converting sexagesimal coordinate '$CoordinateString' ($Hemisphere): $($_.Exception.Message)"
        return $null
    }
}


function Get-DawarichDataFromApi {
    param([string]$BaseUrl, [string]$ApiKey, [string]$StartAt, [string]$EndAt) 
    $encodedStartAt = [System.Web.HttpUtility]::UrlEncode($StartAt)
    $encodedEndAt = [System.Web.HttpUtility]::UrlEncode($EndAt)
    $apiUrlEffective = "$BaseUrl`?api_key=$ApiKey`&start_at=$encodedStartAt`&end_at=$encodedEndAt`&order=asc"
    # Redact key from log display
    $logUrl = "$BaseUrl`?api_key=***`&start_at=$encodedStartAt`&end_at=$encodedEndAt`&order=asc"
    Show-ConsoleProgress -StatusMessage "Querying Dawarich API: $logUrl" -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress
    try { $response = Invoke-RestMethod -Uri $apiUrlEffective -Method Get -TimeoutSec 120 -ErrorAction Stop; return $response }
    catch {
        $errMsg = "Dawarich API Error ($apiUrlEffective): $($_.Exception.Message)"
        Write-Error $errMsg
        Show-ConsoleProgress -StatusMessage "[ERROR] $errMsg" -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress -MessageColor Red
        if ($_.Exception.Response) { try { $s = $_.Exception.Response.GetResponseStream(); $r = New-Object System.IO.StreamReader($s); $body = $r.ReadToEnd(); Write-Error "API Body: $body"; Show-ConsoleProgress -StatusMessage "[ERROR] API Response Body: $body" -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress -MessageColor Red }catch { Write-Error "No error body."; Show-ConsoleProgress -StatusMessage "[ERROR] Could not read error response body." -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress -MessageColor Red } }; return $null
    }
}

function Get-LocationFromPhoton {
    param([string]$BaseUrl, [double]$Latitude, [double]$Longitude) 
    $latStr = $Latitude.ToString([System.Globalization.CultureInfo]::InvariantCulture); $lonStr = $Longitude.ToString([System.Globalization.CultureInfo]::InvariantCulture)
    $photonReverseUrl = "$BaseUrl/reverse?lat=$latStr&lon=$lonStr"
    Show-ConsoleProgress -StatusMessage "Querying Photon API: $photonReverseUrl" -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress
    try {
        $response = Invoke-RestMethod -Uri $photonReverseUrl -Method Get -TimeoutSec 60 -ErrorAction Stop
        $country = $null; $city = $null; $countryCode = $null; $state = $null
        if ($response.features -ne $null -and $response.features.Count -gt 0) {
            $props = $response.features[0].properties
            if ($props -ne $null) {
                $country = $props.country
                $city = $props.city
                $countryCode = $props.countrycode
                $state = $props.state 
                if ([string]::IsNullOrWhiteSpace($city)) { $city = $props.county }
                if ([string]::IsNullOrWhiteSpace($city)) { $city = $props.name } 
            }
        }
        else {
            Write-Verbose "Photon reverse geocoding returned no features for ($Latitude, $Longitude)."
            Show-ConsoleProgress -StatusMessage "[WARNING] Photon API response did not contain 'features' data." -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress -MessageColor Yellow
        }
        return @{Country = $country; City = $city; CountryCode = $countryCode; State = $state } 
    }
    catch {
        $errMsg = "Photon API Error ($photonReverseUrl): $($_.Exception.Message)"
        Write-Error $errMsg
        Show-ConsoleProgress -StatusMessage "[ERROR] $errMsg" -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress -MessageColor Red
        if ($_.Exception.Response) { try { $s = $_.Exception.Response.GetResponseStream(); $r = New-Object System.IO.StreamReader($s); $body = $r.ReadToEnd(); Write-Error "API Body: $body"; Show-ConsoleProgress -StatusMessage "[ERROR] Photon API Response Body: $body" -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress -MessageColor Red }catch { Write-Error "No error body."; Show-ConsoleProgress -StatusMessage "[ERROR] Could not read Photon error response body." -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress -MessageColor Red } }; return $null
    }
}

function Test-DawarichResultIsValid {
    param(
        $Result 
    )
    if ($null -eq $Result) { return $false }
    if (-not ($Result.PSObject.Properties.Name -contains 'latitude' -and $Result.PSObject.Properties.Name -contains 'longitude')) {
        Write-Verbose "Test-DawarichResultIsValid: Missing latitude or longitude property."
        return $false
    }
    if ($Result.latitude -eq $null -or $Result.longitude -eq $null) {
        Write-Verbose "Test-DawarichResultIsValid: Latitude ('$($Result.latitude)') or Longitude ('$($Result.longitude)') is null."
        return $false
    }
    $latC = 0.0; $lonC = 0.0
    $latParsed = [double]::TryParse($Result.latitude.ToString(), [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$latC)
    $lonParsed = [double]::TryParse($Result.longitude.ToString(), [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$lonC)
    if ($latParsed -and $lonParsed -and ($latC -ne 0.0 -or $lonC -ne 0.0)) {
        Write-Verbose "Test-DawarichResultIsValid: Valid non-zero coordinates found (Lat: $latC, Lon: $lonC)."
        return $true
    }
    else {
        Write-Verbose "Test-DawarichResultIsValid: Parsing failed OR coordinates are (0,0). LatParsed: $latParsed, LonParsed: $lonParsed, LatValue: $latC, LonValue: $lonC"
        return $false
    }
}

function Parse-DawarichTimestamp {
    param(
        $TimestampInput
    )

    if ($null -eq $TimestampInput) {
        Write-Warning "Dawarich timestamp is missing."
        Show-ConsoleProgress -StatusMessage "[WARNING] Dawarich timestamp is missing." -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress -MessageColor Yellow
        return $null
    }

    # Integer/long: Unix epoch seconds
    if ($TimestampInput -is [long] -or $TimestampInput -is [int]) {
        try {
            return [datetimeoffset]::FromUnixTimeSeconds($TimestampInput).UtcDateTime
        }
        catch {
            Write-Warning "Dawarich Unix timestamp parse fail: $TimestampInput. Error: $($_.Exception.Message)"
            Show-ConsoleProgress -StatusMessage "[WARNING] Dawarich Unix timestamp parse fail: $TimestampInput" -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress -MessageColor Yellow
            return $null
        }
    }

    # String: try all ISO-8601 variants without exceptions (TryParseExact array overload)
    if ($TimestampInput -is [string]) {
        $tsFormats = [string[]]@(
            "yyyy-MM-ddTHH:mm:ssZ", "yyyy-MM-ddTHH:mm:ss.fZ", "yyyy-MM-ddTHH:mm:ss.ffZ",
            "yyyy-MM-ddTHH:mm:ss.fffZ", "yyyy-MM-ddTHH:mm:ss.ffffZ", "yyyy-MM-ddTHH:mm:ss.fffffZ",
            "yyyy-MM-ddTHH:mm:ss.ffffffZ", "yyyy-MM-ddTHH:mm:ss.fffffffZ"
        )
        $parsedDateTime = [datetime]::MinValue
        $dateStyle = [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal
        $ok = [datetime]::TryParseExact(
            $TimestampInput,
            $tsFormats,
            [System.Globalization.CultureInfo]::InvariantCulture,
            $dateStyle,
            [ref]$parsedDateTime
        )
        if ($ok) { return $parsedDateTime }

        Write-Warning "Dawarich string timestamp parse fail for all formats: $TimestampInput"
        Show-ConsoleProgress -StatusMessage "[WARNING] Dawarich string timestamp parse fail: $TimestampInput" -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress -MessageColor Yellow
        return $null
    }

    # Unknown type
    Write-Warning "Unknown Dawarich timestamp type: $($TimestampInput.GetType().FullName)"
    Show-ConsoleProgress -StatusMessage "[WARNING] Unknown Dawarich timestamp type: $($TimestampInput.GetType().FullName)" -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress -MessageColor Yellow
    return $null
}

#region ExifTool Daemon Management
function Start-ExifDaemon {
    param([string]$ExiftoolExePath)
    if ($script:ExifDaemonProcess -ne $null -and -not $script:ExifDaemonProcess.HasExited) { return }

    $pInfo = New-Object System.Diagnostics.ProcessStartInfo
    $pInfo.FileName = $ExiftoolExePath
    $pInfo.Arguments = "-stay_open True -@ -"   # Read args from stdin (reliable, no file-locking issues)
    $pInfo.RedirectStandardInput = $true
    $pInfo.RedirectStandardOutput = $true
    $pInfo.RedirectStandardError = $true
    $pInfo.UseShellExecute = $false
    $pInfo.CreateNoWindow = $true
    $pInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $pInfo.StandardErrorEncoding = [System.Text.Encoding]::UTF8

    $script:ExifDaemonProcess = New-Object System.Diagnostics.Process
    $script:ExifDaemonProcess.StartInfo = $pInfo
    $script:ExifDaemonProcess.Start() | Out-Null

    # Async stderr collection via compiled C# handler — fires on .NET ThreadPool thread,
    # not the PowerShell pipeline thread, so it works even during synchronous processing.
    $script:StderrCollector = New-Object ExifStderrCollector
    $script:ExifDaemonProcess.add_ErrorDataReceived(
        $script:StderrCollector.Delegate
    )
    $script:ExifDaemonProcess.BeginErrorReadLine()

    # Create a reusable runspace for background stdout reading (avoids per-file runspace overhead)
    $script:ExifReaderRunspace = [runspacefactory]::CreateRunspace()
    $script:ExifReaderRunspace.Open()
}

function Stop-ExifDaemon {
    if ($script:ExifDaemonProcess -ne $null) {
        if (-not $script:ExifDaemonProcess.HasExited) {
            try {
                $script:ExifDaemonProcess.StandardInput.WriteLine("-stay_open")
                $script:ExifDaemonProcess.StandardInput.WriteLine("False")
                $script:ExifDaemonProcess.StandardInput.Flush()
                $script:ExifDaemonProcess.StandardInput.Close()
            } catch { <# stdin may already be closed #> }
            $script:ExifDaemonProcess.WaitForExit(3000)
            if (-not $script:ExifDaemonProcess.HasExited) { $script:ExifDaemonProcess.Kill() }
        }
        try { $script:ExifDaemonProcess.CancelErrorRead() } catch { }
        $script:ExifDaemonProcess.Close()
        $script:ExifDaemonProcess = $null
    }
    if ($script:ExifReaderRunspace -ne $null) {
        try { $script:ExifReaderRunspace.Close() } catch { }
        $script:ExifReaderRunspace = $null
    }
    $script:StderrCollector = $null
}

function Invoke-ExifDaemon {
    param([string[]]$ArgsArray)
    if ($script:ExifDaemonProcess -eq $null -or $script:ExifDaemonProcess.HasExited) {
        throw "ExifDaemon is not running."
    }

    # Write args to ExifTool via stdin (one argument per line, -execute to flush)
    foreach ($arg in $ArgsArray) {
        $script:ExifDaemonProcess.StandardInput.WriteLine($arg)
    }
    $script:ExifDaemonProcess.StandardInput.WriteLine("-execute")
    $script:ExifDaemonProcess.StandardInput.Flush()

    # Read stdout in a BACKGROUND RUNSPACE so the UI thread is never blocked.
    # The blocking ReadLine() call happens on the runspace's thread; we pump
    # the WPF dispatcher on the UI thread while polling for completion.
    $ps = [powershell]::Create()
    $ps.Runspace = $script:ExifReaderRunspace
    $ps.AddScript({
        param($process)
        $lines = [System.Collections.Generic.List[string]]::new()
        while ($true) {
            $line = $process.StandardOutput.ReadLine()
            if ($null -eq $line) { break }          # stream closed (process exited)
            if ($line.Trim() -eq '{ready}') { break } # ExifTool finished this command
            $lines.Add($line)
        }
        return ($lines -join "`n")
    }).AddArgument($script:ExifDaemonProcess) | Out-Null

    $asyncResult = $ps.BeginInvoke()

    # Pump the WPF dispatcher while waiting — keeps buttons, cancel, and progress alive
    while (-not $asyncResult.IsCompleted) {
        [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke(
            [System.Windows.Threading.DispatcherPriority]::Background, [Action] {})
        Start-Sleep -Milliseconds 20
    }

    $stdoutResult = ""
    try {
        $output = $ps.EndInvoke($asyncResult)
        if ($output.Count -gt 0) { $stdoutResult = $output[0] }
    } catch {
        Write-Warning "ExifDaemon stdout read error: $($_.Exception.Message)"
    }
    $ps.Dispose()

    # Drain any stderr lines collected by the async C# handler
    $stderrResult = ""
    if ($script:StderrCollector) {
        $stderrResult = $script:StderrCollector.DrainAll()
    }

    return @{ StdOut = $stdoutResult; StdErr = $stderrResult }
}
#endregion

function Set-ExifData {
    param(
        [string]$ExiftoolExePath,
        [string]$FilePath,
        [double]$Latitude,
        [double]$Longitude,
        [string]$Country, 
        [string]$City,    
        [string]$CountryCode,
        [string]$State,
        [string]$DiscoveryDate
    )
    $fileInfo = Get-Item -LiteralPath $FilePath; $isMp4 = $fileInfo.Extension.ToLower() -eq ".mp4"
    $tagArgs = @(); $exifArgs = @(); $outputTargetDescription = ""

    if ($isMp4) {
        $outputTargetDescription = "GPS (Google Photos format) and Creation Date into MP4 '$($fileInfo.Name)'"
        $latF = ([Math]::Abs($Latitude)).ToString("F4", [System.Globalization.CultureInfo]::InvariantCulture); $lonF = ([Math]::Abs($Longitude)).ToString("F4", [System.Globalization.CultureInfo]::InvariantCulture)
        $latS = if ($Latitude -ge 0) { "+" }else { "-" }; $lonS = if ($Longitude -ge 0) { "+" }else { "-" }
        $udGpsStr = '{0}{1}, {2}{3}, 0' -f $latS, $latF, $lonS, $lonF
        $tagArgs = @("-UserData:GPSCoordinates=$udGpsStr", "-GPSAltitude=0", "-GPSAltitudeRef=0") 
        if ($DiscoveryDate) {
            try {
                $exifFmt = [datetime]::ParseExact($DiscoveryDate, "yyyy-MM-ddTHH:mm:ssZ", $null).ToString("yyyy:MM:dd HH:mm:ss")
                $tagArgs += "-CreateDate=$exifFmt"
                $tagArgs += "-MediaCreateDate=$exifFmt"
                $tagArgs += "-TrackCreateDate=$exifFmt"
                $outputTargetDescription = "GPS and Creation Date ($exifFmt) into MP4 '$($fileInfo.Name)'"
            }
            catch { Write-Warning "Could not format DiscoveryDate '$DiscoveryDate' for EXIF." }
        }
        $exifArgs += "-overwrite_original"; $exifArgs += $tagArgs; $exifArgs += $FilePath
    }
    else { 
        $outputTargetDescription = "metadata and Creation Date directly into image file '$($fileInfo.Name)'"
        $latRef = if ($Latitude -ge 0) { "N" }else { "S" }; $lonRef = if ($Longitude -ge 0) { "E" }else { "W" }
        $latAbs = [Math]::Abs($Latitude).ToString([System.Globalization.CultureInfo]::InvariantCulture); $lonAbs = [Math]::Abs($Longitude).ToString([System.Globalization.CultureInfo]::InvariantCulture)
        $tagArgs = @("-GPSLatitude=$latAbs", "-GPSLatitudeRef=$latRef", "-GPSLongitude=$lonAbs", "-GPSLongitudeRef=$lonRef", "-XMP:GPSLatitude=$latAbs", "-XMP:GPSLongitude=$lonAbs")
        if (-not[string]::IsNullOrWhiteSpace($Country)) { $tagArgs += "-Country=$Country" }
        if (-not[string]::IsNullOrWhiteSpace($City)) { $tagArgs += "-City=$City" }
        if (-not[string]::IsNullOrWhiteSpace($CountryCode)) { $tagArgs += "-XMP-iptcCore:CountryCode=$CountryCode" }
        if (-not[string]::IsNullOrWhiteSpace($State)) { $tagArgs += "-XMP-photoshop:State=$State" } 
        if ($DiscoveryDate) {
            try {
                $exifFmt = [datetime]::ParseExact($DiscoveryDate, "yyyy-MM-ddTHH:mm:ssZ", $null).ToString("yyyy:MM:dd HH:mm:ss")
                $tagArgs += "-DateTimeOriginal=$exifFmt"
                $tagArgs += "-CreateDate=$exifFmt"
                $outputTargetDescription = "metadata and Creation Date ($exifFmt) directly into image file '$($fileInfo.Name)'"
            }
            catch { Write-Warning "Could not format DiscoveryDate '$DiscoveryDate' for EXIF." }
        }
        $exifArgs += "-overwrite_original"; $exifArgs += $tagArgs; $exifArgs += $FilePath
    }

    try {
        $cmdLog = "$ExiftoolExePath $($exifArgs -join ' ')"
        Show-ConsoleProgress -StatusMessage "Executing exiftool write to $outputTargetDescription" -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress
        Show-ConsoleProgress -StatusMessage "Command: $cmdLog" -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress

        $exifOutHash = Invoke-ExifDaemon -ArgsArray $exifArgs
        $stdOut = $exifOutHash.StdOut
        $stdErr = $exifOutHash.StdErr

        $successPattern = '1 image files updated|1 output files created|1 video files updated|1 image files created|1 files updated'
        $warningPattern = 'Nothing to write|0 image files updated|0 output files created|0 video files updated|File not changed'

        $isSuccess = ($stdOut -match $successPattern) -or ($stdErr -match $successPattern)
        $isWarning = ($stdOut -match $warningPattern) -or ($stdErr -match $warningPattern)

        if ($isSuccess) {
            $successMsg = "Metadata written to $outputTargetDescription."
            Write-Host "     -> $successMsg" -ForegroundColor Green
            Show-ConsoleProgress -StatusMessage $successMsg -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress -MessageColor Green
            if (-not [string]::IsNullOrWhiteSpace($stdOut) -and $stdOut -notmatch $successPattern) {
                Write-Verbose "Exiftool out: $stdOut"
                Show-ConsoleProgress -StatusMessage "Exiftool output: $stdOut" -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress
            }
            if (-not [string]::IsNullOrWhiteSpace($stdErr) -and $stdErr -notmatch $successPattern) {
                Write-Warning "Exiftool warn: $stdErr"
                Show-ConsoleProgress -StatusMessage "[WARNING] Exiftool warnings: $stdErr" -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress -MessageColor Yellow
            }
            return $true
        }
        elseif ($isWarning) {
            $warnMsg = "No changes needed for $outputTargetDescription (tags identical)."
            Write-Host "     -> $warnMsg" -ForegroundColor Yellow
            Show-ConsoleProgress -StatusMessage "[WARNING] $warnMsg" -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress -MessageColor Yellow
            if (-not [string]::IsNullOrWhiteSpace($stdErr) -and $stdErr -notmatch $warningPattern) {
                Write-Warning "Exiftool warnings: $stdErr"
                Show-ConsoleProgress -StatusMessage "[WARNING] Exiftool warnings: $stdErr" -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress -MessageColor Yellow
            }
            return $true
        }
        else {
            $errContent = if (-not [string]::IsNullOrWhiteSpace($stdErr)) { $stdErr } else { $stdOut }
            $errMsg = "Exiftool write error for ${outputTargetDescription}. Details: $errContent"
            Write-Error $errMsg
            Show-ConsoleProgress -StatusMessage "[ERROR] $errMsg" -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress -MessageColor Red
            return $false
        }
    }
    catch {
        $errMsg = "Exiftool exec error for ${outputTargetDescription}: $($_.Exception.Message)"
        Write-Error $errMsg
        Show-ConsoleProgress -StatusMessage "[ERROR] $errMsg" -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress -MessageColor Red
        return $false
    }
}
#endregion

#region New Helper Functions
function Export-ProcessingReport {
    param(
        [string]$TargetFolder,
        [System.Collections.Generic.List[hashtable]]$Results
    )
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $csvPath = Join-Path $TargetFolder "geotag_report_$timestamp.csv"
    try {
        $Results | ForEach-Object {
            [PSCustomObject]@{
                Filename     = $_.Filename
                Status       = $_.Status
                DateSource   = $_.DateSource
                Latitude     = $_.Latitude
                Longitude    = $_.Longitude
                Country      = $_.Country
                City         = $_.City
                TimeDeltaSec = $_.TimeDeltaSec
                Notes        = $_.Notes
            }
        } | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
        Write-Host "Report exported to '$csvPath'" -ForegroundColor Green
        return $csvPath
    }
    catch {
        Write-Warning "Failed to export report: $($_.Exception.Message)"
        return $null
    }
}

function Test-FilenamePattern {
    param(
        [string]$SampleFilename,
        [string]$PatternsString
    )
    $patterns = $PatternsString -split "`r`n|`n|`r" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    foreach ($p in $patterns) {
        $p = $p.Trim()
        if ($SampleFilename -match $p) {
            $dateStr = if ($Matches.Count -ge 2) { $Matches[1] } else { '?' }
            $timeStr = if ($Matches.Count -ge 3) { $Matches[2] } else { '(no time group)' }
            return @{ Matched = $true; Pattern = $p; DateGroup = $dateStr; TimeGroup = $timeStr }
        }
    }
    return @{ Matched = $false }
}

function Start-TrayIcon {
    param([string]$ToolTipText = "EXIF Geotag Tool", $Window)
    if ($script:TrayIcon) { return }
    try {
        $script:TrayIcon = New-Object System.Windows.Forms.NotifyIcon
        $script:TrayIcon.Text = $ToolTipText
        # Use a standard system icon if no custom icon is available
        $script:TrayIcon.Icon = [System.Drawing.SystemIcons]::Application
        $script:TrayIcon.Visible = $true
        $script:TrayIcon.add_DoubleClick({
                if ($null -ne $Window) {
                    $Window.Show()
                    $Window.WindowState = [System.Windows.WindowState]::Normal
                    $Window.Activate()
                }
            })
        $menu = New-Object System.Windows.Forms.ContextMenu
        $restoreItem = New-Object System.Windows.Forms.MenuItem("Restore")
        $restoreItem.add_Click({ if ($null -ne $Window) { $Window.Show(); $Window.WindowState = 'Normal'; $Window.Activate() } })
        $exitItem = New-Object System.Windows.Forms.MenuItem("Exit")
        $exitItem.add_Click({ $script:TrayIcon.Visible = $false; $Window.Close() })
        $menu.MenuItems.Add($restoreItem) | Out-Null
        $menu.MenuItems.Add($exitItem) | Out-Null
        $script:TrayIcon.ContextMenu = $menu
    }
    catch {
        Write-Warning "Tray icon init failed: $($_.Exception.Message)"
    }
}

function Stop-TrayIcon {
    if ($script:TrayIcon) {
        $script:TrayIcon.Visible = $false
        $script:TrayIcon.Dispose()
        $script:TrayIcon = $null
    }
}
#endregion

#region Main Processing Logic
function Invoke-FileProcessing {

    param(
        [string]$TargetFolder,
        [hashtable]$Config
    )
    $msg = $script:Lang[$script:currentLanguage].ProcessingStarted -f $TargetFolder
    Write-Host "`n$msg"

    $dawarichApiUrl = $Config.dawarichApiUrl
    $dawarichApiKey = $Config.dawarichApiKey
    $photonApiUrl = $Config.photonApiUrl
    $defaultTimeWindowSeconds = $Config.defaultTimeWindowSeconds
    $exiftoolPath = $Config.exiftoolPath
    $overwriteExistingData = $Config.overwriteExisting
    $alwaysQueryPhoton = $Config.alwaysQueryPhoton
    $fallbackMethod = if ($Config.fallbackMethod) { $Config.fallbackMethod } else { "Filename" }
    $defaultPat = "PXL_(\d{8})_(\d{6})\d*`nIMG_(\d{8})_(\d{6})\d*`nVID_(\d{8})_(\d{6})\d*`nScreenshot_(\d{8})-(\d{6})`nSignal-(\d{4}-\d{2}-\d{2})-(\d{6})`nWhatsApp Image (\d{4}-\d{2}-\d{2}) at (\d{2}\.\d{2}\.\d{2})`nIMG-(\d{8})-WA\d+`n(\d{8})_(\d{6})\d*`n(\d{6})_(\d{9})"
    $filenamePatterns = if ($Config.filenamePatterns) { $Config.filenamePatterns } else { $defaultPat }

    # New feature flags
    $isRecursive = [bool]$Config.recursive
    $isDryRun = [bool]$Config.dryRun
    $isPhotonOnly = [bool]$Config.photonOnly
    $filterFrom = $null; $filterTo = $null
    if (-not [string]::IsNullOrWhiteSpace($Config.filterDateFrom)) {
        try { $filterFrom = [datetime]::Parse($Config.filterDateFrom) } catch { Write-Warning "Invalid filterDateFrom: $($Config.filterDateFrom)" }
    }
    if (-not [string]::IsNullOrWhiteSpace($Config.filterDateTo)) {
        try { $filterTo = [datetime]::Parse($Config.filterDateTo).AddDays(1).AddSeconds(-1) } catch { Write-Warning "Invalid filterDateTo: $($Config.filterDateTo)" }
    }

    if ($isDryRun) {
        Show-ConsoleProgress -StatusMessage "[DRY-RUN] No files will be modified." -MessageColor Yellow -Category Info
    }

    # Build extension HashSet from config (O(1) lookups)
    $extSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $extSource = if (-not [string]::IsNullOrWhiteSpace($Config.fileExtensions)) { $Config.fileExtensions } else { ".jpg,.jpeg,.png,.tiff,.heic,.heif,.gif,.cr2,.dng,.arw,.orf,.webp,.mp4,.mov" }
    $extSource -split ',' | ForEach-Object { $e = $_.Trim(); if ($e) { $extSet.Add($e) | Out-Null } }
    $videoExtensions = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    @('.mp4', '.mov') | ForEach-Object { $videoExtensions.Add($_) | Out-Null }

    $largeFileThresholdBytes = 200 * 1024 * 1024
    Write-Host "Searching for files: $($extSet -join ', ') | Recursive: $isRecursive | DryRun: $isDryRun"
    $gciParams = @{ Path = $TargetFolder; File = $true; ErrorAction = 'Stop' }
    if ($isRecursive) { $gciParams.Recurse = $true }
    try {
        $filesToProcess = Get-ChildItem @gciParams | Where-Object { $extSet.Contains($_.Extension) }
    }
    catch {
        Write-Error "Error finding files: $($_.Exception.Message)"
        return
    }
    if ($filesToProcess.Count -eq 0) {
        $msg = $script:Lang[$script:currentLanguage].NoMediaFound -f $TargetFolder
        Write-Warning $msg; return
    }
    $msg = $script:Lang[$script:currentLanguage].ProcessingFiles
    Write-Host "$($filesToProcess.Count) files found. $msg"

    $processedCount = 0; $updatedCount = 0; $errorCount = 0; $warningCount = 0
    $skippedFiles = [System.Collections.Generic.List[string]]::new()
    $noApiDataFiles = [System.Collections.Generic.List[string]]::new()
    $processingResults = [System.Collections.Generic.List[hashtable]]::new()
    $script:totalFilesForProgress = $filesToProcess.Count

    # Cancellation token (set by Cancel button)
    $script:CancelProcessing = $false

    # Load state file for skip-already-processed logic
    $stateFilePath = Join-Path $TargetFolder '.geotag_state.json'
    $processedState = @{}
    if (Test-Path -Path $stateFilePath -PathType Leaf) {
        try {
            $loadedState = Get-Content -Path $stateFilePath -Raw -ErrorAction Stop | ConvertFrom-Json
            $loadedState.PSObject.Properties | ForEach-Object { $processedState[$_.Name] = $_.Value }
            $stateCount = $processedState.Count
            Show-ConsoleProgress -StatusMessage "State file loaded ($stateCount previously processed files)." -Category Info
        }
        catch {
            Write-Warning "Could not load state file: $($_.Exception.Message)"
        }
    }

    # Static exiftool read args
    $exifReadArgs = @("-j", "-GPSLatitude", "-GPSLongitude", "-GPSLatitudeRef", "-GPSLongitudeRef",
        "-Composite:GPSLatitude", "-Composite:GPSLongitude",
        "-UserData:GPSCoordinates", "-Rotation",
        "-Country", "-City", "-XMP-photoshop:State", "-XMP-iptcCore:CountryCode",
        "-DateTimeOriginal", "-CreateDate", "-MediaCreateDate", "-TrackCreateDate",
        "-FilePath")

    # Helper: update live stats in UI
    $UpdateStats = [Action] {
        if ($script:StatUpdatedVal) { $script:StatUpdatedVal.Text = "$updatedCount" }
        if ($script:StatWarningsVal) { $script:StatWarningsVal.Text = "$warningCount" }
        if ($script:StatSkippedVal) { $script:StatSkippedVal.Text = "$($skippedFiles.Count)" }
        $rem = $script:totalFilesForProgress - $processedCount
        if ($script:StatRemainingVal) { $script:StatRemainingVal.Text = "$rem" }
    }

    try {
        Start-ExifDaemon -ExiftoolExePath $exiftoolPath
        foreach ($file in $filesToProcess) {
            # Honour cancel request
            if ($script:CancelProcessing) {
                Show-ConsoleProgress -StatusMessage "Processing cancelled by user." -MessageColor Yellow -Category Info
                break
            }

            $processedCount++
            $script:currentFileIndexForProgress = $processedCount
            $fileHadError = $false
            $isMp4File = $videoExtensions.Contains($file.Extension)
            $bestMatchApiResult = $null

            # Date range filter
            if ($filterFrom -or $filterTo) {
                $fileDate = $file.LastWriteTime
                if (($filterFrom -and $fileDate -lt $filterFrom) -or ($filterTo -and $fileDate -gt $filterTo)) {
                    Show-ConsoleProgress -StatusMessage "  [SKIPPED] $($file.Name) - outside date filter." -MessageColor Yellow -Category Skipped
                    $skippedFiles.Add($file.FullName)
                    $UpdateStats.Invoke()
                    continue
                }
            }

            if ($file.Length -gt $largeFileThresholdBytes) {
                Show-ConsoleProgress -StatusMessage ('  [{0}/{1}] {2} (Large: {3} MB)' -f $processedCount, $script:totalFilesForProgress, $file.Name, ($file.Length / 1MB -as [int])) -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress -MessageColor Yellow
            }
            else {
                Show-ConsoleProgress -StatusMessage ('  [{0}/{1}] {2}' -f $processedCount, $script:totalFilesForProgress, $file.Name) -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress
            }

            # Exiftool read args are defined before the loop (static per run)
            $exifData = $null
            try {
                $daemonArgs = $exifReadArgs + "$($file.FullName)"
                $exifOutHash = Invoke-ExifDaemon -ArgsArray $daemonArgs
                $exifOut = $exifOutHash.StdOut
                if ($exifOutHash.StdErr) { Write-Warning "Exiftool read warnings: $($exifOutHash.StdErr)" }
                
                $tmpJson = $exifOut | ConvertFrom-Json -EA SilentlyContinue
                if ($tmpJson -is [array]) {
                    $exifData = if ($tmpJson.Count -gt 0) { $tmpJson[0] } else { $null }
                }
                else {
                    $exifData = $tmpJson
                }
                if ($null -eq $exifData -and -not [string]::IsNullOrWhiteSpace($exifOut)) {
                    Show-ConsoleProgress -StatusMessage ('[WARNING] JSON parse fail for ''{0}''.' -f $file.Name) -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress -MessageColor Yellow
                    Write-Warning "JSON parse fail for '$($file.Name)'. Output: $exifOut"
                    throw
                }
                elseif ($null -eq $exifData) {
                    Show-ConsoleProgress -StatusMessage "  -> No EXIF/XMP data found. Skipping." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress
                    continue
                }
            }
            catch {
                Write-Warning "Exif read error for '$($file.Name)': $($_.Exception.Message)"
                if ($null -ne $LASTEXITCODE -and $LASTEXITCODE -ne 0) { Write-Warning "Exiftool exit code $LASTEXITCODE." }
                $fileHadError = $true; $errorCount++
                continue
            }

            # --- DATE DISCOVERY ---
            $discoveryResult = Get-DiscoveryDate -File $file -ExifData $exifData -FallbackMethod $fallbackMethod -PatternsString $filenamePatterns
            $fileTimestampUTC = $discoveryResult.Date
            $dateSource = $discoveryResult.Source
            $writeDateToMetadata = if ($dateSource -ne "Exif") { $fileTimestampUTC } else { $null }
            $dateLabel = if ($fileTimestampUTC) { $fileTimestampUTC } else { "(not found)" }
            Show-ConsoleProgress -StatusMessage "  -> Date: $dateLabel [$dateSource]  GPS check..." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress
            
            $existingGpsLat = $null; $existingGpsLon = $null
            $imageHasUsableExistingGps = $false; $mp4HasUsableExistingGps = $false

            if (-not $isMp4File -and $exifData) {
                $compositeParseSuccess = $false
                $compLat = $exifData.'Composite:GPSLatitude'
                $compLon = $exifData.'Composite:GPSLongitude'
                if ($null -ne $compLat -and $null -ne $compLon) {
                    $latFromComposite = 0.0; $lonFromComposite = 0.0
                    if ([double]::TryParse($compLat.ToString(), [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$latFromComposite) -and
                        [double]::TryParse($compLon.ToString(), [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$lonFromComposite) -and
                        ($latFromComposite -ne 0 -or $lonFromComposite -ne 0)) {
                        $existingGpsLat = $latFromComposite; $existingGpsLon = $lonFromComposite
                        $imageHasUsableExistingGps = $true; $compositeParseSuccess = $true
                        Write-Verbose "Image Composite GPS: Lat=$existingGpsLat Lon=$existingGpsLon"
                    }
                    else {
                        Write-Verbose "Composite GPS present but could not parse or is (0,0) for '$($file.Name)'."
                    }
                }
                if (-not $compositeParseSuccess) {
                    if ($exifData.PSObject.Properties.Name -contains 'GPSLatitude' -and $exifData.PSObject.Properties.Name -contains 'GPSLongitude' -and
                        $exifData.PSObject.Properties.Name -contains 'GPSLatitudeRef' -and $exifData.PSObject.Properties.Name -contains 'GPSLongitudeRef' -and
                        $exifData.GPSLatitude -ne $null -and $exifData.GPSLongitude -ne $null -and
                        $exifData.GPSLatitudeRef -ne $null -and $exifData.GPSLongitudeRef -ne $null) {
                        Write-Verbose "Attempting to parse standard GPS tags for $($file.Name)"
                        try {
                            $latVal = $null; $lonVal = $null
                            if ($exifData.GPSLatitude -is [string] -and ($exifData.GPSLatitude -match "deg" -or $exifData.GPSLatitude -match "'" -or $exifData.GPSLatitude -match '"')) { 
                                $latVal = Convert-SexagesimalToDecimal -CoordinateString $exifData.GPSLatitude -Hemisphere $exifData.GPSLatitudeRef
                            }
                            elseif ([double]::TryParse($exifData.GPSLatitude.ToString(), [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$latVal)) {
                                if ($exifData.GPSLatitudeRef -eq 'S') { $latVal = - $latVal }
                            }
                            else { $latVal = $null }

                            if ($exifData.GPSLongitude -is [string] -and ($exifData.GPSLongitude -match "deg" -or $exifData.GPSLongitude -match "'" -or $exifData.GPSLongitude -match '"')) { 
                                $lonVal = Convert-SexagesimalToDecimal -CoordinateString $exifData.GPSLongitude -Hemisphere $exifData.GPSLongitudeRef
                            }
                            elseif ([double]::TryParse($exifData.GPSLongitude.ToString(), [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$lonVal)) {
                                if ($exifData.GPSLongitudeRef -eq 'W') { $lonVal = - $lonVal }
                            }
                            else { $lonVal = $null }

                            if ($null -ne $latVal -and $null -ne $lonVal -and ($latVal -ne 0 -or $lonVal -ne 0)) {
                                $existingGpsLat = $latVal; $existingGpsLon = $lonVal
                                $imageHasUsableExistingGps = $true
                                Write-Verbose "Image standard GPS: Lat=$existingGpsLat Lon=$existingGpsLon"
                            }
                            else {
                                Show-ConsoleProgress -StatusMessage ('[WARNING] Could not parse standard GPS tags for ''{0}''.' -f $file.Name) -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress -MessageColor Yellow
                            }
                        }
                        catch {
                            Show-ConsoleProgress -StatusMessage ('[WARNING] Error parsing GPS tags for ''{0}'': {1}' -f $file.Name, $_.Exception.Message) -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress -MessageColor Yellow
                        }
                    }
                }
            }
            elseif ($isMp4File -and $exifData) {
                if ($exifData.PSObject.Properties.Name -contains 'UserData:GPSCoordinates') {
                    $udGpsStr = $exifData.'UserData:GPSCoordinates'
                    if (-not [string]::IsNullOrWhiteSpace($udGpsStr)) {
                        $udGpsStr = $udGpsStr.Trim("`"")
                        $gpsParts = $udGpsStr.Split(',')
                        if ($gpsParts.Count -ge 2) {
                            try { 
                                $latCand = [double]::Parse($gpsParts[0].Trim(), [System.Globalization.CultureInfo]::InvariantCulture)
                                $lonCand = [double]::Parse($gpsParts[1].Trim(), [System.Globalization.CultureInfo]::InvariantCulture)
                                if ($latCand -ne 0 -or $lonCand -ne 0) {
                                    $existingGpsLat = $latCand; $existingGpsLon = $lonCand
                                    $mp4HasUsableExistingGps = $true
                                    Write-Verbose "MP4 UserData GPS: Lat=$latCand Lon=$lonCand"
                                }
                                else {
                                    Write-Verbose "MP4 UserData:GPS is (0,0) for '$($file.Name)'."
                                }
                            }
                            catch { 
                                Show-ConsoleProgress -StatusMessage ('[WARNING] Parse UserData:GPS fail for MP4 ''{0}'': {1}' -f $file.Name, $udGpsStr) -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress -MessageColor Yellow
                                Write-Warning "     Parse UserData:GPS fail for MP4 '$($file.Name)': $udGpsStr"
                            }
                        }
                        else {
                            Show-ConsoleProgress -StatusMessage ('[WARNING] UserData:GPS format error for MP4 ''{0}'': {1}' -f $file.Name, $udGpsStr) -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress -MessageColor Yellow
                            Write-Warning "     UserData:GPS format error for MP4 '$($file.Name)': $udGpsStr"
                        }
                    }
                }
            }
            
            $fileCompletelyHasData = $false; $hasRequiredGpsForFile = $false; $existingState = $null
            if ($exifData -ne $null -and $exifData.PSObject.Properties.Name -contains 'XMP-photoshop:State') {
                $existingState = $exifData.'XMP-photoshop:State'
            }

            if ($isMp4File) {
                $hasRequiredGpsForFile = $mp4HasUsableExistingGps
                $fileCompletelyHasData = $hasRequiredGpsForFile 
            }
            else { 
                $hasRequiredGpsForFile = $imageHasUsableExistingGps
                $hasLocImg = $false
                if ($exifData -ne $null) {
                    $imgCountry = $exifData.Country
                    $imgCity = $exifData.City
                    $imgCCode = $exifData.'XMP-iptcCore:CountryCode'
                    if (-not([string]::IsNullOrWhiteSpace($imgCountry)) -or -not([string]::IsNullOrWhiteSpace($imgCity)) -or -not([string]::IsNullOrWhiteSpace($imgCCode)) -or -not([string]::IsNullOrWhiteSpace($existingState)) ) {
                        $hasLocImg = $true
                    }
                }
                $fileCompletelyHasData = $hasRequiredGpsForFile -and $hasLocImg
            }
            $shouldProcessFile = $false
            if ($overwriteExistingData) {
                $shouldProcessFile = $true
                Show-ConsoleProgress -StatusMessage "     -> Overwrite ON. File will be processed." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress 
            }
            elseif (-not $fileCompletelyHasData) {
                $shouldProcessFile = $true
                $reason = ""
                if ($isMp4File -and -not $hasRequiredGpsForFile) { $reason = "MP4 GPS missing." }
                elseif (-not $isMp4File) {
                    if (-not $hasRequiredGpsForFile) { $reason += "Image GPS missing. " }
                    if (-not $hasLocImg) { $reason += "Image Location (Country/City/State/Code) missing." }
                }
                Show-ConsoleProgress -StatusMessage "     -> $reason Processing needed." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress 
            }
            
            if (-not $shouldProcessFile) { 
                Show-ConsoleProgress -StatusMessage "     -> No processing needed (data exists, overwrite OFF). Skipping." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress
                $skippedFiles.Add($file.FullName)
                continue
            }
            
            $latitudeToUse = $null; $longitudeToUse = $null; $countryToWrite = $null; $cityToWrite = $null; $countryCodeToWrite = $null; $stateToWrite = $null
    
            if (-not $isMp4File -and $imageHasUsableExistingGps) {
                Show-ConsoleProgress -StatusMessage ('     -> Image has GPS (Lat:{0},Lon:{1}). Using it. Dawarich API skipped.' -f $existingGpsLat, $existingGpsLon) -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress -MessageColor Green
                $latitudeToUse = $existingGpsLat; $longitudeToUse = $existingGpsLon
                if ($exifData -ne $null) {
                    $countryToWrite = $exifData.Country
                    $cityToWrite = $exifData.City
                    $countryCodeToWrite = $exifData.'XMP-iptcCore:CountryCode'
                    $stateToWrite = $exifData.'XMP-photoshop:State' 
                }
                $needsPhoton = $false
                if ($alwaysQueryPhoton) {
                    $needsPhoton = $true
                    Show-ConsoleProgress -StatusMessage "     -> Always Query Photon ON." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress
                }
                elseif ([string]::IsNullOrWhiteSpace($countryToWrite) -or [string]::IsNullOrWhiteSpace($cityToWrite) -or [string]::IsNullOrWhiteSpace($countryCodeToWrite) -or [string]::IsNullOrWhiteSpace($stateToWrite)) {
                    $needsPhoton = $true
                    Show-ConsoleProgress -StatusMessage "     -> Existing location incomplete. Querying Photon." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress
                }
                if ($needsPhoton) {
                    $photonData = Get-LocationFromPhoton -BaseUrl $photonApiUrl -Latitude $latitudeToUse -Longitude $longitudeToUse 
                    if ($photonData) { 
                        Show-ConsoleProgress -StatusMessage "         -> Photon found: C='$($photonData.Country)',Ci='$($photonData.City)',Co='$($photonData.CountryCode)',S='$($photonData.State)'" -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress
                        # If alwaysQueryPhoton is true, Photon values take precedence if they are not empty. Otherwise, existing values are kept.
                        if ($alwaysQueryPhoton) {
                            if (-not ([string]::IsNullOrWhiteSpace($photonData.Country))) { $countryToWrite = $photonData.Country }
                            if (-not ([string]::IsNullOrWhiteSpace($photonData.City))) { $cityToWrite = $photonData.City }
                            if (-not ([string]::IsNullOrWhiteSpace($photonData.State))) { $stateToWrite = $photonData.State }
                            if (-not ([string]::IsNullOrWhiteSpace($photonData.CountryCode))) { $countryCodeToWrite = $photonData.CountryCode }
                        }
                        else {
                            # Fill only if existing data was missing
                            if ([string]::IsNullOrWhiteSpace($countryToWrite) -and -not([string]::IsNullOrWhiteSpace($photonData.Country))) { $countryToWrite = $photonData.Country }
                            if ([string]::IsNullOrWhiteSpace($cityToWrite) -and -not([string]::IsNullOrWhiteSpace($photonData.City))) { $cityToWrite = $photonData.City }
                            if ([string]::IsNullOrWhiteSpace($stateToWrite) -and -not([string]::IsNullOrWhiteSpace($photonData.State))) { $stateToWrite = $photonData.State }
                            if ([string]::IsNullOrWhiteSpace($countryCodeToWrite) -and -not([string]::IsNullOrWhiteSpace($photonData.CountryCode))) { $countryCodeToWrite = $photonData.CountryCode }
                        }
                    }
                    else { 
                        Show-ConsoleProgress -StatusMessage "[WARNING] Photon query failed for existing GPS. Existing location data will be used if available." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress -MessageColor Yellow
                        Write-Warning "     -> Photon query failed for existing GPS."
                    }
                }
                else { 
                    Show-ConsoleProgress -StatusMessage "     -> Photon query not needed." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress
                }
            }
            elseif ($isMp4File -and $mp4HasUsableExistingGps) {
                Show-ConsoleProgress -StatusMessage "     -> MP4 has GPS (Lat:$existingGpsLat,Lon:$existingGpsLon). Using it. Dawarich API skipped." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress -MessageColor Green
                $latitudeToUse = $existingGpsLat; $longitudeToUse = $existingGpsLon
            }
            else {
                # File (Image or MP4) needs Dawarich API
                $fileTypeStr = if ($isMp4File) { 'MP4' }else { 'Image' }
                Show-ConsoleProgress -StatusMessage "     -> File ($fileTypeStr) no usable existing GPS or overwrite forces API. Using Dawarich." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress
                
                if ([string]::IsNullOrWhiteSpace($fileTimestampUTC)) {
                    $skipMsg = "Could not determine creation date for '$($file.Name)'. Skipping."
                    Write-Host "     -> $skipMsg" -ForegroundColor Yellow
                    Show-ConsoleProgress -StatusMessage "[WARNING] $skipMsg" -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress -MessageColor Yellow -Category Warning
                    $warningCount++
                    $noApiDataFiles.Add($file.FullName)
                    $processingResults.Add(@{ Filename = $file.Name; Status = 'NoDate'; DateSource = 'None'; Latitude = ''; Longitude = ''; Country = ''; City = ''; TimeDeltaSec = ''; Notes = 'Could not determine creation date' })
                    $UpdateStats.Invoke()
                    continue
                }

                $fileDateTime = $null
                try {
                    $fileDateTime = [datetime]::ParseExact($fileTimestampUTC, "yyyy-MM-ddTHH:mm:ssZ", [System.Globalization.CultureInfo]::InvariantCulture, ([System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal))
                }
                catch {
                    Show-ConsoleProgress -StatusMessage "[WARNING] Parse UTC timestamp fail. Skipping." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress -MessageColor Yellow
                    Write-Warning "     Parse UTC fail '$($file.Name)'."
                    $noApiDataFiles.Add($file.FullName)
                    $fileHadError = $true
                    $errorCount++
                    $UpdateStats.Invoke()
                    continue
                }
                Show-ConsoleProgress -StatusMessage "     Creation (UTC): $fileTimestampUTC" -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress
                $startAt = $fileDateTime.AddSeconds(-$defaultTimeWindowSeconds).ToString("yyyy-MM-ddTHH:mm:ssZ"); $endAt = $fileDateTime.AddSeconds($defaultTimeWindowSeconds).ToString("yyyy-MM-ddTHH:mm:ssZ")
                
                $apiResultRange = Get-DawarichDataFromApi -BaseUrl $dawarichApiUrl -ApiKey $dawarichApiKey -StartAt $startAt -EndAt $endAt
                if ($apiResultRange) {
                    $resArr = @($apiResultRange)
                    if ($resArr.Count -gt 0) {
                        $validRes = $resArr | Where-Object { Test-DawarichResultIsValid -Result $_ }
                        if ($validRes.Count -gt 0) {
                            Show-ConsoleProgress -StatusMessage "     -> $($validRes.Count) valid Dawarich results. Finding closest..." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress
                            $closestDiff = [double]::MaxValue
                            foreach ($res in $validRes) {
                                try {
                                    $resTs = Parse-DawarichTimestamp -TimestampInput $res.timestamp 
                                    if ($resTs) {
                                        $tDiff = New-TimeSpan -Start $fileDateTime -End $resTs
                                        $absDiff = [Math]::Abs($tDiff.TotalSeconds)
                                        if ($absDiff -lt $closestDiff) {
                                            $closestDiff = $absDiff
                                            $bestMatchApiResult = $res
                                        }
                                    }
                                }
                                catch {
                                    $errMsgInnerLoop = "Error processing Dawarich result for timestamp comparison: '$($res.timestamp)' - $($_.Exception.Message)"
                                    Show-ConsoleProgress -StatusMessage ('[WARNING] {0}' -f $errMsgInnerLoop) -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress -MessageColor Yellow
                                    Write-Warning $errMsgInnerLoop
                                }
                            }
                            if ($bestMatchApiResult) { Show-ConsoleProgress -StatusMessage "     -> Closest Dawarich match (Diff: $($closestDiff.ToString('F2'))s)." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress }
                            else { Show-ConsoleProgress -StatusMessage "     -> No time-comparable Dawarich result." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress }
                        }
                        else { Show-ConsoleProgress -StatusMessage "     -> Dawarich results, but no valid non-zero coords." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress }
                    }
                    else { Show-ConsoleProgress -StatusMessage "     -> No results from Dawarich." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress }
                }
                else { Show-ConsoleProgress -StatusMessage "     -> Dawarich API query failed." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress }

                if ($bestMatchApiResult) {
                    [double]::TryParse($bestMatchApiResult.latitude.ToString(), [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$latitudeToUse) | Out-Null
                    [double]::TryParse($bestMatchApiResult.longitude.ToString(), [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$longitudeToUse) | Out-Null
                    if ($latitudeToUse -eq $null -or $longitudeToUse -eq $null -or ($latitudeToUse -eq 0 -and $longitudeToUse -eq 0)) { 
                        Show-ConsoleProgress -StatusMessage ('[WARNING] Invalid/zero lat/lon from Dawarich. Skipping write.') -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress -MessageColor Yellow
                        Write-Warning "     -> Invalid/zero lat/lon from Dawarich for '$($file.Name)'."
                        $noApiDataFiles.Add($file.FullName); $fileHadError = $true; $errorCount++; continue
                    }
                    $countryToWrite = $bestMatchApiResult.country
                    $cityToWrite = $bestMatchApiResult.city
                    $countryCodeToWrite = $bestMatchApiResult.country_code
                    # $stateToWrite = $bestMatchApiResult.state # Assuming Dawarich might provide state, adjust if property name is different
                    
                    if (-not $isMp4File) {
                        $needsPhoton = $false
                        if ($alwaysQueryPhoton) {
                            $needsPhoton = $true
                            Show-ConsoleProgress -StatusMessage "     -> Always Query Photon ON." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress
                        }
                        elseif ([string]::IsNullOrWhiteSpace($countryToWrite) -or [string]::IsNullOrWhiteSpace($cityToWrite) -or [string]::IsNullOrWhiteSpace($countryCodeToWrite) -or [string]::IsNullOrWhiteSpace($stateToWrite) ) {
                            $needsPhoton = $true
                            Show-ConsoleProgress -StatusMessage "     -> Dawarich/Existing location incomplete. Querying Photon." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress
                        }
                        if ($needsPhoton) {
                            $photonData = Get-LocationFromPhoton -BaseUrl $photonApiUrl -Latitude $latitudeToUse -Longitude $longitudeToUse 
                            if ($photonData) { 
                                Show-ConsoleProgress -StatusMessage "         -> Photon found: C='$($photonData.Country)',Ci='$($photonData.City)',Co='$($photonData.CountryCode)',S='$($photonData.State)'" -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress
                                # If alwaysQueryPhoton is true, Photon values take precedence if they are not empty. Otherwise, existing values (from Dawarich) are kept.
                                if ($alwaysQueryPhoton) {
                                    if (-not ([string]::IsNullOrWhiteSpace($photonData.Country))) { $countryToWrite = $photonData.Country }
                                    if (-not ([string]::IsNullOrWhiteSpace($photonData.City))) { $cityToWrite = $photonData.City }
                                    if (-not ([string]::IsNullOrWhiteSpace($photonData.State))) { $stateToWrite = $photonData.State }
                                    if (-not ([string]::IsNullOrWhiteSpace($photonData.CountryCode))) { $countryCodeToWrite = $photonData.CountryCode }
                                }
                                else {
                                    # Fill only if Dawarich data was missing
                                    if ([string]::IsNullOrWhiteSpace($countryToWrite) -and -not([string]::IsNullOrWhiteSpace($photonData.Country))) { $countryToWrite = $photonData.Country }
                                    if ([string]::IsNullOrWhiteSpace($cityToWrite) -and -not([string]::IsNullOrWhiteSpace($photonData.City))) { $cityToWrite = $photonData.City }
                                    if ([string]::IsNullOrWhiteSpace($stateToWrite) -and -not([string]::IsNullOrWhiteSpace($photonData.State))) { $stateToWrite = $photonData.State }
                                    if ([string]::IsNullOrWhiteSpace($countryCodeToWrite) -and -not([string]::IsNullOrWhiteSpace($photonData.CountryCode))) { $countryCodeToWrite = $photonData.CountryCode }
                                }
                            }
                            else { 
                                Show-ConsoleProgress -StatusMessage ('[WARNING] Photon query failed. Existing/Dawarich location data will be used if available.') -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress -MessageColor Yellow
                                Write-Warning "     -> Photon query failed."
                            }
                        }
                    }
                }
                else { 
                    Show-ConsoleProgress -StatusMessage "     -> No suitable GPS from Dawarich API. Skipping write." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress
                    Write-Host "     -> No suitable GPS from Dawarich API for '$($file.Name)'."
                    $noApiDataFiles.Add($file.FullName)
                    continue
                }
            } 

            if ($latitudeToUse -ne $null -and $longitudeToUse -ne $null -and ($latitudeToUse -ne 0 -or $longitudeToUse -ne 0)) {
                $resultEntry = @{
                    Filename     = $file.Name
                    Status       = 'Updated'
                    DateSource   = $discoveryResult.Source
                    Latitude     = $latitudeToUse
                    Longitude    = $longitudeToUse
                    Country      = $countryToWrite
                    City         = $cityToWrite
                    TimeDeltaSec = if ($closestDiff -and $closestDiff -ne [double]::MaxValue) { [Math]::Round($closestDiff, 1) } else { '' }
                    Notes        = if ($isDryRun) { 'DRY-RUN' } else { '' }
                }

                if ($isDryRun) {
                    Show-ConsoleProgress -StatusMessage "     -> [DRY-RUN] Would write to: $($file.Name)" -MessageColor Yellow -Category Info
                    $updatedCount++
                }
                else {
                    $writeSuccess = Set-ExifData -ExiftoolExePath $exiftoolPath -FilePath $file.FullName `
                        -Latitude $latitudeToUse -Longitude $longitudeToUse `
                        -Country $countryToWrite -City $cityToWrite -CountryCode $countryCodeToWrite `
                        -State $stateToWrite -DiscoveryDate $writeDateToMetadata
                    if (-not $writeSuccess) {
                        $fileHadError = $true; $errorCount++
                        $resultEntry.Status = 'Error'
                    }
                    else {
                        $updatedCount++
                        $processedState[$file.FullName] = (Get-Date -Format 'o')
                    }
                }
                $processingResults.Add($resultEntry)
            }
            elseif ($shouldProcessFile) {
                Show-ConsoleProgress -StatusMessage "[WARNING] No usable GPS determined after all checks. File not updated." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress -MessageColor Yellow -Category Warning
                Write-Warning "     -> No usable GPS determined for '$($file.Name)' after all checks. File not updated."
                $warningCount++
                $noApiDataFiles.Add($file.FullName)
                $processingResults.Add(@{ Filename = $file.Name; Status = 'NoGPS'; DateSource = $discoveryResult.Source; Latitude = ''; Longitude = ''; Country = ''; City = ''; TimeDeltaSec = ''; Notes = '' })
            }
            $UpdateStats.Invoke()

        } # end foreach file
    }
    finally {
        Stop-ExifDaemon
        Write-Progress -Activity "Processing" -Completed -Id 1
    }

    # Save state file (only when not dry-run)
    if (-not $isDryRun -and $processedState.Count -gt 0) {
        try {
            $processedState | ConvertTo-Json -Depth 2 | Set-Content -Path $stateFilePath -Encoding UTF8 -ErrorAction Stop
            Show-ConsoleProgress -StatusMessage "State saved ($($processedState.Count) files tracked)." -Category Info
        }
        catch {
            Write-Warning "Could not save state file: $($_.Exception.Message)"
        }
    }

    # Enable export button in UI
    if ($script:ExportReportButton -and $processingResults.Count -gt 0) {
        $script:ExportReportButton.IsEnabled = $true
        $script:LastProcessingResults = $processingResults
        $script:LastTargetFolder = $TargetFolder
    }

    # Final Summary
    $summaryLines = @(
        "",
        "--- FINAL SUMMARY $(if($isDryRun){'[DRY-RUN] '}else{''})---",
        " * Files scanned:   $processedCount",
        " * Updated:         $updatedCount",
        " * Errors:          $errorCount",
        " * Skipped:         $($skippedFiles.Count)",
        " * No GPS found:    $($noApiDataFiles.Count)"
    )
    $summaryLines | ForEach-Object { Show-ConsoleProgress -StatusMessage $_ -Category Info }
    Write-Host ""
}
#endregion

# --- Script Entry Point ---
# Load initial configuration
$script:currentConfig = Load-Configuration -FilePath $configFilePath -Defaults $defaultConfig

# Show the main application window
Show-MainGui

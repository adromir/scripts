<#
.SYNOPSIS
Searches a selected folder for image and MP4 files, optionally updating GPS and location metadata for better compatibility with Google Photos. Displays progress in the console.
For Images: Updates standard GPS tags, XMP GPS tags, country, city, state, and country code directly into the image file. If an image already has GPS (decimal or sexagesimal), these coordinates are used for Photon reverse geocoding, skipping Dawarich. Sexagesimal coordinates are converted to decimal and written back. If 'alwaysQueryPhoton' is true, Photon data is preferred for location fields, but existing data (e.g., from Dawarich) is preserved if Photon provides no data for a specific field.
For MP4s: Updates ONLY GPS coordinates directly into the MP4 file using Google Photos preferred tags ('UserData:GPSCoordinates', 'GPSAltitude'). Existing 'Rotation' is not modified. Country/City/State/Code are NOT written to MP4s. If an MP4 already has GPS, these coordinates are used, skipping Dawarich.
Queries a primary API (Dawarich) for location data based on a time window around the file's creation date (unless skipped for files with existing GPS).
Optionally uses reverse geocoding via a secondary API (Photon) for IMAGES if primary data is missing or user chooses to always query. Photon is NOT used for MP4s.
Writes the found data using exiftool.
Includes a main WPF GUI for starting processing and accessing settings, and a configuration GUI. Progress is shown in the console.
Outputs lists of skipped files at the end to the console.

.DESCRIPTION
This script performs the following steps:
1.  Loads configuration from config.json or uses defaults.
2.  Displays a Main WPF GUI window.
    - Button to "Select Folder & Start Processing".
    - Button to open "Settings".
    - Status indication if config.json is missing.
3.  If "Settings" is clicked:
    - Displays the Configuration WPF GUI.
    - Allows viewing/editing/saving of settings.
4.  If "Select Folder & Start Processing" is clicked:
    - Prompts the user to select a folder. If cancelled, returns to the main GUI.
    - Searches for supported files.
    - For each file (updates progress in console):
        a. Reads EXIF/XMP/UserData/Rotation tags.
        b. Converts sexagesimal GPS to decimal for images if necessary.
        c. Determines if processing is needed based on missing data or the "Overwrite" flag.
        d. Handles IMAGE files WITH existing GPS (skips Dawarich, uses existing GPS for Photon if needed, writes back converted decimal GPS if original was sexagesimal).
        e. Handles MP4 files WITH existing GPS (skips Dawarich, uses existing GPS; Rotation is not modified).
        f. Handles files (IMAGE or MP4) WITHOUT existing GPS (queries Dawarich, then Photon for images if needed; MP4 Rotation is not modified). If 'alwaysQueryPhoton' is true for images, Photon data takes precedence for fields it provides, otherwise Dawarich data for those fields is kept.
        g. Writes data using exiftool directly into the media file (including State for images from Photon).
        h. Adds file to skipped lists if applicable.
    - Cancellation via Ctrl+C in the console.
5.  Outputs final summary and skipped file lists to the console.

.NOTES
Ensure that exiftool.exe is either in the system PATH or the full path is specified correctly.
The API keys and URLs are now primarily managed via the GUI and optional config file.
Writing data overwrites the original files (using exiftool -overwrite_original for MP4s and images). Back up files beforehand. XMP sidecar files are NOT created or updated.
The configuration file (config.json) stores settings in plain text.
MP4 tags ('UserData:GPSCoordinates', 'GPSAltitude') are for Google Photos. Rotation for MP4s is not modified.
Image tags include standard EXIF GPS and XMP GPS. Composite GPS tags are read for decimal degrees. UserData:GPSCoordinates is parsed for MP4s. State/Province is written as XMP-photoshop:State for images.
Progress and final summary are shown in the console.
#>

#region Configuration Defaults & File Handling
# ================== CONFIGURATION DEFAULTS & FILE HANDLING ==================

# Default values (used if config file not found or value missing)
$defaultConfig = @{
    dawarichApiUrl = "https://your-api-host.com/api/v1/points"
    dawarichApiKey = "YOUR_API_KEY"
    photonApiUrl = "https://photon.komoot.io"
    defaultTimeWindowSeconds = 60
    exiftoolPath = "exiftool.exe"
    overwriteExisting = $false
    alwaysQueryPhoton = $false
}

# Configuration file path
if ($PSScriptRoot) {
    $configFilePath = Join-Path -Path $PSScriptRoot -ChildPath "config.json"
} else {
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
        } catch {
            Write-Warning "Failed to load or parse configuration file '$FilePath'. Using defaults. Error: $($_.Exception.Message)"
        }
    } else {
        Write-Verbose "Configuration file '$FilePath' not found. Using defaults."
    }

    if ($loadedConfig -ne $null) {
        if ($loadedConfig.PSObject.Properties.Name -contains 'dawarichApiUrl') { $config.dawarichApiUrl = $loadedConfig.dawarichApiUrl }
        elseif ($loadedConfig.PSObject.Properties.Name -contains 'gpsApiUrl') { $config.dawarichApiUrl = $loadedConfig.gpsApiUrl; Write-Verbose "Using old key 'gpsApiUrl'."}
        if ($loadedConfig.PSObject.Properties.Name -contains 'dawarichApiKey') { $config.dawarichApiKey = $loadedConfig.dawarichApiKey }
        elseif ($loadedConfig.PSObject.Properties.Name -contains 'gpsApiKey') { $config.dawarichApiKey = $loadedConfig.gpsApiKey; Write-Verbose "Using old key 'gpsApiKey'."}
        if ($loadedConfig.PSObject.Properties.Name -contains 'photonApiUrl') { $config.photonApiUrl = $loadedConfig.photonApiUrl }
        elseif ($loadedConfig.PSObject.Properties.Name -contains 'komootApiUrl') { $config.photonApiUrl = $loadedConfig.komootApiUrl; Write-Verbose "Using old key 'komootApiUrl'."}

        if ($loadedConfig.PSObject.Properties.Name -contains 'defaultTimeWindowSeconds') { $config.defaultTimeWindowSeconds = $loadedConfig.defaultTimeWindowSeconds }
        if ($loadedConfig.PSObject.Properties.Name -contains 'exiftoolPath') { $config.exiftoolPath = $loadedConfig.exiftoolPath }
        if ($loadedConfig.PSObject.Properties.Name -contains 'overwriteExisting') { $config.overwriteExisting = $loadedConfig.overwriteExisting }
        if ($loadedConfig.PSObject.Properties.Name -contains 'alwaysQueryPhoton') { $config.alwaysQueryPhoton = $loadedConfig.alwaysQueryPhoton }
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
        $dataToSave = $ConfigData.Clone()
        if ($dataToSave.ContainsKey('saveConfig')) { $dataToSave.Remove('saveConfig') }
        if ($dataToSave.ContainsKey('exiftoolTimeoutMs')) { $dataToSave.Remove('exiftoolTimeoutMs') }
        
        foreach($key in $defaultConfig.Keys){ 
            if (-not $dataToSave.ContainsKey($key)){ 
                $dataToSave[$key] = $defaultConfig[$key] 
            }
        }
        $dataToSave.Remove('gpsApiUrl') | Out-Null
        $dataToSave.Remove('gpsApiKey') | Out-Null
        $dataToSave.Remove('komootApiUrl') | Out-Null

        $dataToSave | ConvertTo-Json -Depth 3 | Set-Content -Path $FilePath -Encoding UTF8 -ErrorAction Stop
        Write-Host "Configuration saved successfully to '$FilePath'." -ForegroundColor Green
    } catch {
        Write-Warning "Failed to save configuration file '$FilePath'. Error: $($_.Exception.Message)"
    }
}
#endregion

#region GUI Functions
# ================== Main GUI FUNCTION (WPF) ==================
function Show-MainGui {
    Add-Type -AssemblyName PresentationFramework; Add-Type -AssemblyName PresentationCore; Add-Type -AssemblyName WindowsBase
    
    $xamlMain = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        x:Name="MainAppWindow" Title="EXIF Geotag Tool" Height="230" Width="450"
        WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
    <Grid Margin="15">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <Label x:Name="ConfigStatusLabel" Content="Konfigurationsdatei (config.json) nicht gefunden. Standardeinstellungen werden verwendet. Bitte Einstellungen prüfen." Grid.Row="0" HorizontalAlignment="Center" Margin="0,0,0,10" Foreground="OrangeRed" FontWeight="Bold" Visibility="Collapsed"/>
        
        <Button x:Name="StartProcessingButton" Content="Ordner auswählen &amp; Verarbeitung starten" Grid.Row="1" Height="45" Margin="0,5,0,10" Padding="10,5"/>
        <Button x:Name="SettingsButton" Content="Einstellungen" Grid.Row="2" Height="45" Margin="0,5,0,5" Padding="10,5"/>

    </Grid>
</Window>
"@
    $stringReaderMain = New-Object System.IO.StringReader($xamlMain)
    $xmlReaderMain = [System.Xml.XmlReader]::Create($stringReaderMain)
    $mainAppWindow = [System.Windows.Markup.XamlReader]::Load($xmlReaderMain)

    $ConfigStatusLabel = $mainAppWindow.FindName("ConfigStatusLabel")
    $StartProcessingButton = $mainAppWindow.FindName("StartProcessingButton")
    $SettingsButton = $mainAppWindow.FindName("SettingsButton")

    if (-not (Test-Path $script:configFilePath -PathType Leaf)) {
        $ConfigStatusLabel.Visibility = 'Visible'
    }

    $SettingsButton.add_Click({
        $outputConfigFromGui = Show-ConfigurationGui -InitialConfig $script:currentConfig
        if ($outputConfigFromGui -ne $null) {
            $script:currentConfig.dawarichApiUrl = $outputConfigFromGui.dawarichApiUrl
            $script:currentConfig.dawarichApiKey = $outputConfigFromGui.dawarichApiKey
            $script:currentConfig.photonApiUrl = $outputConfigFromGui.photonApiUrl
            $script:currentConfig.defaultTimeWindowSeconds = $outputConfigFromGui.defaultTimeWindowSeconds
            $script:currentConfig.exiftoolPath = $outputConfigFromGui.exiftoolPath
            $script:currentConfig.overwriteExisting = $outputConfigFromGui.overwriteExisting
            $script:currentConfig.alwaysQueryPhoton = $outputConfigFromGui.alwaysQueryPhoton
            
            Write-Host "Settings updated in current session."
            if ($outputConfigFromGui.saveConfig) {
                $configToSave = $outputConfigFromGui.Clone()
                $configToSave.Remove("saveConfig") | Out-Null
                Save-Configuration -FilePath $script:configFilePath -ConfigData $configToSave
                $ConfigStatusLabel.Visibility = 'Collapsed' 
            }
        } else {
            Write-Host "Settings window cancelled."
        }
    })

    $StartProcessingButton.add_Click({
        $exiftoolPathToCheck = $script:currentConfig.exiftoolPath
        $exiftoolFound = $false
        if (Test-Path $exiftoolPathToCheck -PathType Leaf) {
            $exiftoolFound = $true
        } else {
            $chkPath = Get-Command $exiftoolPathToCheck -ErrorAction SilentlyContinue
            if ($chkPath) {
                $script:currentConfig.exiftoolPath = $chkPath.Source 
                $exiftoolFound = $true
                Write-Warning "Exiftool found in PATH and path updated in current config: $($script:currentConfig.exiftoolPath)"
            }
        }

        if (-not $exiftoolFound) {
            [System.Windows.MessageBox]::Show("Exiftool nicht gefunden unter '$exiftoolPathToCheck' oder im System-PATH. Bitte in den Einstellungen korrigieren.","Exiftool nicht gefunden",'OK','Error')
            return 
        }
        Write-Host "Using exiftool: $($script:currentConfig.exiftoolPath)"
        if($script:currentConfig.overwriteExisting){Write-Host "Overwrite ON."-Fg Yellow}
        if($script:currentConfig.alwaysQueryPhoton){Write-Host "Always Query Photon ON."-Fg Yellow}

        $targetFolder = Select-FolderDialog -Description "Ordner mit Mediendateien auswählen"
        if (-not $targetFolder) {
            Write-Warning "Kein Ordner ausgewählt. Verarbeitung abgebrochen."
            return 
        }
        
        $mainAppWindow.Close() 
        Invoke-FileProcessing -TargetFolder $targetFolder -Config $script:currentConfig
    })

    $mainAppWindow.ShowDialog() | Out-Null
}


# ================== Configuration GUI FUNCTION (WPF) ==================
function Show-ConfigurationGui {
    param([hashtable]$InitialConfig) 
    Add-Type -AssemblyName PresentationFramework; Add-Type -AssemblyName PresentationCore; Add-Type -AssemblyName WindowsBase
    $xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" x:Name="ConfigWindow" Title="EXIF Updater Configuration - WPF" Height="470" Width="500" ResizeMode="NoResize" WindowStartupLocation="CenterScreen" Topmost="True">
    <Grid Margin="15">
        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="20"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="20"/><RowDefinition Height="*"/></Grid.RowDefinitions>
        <Grid.ColumnDefinitions><ColumnDefinition Width="Auto"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
        <Label Content="Dawarich API URL:" Grid.Row="0" Grid.Column="0" VerticalAlignment="Center" Margin="0,0,5,5"/><TextBox x:Name="DawarichApiUrlTextBox" Grid.Row="0" Grid.Column="1" VerticalAlignment="Center" Margin="0,0,0,5"/>
        <Label Content="Dawarich API Key:" Grid.Row="1" Grid.Column="0" VerticalAlignment="Center" Margin="0,0,5,5"/><TextBox x:Name="DawarichApiKeyTextBox" Grid.Row="1" Grid.Column="1" VerticalAlignment="Center" Margin="0,0,0,5"/>
        <Label Content="Photon API URL:" Grid.Row="2" Grid.Column="0" VerticalAlignment="Center" Margin="0,0,5,5"/><TextBox x:Name="PhotonApiUrlTextBox" Grid.Row="2" Grid.Column="1" VerticalAlignment="Center" Margin="0,0,0,5"/>
        <Label Content="API Time Window (sec):" Grid.Row="3" Grid.Column="0" VerticalAlignment="Center" Margin="0,0,5,5"/><TextBox x:Name="TimeWindowTextBox" Grid.Row="3" Grid.Column="1" VerticalAlignment="Center" Margin="0,0,0,5" Width="100" HorizontalAlignment="Left"/>
        <Label Content="Exiftool Path:" Grid.Row="4" Grid.Column="0" VerticalAlignment="Center" Margin="0,0,5,5"/><TextBox x:Name="ExiftoolPathTextBox" Grid.Row="4" Grid.Column="1" VerticalAlignment="Center" Margin="0,0,0,5"/>
        <CheckBox x:Name="OverwriteCheckBox" Content="Overwrite existing GPS/Location data in files" Grid.Row="6" Grid.Column="0" Grid.ColumnSpan="2" VerticalAlignment="Center" Margin="0,5,0,5"/>
        <CheckBox x:Name="AlwaysQueryPhotonCheckBox" Content="Always query Photon API (overwrites Dawarich location details for Images)" Grid.Row="7" Grid.Column="0" Grid.ColumnSpan="2" VerticalAlignment="Center" Margin="0,5,0,5"/>
        <CheckBox x:Name="SaveConfigCheckBox" Content="Save these settings to config.json (in script directory)" Grid.Row="8" Grid.Column="0" Grid.ColumnSpan="2" VerticalAlignment="Center" Margin="0,5,0,5"/>
        <StackPanel Grid.Row="10" Grid.ColumnSpan="2" Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Bottom">
            <Button x:Name="OkButton" Content="OK" Width="80" Height="30" Margin="5" IsDefault="True"/><Button x:Name="CancelButton" Content="Cancel" Width="80" Height="30" Margin="5" IsCancel="True"/>
        </StackPanel>
    </Grid>
</Window>
"@
    $stringReader = New-Object System.IO.StringReader($xaml); $xmlReader = [System.Xml.XmlReader]::Create($stringReader); $window = [System.Windows.Markup.XamlReader]::Load($xmlReader)
    $DawarichApiUrlTextBox=$window.FindName("DawarichApiUrlTextBox"); $DawarichApiKeyTextBox=$window.FindName("DawarichApiKeyTextBox"); $PhotonApiUrlTextBox=$window.FindName("PhotonApiUrlTextBox"); $TimeWindowTextBox=$window.FindName("TimeWindowTextBox"); $ExiftoolPathTextBox=$window.FindName("ExiftoolPathTextBox"); $OverwriteCheckBox=$window.FindName("OverwriteCheckBox"); $AlwaysQueryPhotonCheckBox=$window.FindName("AlwaysQueryPhotonCheckBox"); $SaveConfigCheckBox=$window.FindName("SaveConfigCheckBox"); $OkButton=$window.FindName("OkButton"); $CancelButton=$window.FindName("CancelButton")
    
    $DawarichApiUrlTextBox.Text=$InitialConfig.dawarichApiUrl
    $DawarichApiKeyTextBox.Text=$InitialConfig.dawarichApiKey
    $PhotonApiUrlTextBox.Text=$InitialConfig.photonApiUrl
    $TimeWindowTextBox.Text=$InitialConfig.defaultTimeWindowSeconds.ToString()
    $ExiftoolPathTextBox.Text=$InitialConfig.exiftoolPath
    $OverwriteCheckBox.IsChecked=$InitialConfig.overwriteExisting
    $AlwaysQueryPhotonCheckBox.IsChecked=$InitialConfig.alwaysQueryPhoton
    $SaveConfigCheckBox.IsChecked=$false 

    $resultFromGui = $null
    $OkButton.add_Click({
        $timeWindowValue=0
        if(-not([int]::TryParse($TimeWindowTextBox.Text,[ref]$timeWindowValue) -and $timeWindowValue -ge 0)){
            [System.Windows.MessageBox]::Show("Invalid Time Window. Must be non-negative integer.","Input Error",'OK','Error')
            return
        }
        $resultFromGui = @{
            dawarichApiUrl = $DawarichApiUrlTextBox.Text
            dawarichApiKey = $DawarichApiKeyTextBox.Text
            photonApiUrl = $PhotonApiUrlTextBox.Text
            defaultTimeWindowSeconds = $timeWindowValue
            exiftoolPath = $ExiftoolPathTextBox.Text
            overwriteExisting = $OverwriteCheckBox.IsChecked
            alwaysQueryPhoton = $AlwaysQueryPhotonCheckBox.IsChecked
            saveConfig = $SaveConfigCheckBox.IsChecked 
        }
        $window.DialogResult=$true
        $window.Close()
    })
    $CancelButton.add_Click({
        $resultFromGui = $null
        $window.DialogResult=$false
        $window.Close()
    })
    $window.Add_Closing({
        if($window.DialogResult -eq $null){ 
            $resultFromGui = $null
        }
    })
    
    $window.ShowDialog() | Out-Null
    return $resultFromGui 
}

# ================== Console Progress FUNCTION ==================
function Show-ConsoleProgress {
    param(
        [Parameter(Mandatory=$true)]
        [int]$CurrentFileIndex,
        [Parameter(Mandatory=$true)]
        [int]$TotalFiles,
        [Parameter(Mandatory=$true)]
        [string]$StatusMessage,
        [string]$MessageColor = 'Black' 
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $fullStatusMessage = "$timestamp - $StatusMessage"

    $percentComplete = 0
    if ($TotalFiles -gt 0) {
        $percentComplete = ($CurrentFileIndex / $TotalFiles) * 100
    }
    Write-Progress -Activity "Verarbeite Dateien" -Status "$CurrentFileIndex von $TotalFiles verarbeitet ($([int]$percentComplete)%)" -PercentComplete $percentComplete -Id 1
    
    $foregroundColor = switch ($MessageColor.ToLower()) {
        'red' { 'Red' }
        'yellow' { 'Yellow' }
        'green' { 'Green' }
        'orange' { 'DarkYellow' } 
        'gray' { 'Gray' }
        default { 'White' } 
    }
    Write-Host $fullStatusMessage -ForegroundColor $foregroundColor
}
#endregion

#region Helper Functions (Core Logic)
function Select-FolderDialog {
    param(
        [string]$Description="Ordner auswählen", 
        [string]$InitialDirectory=$null 
    )
    Add-Type -AssemblyName System.Windows.Forms
    $folderBrowser=New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description=$Description
    if (-not [string]::IsNullOrEmpty($InitialDirectory) -and (Test-Path $InitialDirectory -PathType Container)) {
        $folderBrowser.SelectedPath=$InitialDirectory
    }
    $folderBrowser.ShowNewFolderButton=$true 
    
    $ownerForm=New-Object System.Windows.Forms.Form -Property @{TopMost=$true;WindowState='Minimized';ShowInTaskbar=$false}
    $ownerForm.Show()
    $ownerForm.Hide() 
    $dialogResult=$folderBrowser.ShowDialog($ownerForm) 
    $ownerForm.Dispose() 

    if($dialogResult -eq [System.Windows.Forms.DialogResult]::OK){
        return $folderBrowser.SelectedPath
    }else{
        Write-Warning "Folder selection cancelled by user."
        return $null 
    }
}

function ConvertTo-ApiTimestamp {
    param([string]$ExifDateTimeString)
    if([string]::IsNullOrWhiteSpace($ExifDateTimeString)){return $null}
    $ExifDateTimeString=$ExifDateTimeString-replace '([+-]\d{2}):(\d{2})$','$1$2' 
    $cleanedString=$ExifDateTimeString.Split('.')[0] 
    $cleanedString = ($cleanedString -replace ":", "-") -replace " ", "T" 
    $formats=@("yyyy-MM-ddTHH-mm-ss","yyyy-MM-ddTHH-mm-sszzz","yyyy-MM-ddTHH-mm-ssZ");$parsedDate=$null
    foreach($format in $formats){try{$style=[System.Globalization.DateTimeStyles]::None;if($format.EndsWith("zzz")){$style=[System.Globalization.DateTimeStyles]::AdjustToUniversal}elseif($format.EndsWith("Z")){$style=[System.Globalization.DateTimeStyles]::AssumeUniversal};$parsedDate=[datetime]::ParseExact($cleanedString,$format,[System.Globalization.CultureInfo]::InvariantCulture,$style);break}catch{Write-Verbose "Parse fail '$cleanedString' fmt '$format': $($_.Exception.Message)"}}
    if($parsedDate){try{if($parsedDate.Kind-eq[System.DateTimeKind]::Unspecified){$parsedDate=[DateTime]::SpecifyKind($parsedDate,[DateTimeKind]::Local)};return $parsedDate.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")}catch{Write-Warning "Date convert error '$ExifDateTimeString': $($_.Exception.Message)";return $null}}else{Write-Warning "Cannot parse date '$ExifDateTimeString'";return $null}
}

function Convert-SexagesimalToDecimal {
    param(
        [Parameter(Mandatory=$true)]
        [string]$CoordinateString,
        [Parameter(Mandatory=$true)]
        [string]$Hemisphere # N, S, E, W
    )
    try {
        $cleanedString = $CoordinateString -replace "deg|'" -replace '"',''
        $parts = $cleanedString -split '[^0-9\.]+' | Where-Object {$_ -ne ""}
        
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
            $decimalDegrees = -$decimalDegrees
        }
        return $decimalDegrees
    } catch {
        Write-Warning "Error converting sexagesimal coordinate '$CoordinateString' ($Hemisphere): $($_.Exception.Message)"
        return $null
    }
}


function Get-DawarichDataFromApi {
    param([string]$BaseUrl,[string]$ApiKey,[string]$StartAt,[string]$EndAt) 
    Add-Type -AssemblyName System.Web
    $encodedStartAt=[System.Web.HttpUtility]::UrlEncode($StartAt);$encodedEndAt=[System.Web.HttpUtility]::UrlEncode($EndAt)
    $apiUrlEffective="$BaseUrl`?api_key=$ApiKey`&start_at=$encodedStartAt`&end_at=$encodedEndAt`&order=asc"
    Show-ConsoleProgress -StatusMessage "Querying Dawarich API: $apiUrlEffective" -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress
    try{$response=Invoke-RestMethod -Uri $apiUrlEffective -Method Get -TimeoutSec 120 -ErrorAction Stop;return $response}
    catch{
        $errMsg = "Dawarich API Error ($apiUrlEffective): $($_.Exception.Message)"
        Write-Error $errMsg
        Show-ConsoleProgress -StatusMessage "[ERROR] $errMsg" -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress -MessageColor Red
        if($_.Exception.Response){try{$s=$_.Exception.Response.GetResponseStream();$r=New-Object System.IO.StreamReader($s);$body=$r.ReadToEnd();Write-Error "API Body: $body"; Show-ConsoleProgress -StatusMessage "[ERROR] API Response Body: $body" -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress -MessageColor Red}catch{Write-Error "No error body."; Show-ConsoleProgress -StatusMessage "[ERROR] Could not read error response body." -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress -MessageColor Red}};return $null}
}

function Get-LocationFromPhoton {
    param([string]$BaseUrl,[double]$Latitude,[double]$Longitude) 
    $latStr=$Latitude.ToString([System.Globalization.CultureInfo]::InvariantCulture);$lonStr=$Longitude.ToString([System.Globalization.CultureInfo]::InvariantCulture)
    $photonReverseUrl="$BaseUrl/reverse?lat=$latStr&lon=$lonStr"
    Show-ConsoleProgress -StatusMessage "Querying Photon API: $photonReverseUrl" -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress
    try{
        $response=Invoke-RestMethod -Uri $photonReverseUrl -Method Get -TimeoutSec 60 -ErrorAction Stop
        $country=$null;$city=$null;$countryCode=$null;$state=$null
        if($response.features -ne $null -and $response.features.Count -gt 0){
            $props=$response.features[0].properties
            if($props-ne $null){
                $country=$props.country
                $city=$props.city
                $countryCode=$props.countrycode
                $state=$props.state 
                if([string]::IsNullOrWhiteSpace($city)){$city=$props.county}
                if([string]::IsNullOrWhiteSpace($city)){$city=$props.name} 
            }
        }else{
            Write-Warning "Photon no features."
            Show-ConsoleProgress -StatusMessage "[WARNING] Photon API response did not contain 'features' data." -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress -MessageColor Yellow
        }
        return @{Country=$country;City=$city;CountryCode=$countryCode;State=$state} 
    }
    catch{
        $errMsg = "Photon API Error ($photonReverseUrl): $($_.Exception.Message)"
        Write-Error $errMsg
        Show-ConsoleProgress -StatusMessage "[ERROR] $errMsg" -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress -MessageColor Red
        if($_.Exception.Response){try{$s=$_.Exception.Response.GetResponseStream();$r=New-Object System.IO.StreamReader($s);$body=$r.ReadToEnd();Write-Error "API Body: $body"; Show-ConsoleProgress -StatusMessage "[ERROR] Photon API Response Body: $body" -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress -MessageColor Red}catch{Write-Error "No error body."; Show-ConsoleProgress -StatusMessage "[ERROR] Could not read Photon error response body." -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress -MessageColor Red}};return $null}
}

function Test-DawarichResultIsValid {
    param(
        [Parameter(Mandatory=$true)]
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
    } else {
        Write-Verbose "Test-DawarichResultIsValid: Parsing failed OR coordinates are (0,0). LatParsed: $latParsed, LonParsed: $lonParsed, LatValue: $latC, LonValue: $lonC"
        return $false
    }
}

function Parse-DawarichTimestamp {
    param(
        [Parameter(Mandatory=$true)]
        $TimestampInput
    )
    $parsedDateTime = $null
    if ($TimestampInput -eq $null) {
        Show-ConsoleProgress -StatusMessage "[WARNING] Dawarich timestamp is missing." -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress -MessageColor Yellow
        Write-Warning "Dawarich timestamp is missing."
        return $null
    }

    if ($TimestampInput -is [long] -or $TimestampInput -is [int]) {
        try {
            $parsedDateTime = [datetimeoffset]::FromUnixTimeSeconds($TimestampInput).UtcDateTime
        } catch {
            Show-ConsoleProgress -StatusMessage "[WARNING] Dawarich Unix timestamp parse fail: $TimestampInput. Error: $($_.Exception.Message)" -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress -MessageColor Yellow
            Write-Warning "Dawarich Unix timestamp parse fail: $TimestampInput. Error: $($_.Exception.Message)"
            return $null
        }
    } elseif ($TimestampInput -is [string]) {
        $tsFormats = @(
            "yyyy-MM-ddTHH:mm:ssZ", "yyyy-MM-ddTHH:mm:ss.fZ", "yyyy-MM-ddTHH:mm:ss.ffZ",
            "yyyy-MM-ddTHH:mm:ss.fffZ", "yyyy-MM-ddTHH:mm:ss.ffffZ", "yyyy-MM-ddTHH:mm:ss.fffffZ",
            "yyyy-MM-ddTHH:mm:ss.ffffffZ", "yyyy-MM-ddTHH:mm:ss.fffffffZ"
        )
        foreach ($fmt in $tsFormats) {
            try {
                $parsedDateTime = [datetime]::ParseExact($TimestampInput, $fmt, [System.Globalization.CultureInfo]::InvariantCulture, ([System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal))
                if ($parsedDateTime) { break } 
            } catch {
                # Continue to next format
            }
        }
        if (-not $parsedDateTime) {
            Show-ConsoleProgress -StatusMessage "[WARNING] Dawarich string timestamp parse fail for all formats: $TimestampInput" -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress -MessageColor Yellow
            Write-Warning "Dawarich string timestamp parse fail for all formats: $TimestampInput"
            return $null
        }
    } else {
        Show-ConsoleProgress -StatusMessage "[WARNING] Unknown Dawarich timestamp type: $($TimestampInput.GetType().FullName)" -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress -MessageColor Yellow
        Write-Warning "Unknown Dawarich timestamp type: $($TimestampInput.GetType().FullName)"
        return $null
    }
    return $parsedDateTime
}

function Set-ExifData {
    param(
        [string]$ExiftoolExePath,
        [string]$FilePath,
        [double]$Latitude,
        [double]$Longitude,
        [string]$Country, 
        [string]$City,    
        [string]$CountryCode,
        [string]$State 
    )
    $fileInfo=Get-Item -LiteralPath $FilePath;$isMp4=$fileInfo.Extension.ToLower() -eq ".mp4"
    $tagArgs=@();$exifArgs=@();$outputTargetDescription=""

    if($isMp4){
        $outputTargetDescription="GPS (Google Photos format) into MP4 '$($fileInfo.Name)'"
        $latF=([Math]::Abs($Latitude)).ToString("F4",[System.Globalization.CultureInfo]::InvariantCulture);$lonF=([Math]::Abs($Longitude)).ToString("F4",[System.Globalization.CultureInfo]::InvariantCulture)
        $latS=if($Latitude -ge 0){"+"}else{"-"};$lonS=if($Longitude -ge 0){"+"}else{"-"}
        $udGpsStr='"{0}{1}, {2}{3}, 0"'-f $latS,$latF,$lonS,$lonF
        $tagArgs=@("-UserData:GPSCoordinates=$udGpsStr","-GPSAltitude=0","-GPSAltitudeRef=0") 
        $exifArgs+="-overwrite_original";$exifArgs+=$tagArgs;$exifArgs+="`"$FilePath`""
    }else{ 
        $outputTargetDescription="metadata directly into image file '$($fileInfo.Name)'"
        $latRef=if($Latitude -ge 0){"N"}else{"S"};$lonRef=if($Longitude -ge 0){"E"}else{"W"}
        $latAbs=[Math]::Abs($Latitude).ToString([System.Globalization.CultureInfo]::InvariantCulture);$lonAbs=[Math]::Abs($Longitude).ToString([System.Globalization.CultureInfo]::InvariantCulture)
        $tagArgs=@("-GPSLatitude=$latAbs","-GPSLatitudeRef=$latRef","-GPSLongitude=$lonAbs","-GPSLongitudeRef=$lonRef","-XMP:GPSLatitude=$latAbs","-XMP:GPSLongitude=$lonAbs")
        if(-not[string]::IsNullOrWhiteSpace($Country)){$tagArgs+="-Country=`"$Country`""}
        if(-not[string]::IsNullOrWhiteSpace($City)){$tagArgs+="-City=`"$City`""}
        if(-not[string]::IsNullOrWhiteSpace($CountryCode)){$tagArgs+="-XMP-iptcCore:CountryCode=`"$CountryCode`""}
        if(-not[string]::IsNullOrWhiteSpace($State)){$tagArgs+="-XMP-photoshop:State=`"$State`""} 
        $exifArgs+="-overwrite_original";$exifArgs+=$tagArgs;$exifArgs+="`"$FilePath`""
    }

    try{
        $cmdLog = "$ExiftoolExePath $($exifArgs -join ' ')"
        Show-ConsoleProgress -StatusMessage "Executing exiftool write to $outputTargetDescription" -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress
        Show-ConsoleProgress -StatusMessage "Command: $cmdLog" -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress

        $pInfo=New-Object System.Diagnostics.ProcessStartInfo;$pInfo.FileName=$ExiftoolExePath;$pInfo.Arguments=$exifArgs-join ' ';$pInfo.RedirectStandardOutput=$true;$pInfo.RedirectStandardError=$true;$pInfo.UseShellExecute=$false;$pInfo.CreateNoWindow=$true
        $proc=New-Object System.Diagnostics.Process;$proc.StartInfo=$pInfo;$proc.Start()|Out-Null;$stdOut=$proc.StandardOutput.ReadToEnd();$stdErr=$proc.StandardError.ReadToEnd();$proc.WaitForExit()

        if($proc.ExitCode -ne 0){
            if($proc.ExitCode -eq 1 -and ($stdErr -match 'Nothing to write|0 image files updated|0 output files created|0 video files updated|File not changed')){
                $warnMsg = "No changes needed for $outputTargetDescription (tags identical)."
                Write-Host "     -> $warnMsg" -ForegroundColor Yellow
                Show-ConsoleProgress -StatusMessage "[WARNING] $warnMsg" -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress -MessageColor Yellow
                if($stdErr-notmatch 'Nothing to write|0 image files updated|0 output files created|0 video files updated|File not changed'){ Write-Warning "Exiftool warnings: $stdErr"; Show-ConsoleProgress -StatusMessage "[WARNING] Exiftool warnings: $stdErr" -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress -MessageColor Yellow}
                return $true
            } else {
                $errMsg = "Exiftool write error $($proc.ExitCode) for ${outputTargetDescription}. Stderr: $stdErr Stdout: $stdOut"
                Write-Error $errMsg
                Show-ConsoleProgress -StatusMessage "[ERROR] $errMsg" -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress -MessageColor Red
                return $false
            }
        } else {
            $successMsg = "Metadata written to $outputTargetDescription."
            Write-Host "     -> $successMsg" -ForegroundColor Green
            Show-ConsoleProgress -StatusMessage $successMsg -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress -MessageColor Green
            $sPattern='1 image files updated|1 output files created|1 video files updated';
            if(-not[string]::IsNullOrWhiteSpace($stdOut) -and $stdOut-notmatch $sPattern){ Write-Verbose "Exiftool out: $stdOut"; Show-ConsoleProgress -StatusMessage "Exiftool output: $stdOut" -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress }
            if(-not[string]::IsNullOrWhiteSpace($stdErr) -and $stdErr-notmatch $sPattern){ Write-Warning "Exiftool warn: $stdErr"; Show-ConsoleProgress -StatusMessage "[WARNING] Exiftool warnings: $stdErr" -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress -MessageColor Yellow}
            return $true
        }
    } catch {
        $errMsg = "Exiftool exec error for ${outputTargetDescription}: $($_.Exception.Message)"
        Write-Error $errMsg
        Show-ConsoleProgress -StatusMessage "[ERROR] $errMsg" -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress -MessageColor Red
        return $false
    }
}
#endregion

#region Main Processing Logic
function Invoke-FileProcessing {
    param(
        [string]$TargetFolder,
        [hashtable]$Config
    )

    Write-Host "`nProcessing folder: $TargetFolder"

    $dawarichApiUrl = $Config.dawarichApiUrl
    $dawarichApiKey = $Config.dawarichApiKey
    $photonApiUrl = $Config.photonApiUrl
    $defaultTimeWindowSeconds = $Config.defaultTimeWindowSeconds
    $exiftoolPath = $Config.exiftoolPath
    $overwriteExistingData = $Config.overwriteExisting
    $alwaysQueryPhoton = $Config.alwaysQueryPhoton

    $imageExtensions=@(".jpg",".jpeg",".png",".tiff",".heic",".gif",".cr2",".dng");$videoExtensions=@(".mp4");$allExtensions=$imageExtensions+$videoExtensions
    $largeFileThresholdMB=200;$largeFileThresholdBytes=$largeFileThresholdMB*1024*1024
    Write-Host "Searching for files: $($allExtensions -join ', ')"
    try{$filesToProcess=Get-ChildItem -Path $TargetFolder -File -EA Stop|Where-Object{$allExtensions -contains $_.Extension.ToLower()}}catch{Write-Error "Error finding files: $($_.Exception.Message)";return} 
    if($filesToProcess.Count -eq 0){Write-Warning "No matching files in '$TargetFolder'.";return} 
    Write-Host "$($filesToProcess.Count) files found. Starting processing..."

    $processedCount=0;$updatedCount=0;$errorCount=0
    $skippedFiles=[System.Collections.Generic.List[string]]::new()
    $noApiDataFiles=[System.Collections.Generic.List[string]]::new()
    $script:totalFilesForProgress = $filesToProcess.Count 

    try { 
        foreach ($file in $filesToProcess) {
            $processedCount++
            $script:currentFileIndexForProgress = $processedCount

            Show-ConsoleProgress -StatusMessage "Processing: $($file.Name)" -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress
            
            $fileHadError=$false; $isMp4File=$file.Extension.ToLower() -eq ".mp4"; $bestMatchApiResult=$null
            if($file.Length -gt $largeFileThresholdBytes){ Show-ConsoleProgress -StatusMessage "     -> Large file ($($file.Length/1MB -as [int])MB). May take time..." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress -MessageColor Gray }

            $exifReadArgs=@("-j","-GPSLatitude","-GPSLongitude","-GPSLatitudeRef","-GPSLongitudeRef",
                            "-Composite:GPSLatitude","-Composite:GPSLongitude",
                            "-UserData:GPSCoordinates", "-Rotation", 
                            "-Country","-City","-XMP-photoshop:State","-XMP-iptcCore:CountryCode", 
                            "-DateTimeOriginal","-CreateDate","-MediaCreateDate","-TrackCreateDate",
                            "-FilePath")
            $exifData=$null
            try {
                Show-ConsoleProgress -StatusMessage "     Reading metadata..." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress
                $qExifPath=if($exiftoolPath-match '\s'){"`"$exiftoolPath`""}else{$exiftoolPath}; $qFilePath="`"$($file.FullName)`""
                $cmdStr="$qExifPath -common_args $($exifReadArgs -join ' ') $qFilePath"; Write-Verbose "Exif read: $cmdStr"
                $exifOut=Invoke-Expression $cmdStr -EA Stop; $tmpJson=$exifOut|ConvertFrom-Json -EA SilentlyContinue
                if($tmpJson -is [array]){$exifData=if($tmpJson.Count -gt 0){$tmpJson[0]}else{$null}}else{$exifData=$tmpJson}
                if($exifData -eq $null -and -not([string]::IsNullOrWhiteSpace($exifOut))){ Show-ConsoleProgress -StatusMessage "[WARNING] JSON parse fail for '$($file.Name)'." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress -MessageColor Yellow; Write-Warning "     JSON parse fail for '$($file.Name)'. Output: $exifOut"; throw}
                elseif($exifData -eq $null){ Show-ConsoleProgress -StatusMessage "     No EXIF/XMP data found. Skipping API processing." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress; continue}
            } catch { 
                Write-Warning "     Exif read error for '$($file.Name)': $($_.Exception.Message)"
                if($LASTEXITCODE-ne $null-and $LASTEXITCODE-ne 0){Write-Warning "     Exiftool exit code $LASTEXITCODE."}
                $fileHadError=$true;$errorCount++;
                continue 
            }
            
            $existingGpsLat=$null; $existingGpsLon=$null; $imageHasUsableExistingGps=$false; $mp4HasUsableExistingGps=$false
            if(-not $isMp4File -and $exifData){
                $latFromComposite = $null; $lonFromComposite = $null; $compositeParseSuccess = $false
                if($exifData.PSObject.Properties.Name -contains 'Composite:GPSLatitude' -and $exifData.PSObject.Properties.Name -contains 'Composite:GPSLongitude' -and $exifData.'Composite:GPSLatitude' -ne $null -and $exifData.'Composite:GPSLongitude' -ne $null){
                    try {
                        $latFromComposite = [double]$exifData.'Composite:GPSLatitude'
                        $lonFromComposite = [double]$exifData.'Composite:GPSLongitude'
                        if (($latFromComposite -ne 0 -or $lonFromComposite -ne 0) -and ($latFromComposite -ne $null -and $lonFromComposite -ne $null) ) {
                             $existingGpsLat = $latFromComposite; $existingGpsLon = $lonFromComposite
                             $imageHasUsableExistingGps = $true; $compositeParseSuccess = $true
                             Show-ConsoleProgress -StatusMessage "     Image using Composite GPS (Lat:$existingGpsLat, Lon:$existingGpsLon)." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress
                        }
                    } catch { Show-ConsoleProgress -StatusMessage "[VERBOSE] Could not parse Composite GPS directly as double for '$($file.Name)'. Will try standard tags." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress -MessageColor Gray }
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
                            } elseif ([double]::TryParse($exifData.GPSLatitude.ToString(), [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$latVal)) {
                                if ($exifData.GPSLatitudeRef -eq 'S') {$latVal = -$latVal}
                            } else {$latVal = $null}

                            if ($exifData.GPSLongitude -is [string] -and ($exifData.GPSLongitude -match "deg" -or $exifData.GPSLongitude -match "'" -or $exifData.GPSLongitude -match '"')) { 
                                 $lonVal = Convert-SexagesimalToDecimal -CoordinateString $exifData.GPSLongitude -Hemisphere $exifData.GPSLongitudeRef
                            } elseif ([double]::TryParse($exifData.GPSLongitude.ToString(), [System.Globalization.NumberStyles]::Any, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$lonVal)) {
                                if ($exifData.GPSLongitudeRef -eq 'W') {$lonVal = -$lonVal}
                            } else {$lonVal = $null}

                            if ($latVal -ne $null -and $lonVal -ne $null -and ($latVal -ne 0 -or $lonVal -ne 0)) {
                                $existingGpsLat = $latVal; $existingGpsLon = $lonVal
                                $imageHasUsableExistingGps = $true
                                Show-ConsoleProgress -StatusMessage "     Image using parsed Standard GPS (Lat:$existingGpsLat, Lon:$existingGpsLon)." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress
                            } else { Show-ConsoleProgress -StatusMessage "[WARNING] Could not parse standard GPS tags into valid decimal for '$($file.Name)'." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress -MessageColor Yellow }
                        } catch { Show-ConsoleProgress -StatusMessage "[WARNING] Error parsing standard GPS tags for '$($file.Name)': $($_.Exception.Message)" -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress -MessageColor Yellow }
                    }
                }
            } elseif($isMp4File -and $exifData){
                if($exifData.PSObject.Properties.Name -contains 'UserData:GPSCoordinates'){
                    $udGpsStr=$exifData.'UserData:GPSCoordinates'
                    if(-not [string]::IsNullOrWhiteSpace($udGpsStr)){
                        $udGpsStr=$udGpsStr.Trim("`"")
                        $gpsParts=$udGpsStr.Split(',')
                        if($gpsParts.Count -ge 2){
                            try { 
                                $latCand=[double]::Parse($gpsParts[0].Trim(),[System.Globalization.CultureInfo]::InvariantCulture)
                                $lonCand=[double]::Parse($gpsParts[1].Trim(),[System.Globalization.CultureInfo]::InvariantCulture)
                                if($latCand -ne 0 -or $lonCand -ne 0){
                                    $existingGpsLat=$latCand
                                    $existingGpsLon=$lonCand
                                    $mp4HasUsableExistingGps=$true
                                } else {
                                    Show-ConsoleProgress -StatusMessage "     MP4 UserData:GPS is (0,0)." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress
                                }
                            } catch { 
                                Show-ConsoleProgress -StatusMessage "[WARNING] Parse UserData:GPS fail for MP4 '$($file.Name)': $udGpsStr" -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress -MessageColor Yellow
                                Write-Warning "     Parse UserData:GPS fail for MP4 '$($file.Name)': $udGpsStr"
                            }
                        } else {
                            Show-ConsoleProgress -StatusMessage "[WARNING] UserData:GPS format error for MP4 '$($file.Name)': $udGpsStr" -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress -MessageColor Yellow
                            Write-Warning "     UserData:GPS format error for MP4 '$($file.Name)': $udGpsStr"
                        }
                    }
                }
            }
            
            $fileCompletelyHasData=$false; $hasRequiredGpsForFile=$false; $existingState = $null
            if ($exifData -ne $null -and $exifData.PSObject.Properties.Name -contains 'XMP-photoshop:State') {
                $existingState = $exifData.'XMP-photoshop:State'
            }

            if($isMp4File){
                $hasRequiredGpsForFile=$mp4HasUsableExistingGps
                $fileCompletelyHasData=$hasRequiredGpsForFile 
            } else { 
                $hasRequiredGpsForFile=$imageHasUsableExistingGps
                $hasLocImg=$false
                if ($exifData -ne $null) {
                    $imgCountry=$exifData.Country
                    $imgCity=$exifData.City
                    $imgCCode=$exifData.'XMP-iptcCore:CountryCode'
                    if(-not([string]::IsNullOrWhiteSpace($imgCountry)) -or -not([string]::IsNullOrWhiteSpace($imgCity)) -or -not([string]::IsNullOrWhiteSpace($imgCCode)) -or -not([string]::IsNullOrWhiteSpace($existingState)) ){
                        $hasLocImg=$true
                    }
                }
                $fileCompletelyHasData=$hasRequiredGpsForFile -and $hasLocImg
            }
            $shouldProcessFile=$false
            if($overwriteExistingData){
                $shouldProcessFile=$true
                Show-ConsoleProgress -StatusMessage "     -> Overwrite ON. File will be processed." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress 
            } elseif(-not $fileCompletelyHasData){
                $shouldProcessFile=$true
                $reason = ""
                if($isMp4File -and -not $hasRequiredGpsForFile){$reason="MP4 GPS missing."}
                elseif(-not $isMp4File){
                    if(-not $hasRequiredGpsForFile){$reason+="Image GPS missing. "}
                    if(-not $hasLocImg){$reason+="Image Location (Country/City/State/Code) missing."}
                }
                Show-ConsoleProgress -StatusMessage "     -> $reason Processing needed." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress 
            }
            
            if(-not $shouldProcessFile){ 
                Show-ConsoleProgress -StatusMessage "     -> No processing needed (data exists, overwrite OFF). Skipping." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress
                $skippedFiles.Add($file.FullName)
                continue
            }
            
            $latitudeToUse=$null; $longitudeToUse=$null; $countryToWrite=$null; $cityToWrite=$null; $countryCodeToWrite=$null; $stateToWrite = $null
    
            if(-not $isMp4File -and $imageHasUsableExistingGps){
                Show-ConsoleProgress -StatusMessage "     -> Image has GPS (Lat:$existingGpsLat,Lon:$existingGpsLon). Using it. Dawarich API skipped." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress -MessageColor Green
                $latitudeToUse=$existingGpsLat; $longitudeToUse=$existingGpsLon
                if ($exifData -ne $null) {
                    $countryToWrite=$exifData.Country
                    $cityToWrite=$exifData.City
                    $countryCodeToWrite=$exifData.'XMP-iptcCore:CountryCode'
                    $stateToWrite = $exifData.'XMP-photoshop:State' 
                }
                $needsPhoton=$false
                if($alwaysQueryPhoton){
                    $needsPhoton=$true
                    Show-ConsoleProgress -StatusMessage "     -> Always Query Photon ON." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress
                }elseif([string]::IsNullOrWhiteSpace($countryToWrite)-or[string]::IsNullOrWhiteSpace($cityToWrite)-or[string]::IsNullOrWhiteSpace($countryCodeToWrite)-or[string]::IsNullOrWhiteSpace($stateToWrite)){
                    $needsPhoton=$true
                    Show-ConsoleProgress -StatusMessage "     -> Existing location incomplete. Querying Photon." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress
                }
                if($needsPhoton){
                    $photonData=Get-LocationFromPhoton -BaseUrl $photonApiUrl -Latitude $latitudeToUse -Longitude $longitudeToUse 
                    if($photonData){ 
                        Show-ConsoleProgress -StatusMessage "         -> Photon found: C='$($photonData.Country)',Ci='$($photonData.City)',Co='$($photonData.CountryCode)',S='$($photonData.State)'" -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress
                        # If alwaysQueryPhoton is true, Photon values take precedence if they are not empty. Otherwise, existing values are kept.
                        if ($alwaysQueryPhoton) {
                            if (-not ([string]::IsNullOrWhiteSpace($photonData.Country))) { $countryToWrite = $photonData.Country }
                            if (-not ([string]::IsNullOrWhiteSpace($photonData.City)))    { $cityToWrite = $photonData.City }
                            if (-not ([string]::IsNullOrWhiteSpace($photonData.State)))   { $stateToWrite = $photonData.State }
                            if (-not ([string]::IsNullOrWhiteSpace($photonData.CountryCode))) { $countryCodeToWrite = $photonData.CountryCode }
                        } else { # Fill only if existing data was missing
                            if([string]::IsNullOrWhiteSpace($countryToWrite) -and -not([string]::IsNullOrWhiteSpace($photonData.Country))){$countryToWrite=$photonData.Country}
                            if([string]::IsNullOrWhiteSpace($cityToWrite) -and -not([string]::IsNullOrWhiteSpace($photonData.City))){$cityToWrite=$photonData.City}
                            if([string]::IsNullOrWhiteSpace($stateToWrite) -and -not([string]::IsNullOrWhiteSpace($photonData.State))){$stateToWrite=$photonData.State}
                            if([string]::IsNullOrWhiteSpace($countryCodeToWrite) -and -not([string]::IsNullOrWhiteSpace($photonData.CountryCode))){$countryCodeToWrite=$photonData.CountryCode}
                        }
                    } else { 
                        Show-ConsoleProgress -StatusMessage "[WARNING] Photon query failed for existing GPS. Existing location data will be used if available." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress -MessageColor Yellow
                        Write-Warning "     -> Photon query failed for existing GPS."
                    }
                } else { 
                    Show-ConsoleProgress -StatusMessage "     -> Photon query not needed." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress
                }
            }
            elseif($isMp4File -and $mp4HasUsableExistingGps){
                Show-ConsoleProgress -StatusMessage "     -> MP4 has GPS (Lat:$existingGpsLat,Lon:$existingGpsLon). Using it. Dawarich API skipped." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress -MessageColor Green
                $latitudeToUse=$existingGpsLat; $longitudeToUse=$existingGpsLon
            }
            else { # File (Image or MP4) needs Dawarich API
                $fileTypeStr = if($isMp4File){'MP4'}else{'Image'}
                Show-ConsoleProgress -StatusMessage "     -> File ($fileTypeStr) no usable existing GPS or overwrite forces API. Using Dawarich." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress
                $creationDateStr=$null
                if ($exifData -ne $null) {
                    if($exifData.DateTimeOriginal){$creationDateStr=$exifData.DateTimeOriginal}elseif($exifData.CreateDate){$creationDateStr=$exifData.CreateDate}elseif($exifData.MediaCreateDate){$creationDateStr=$exifData.MediaCreateDate}elseif($exifData.TrackCreateDate){$creationDateStr=$exifData.TrackCreateDate}
                }
                if([string]::IsNullOrWhiteSpace($creationDateStr)){ Show-ConsoleProgress -StatusMessage "[WARNING] No creation date found. Skipping API lookup." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress -MessageColor Yellow; Write-Warning "     No creation date for '$($file.Name)'. Skipping API.";$noApiDataFiles.Add($file.FullName);$fileHadError=$true;$errorCount++; continue}
                $fileTimestampUTC=ConvertTo-ApiTimestamp -ExifDateTimeString $creationDateStr
                if($fileTimestampUTC -eq $null){ Show-ConsoleProgress -StatusMessage "[WARNING] Date convert fail for API. Skipping." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress -MessageColor Yellow; Write-Warning "     Date convert fail for API '$($file.Name)'.";$noApiDataFiles.Add($file.FullName);$fileHadError=$true;$errorCount++; continue}
                $fileDateTime=$null;try{$fileDateTime=[datetime]::ParseExact($fileTimestampUTC,"yyyy-MM-ddTHH:mm:ssZ",[System.Globalization.CultureInfo]::InvariantCulture,([System.Globalization.DateTimeStyles]::AssumeUniversal-bor[System.Globalization.DateTimeStyles]::AdjustToUniversal))}catch{ Show-ConsoleProgress -StatusMessage "[WARNING] Parse UTC timestamp fail. Skipping." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress -MessageColor Yellow; Write-Warning "     Parse UTC fail '$($file.Name)'.";$noApiDataFiles.Add($file.FullName);$fileHadError=$true;$errorCount++; continue}
                Show-ConsoleProgress -StatusMessage "     Creation (UTC): $fileTimestampUTC" -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress
                $startAt=$fileDateTime.AddSeconds(-$defaultTimeWindowSeconds).ToString("yyyy-MM-ddTHH:mm:ssZ");$endAt=$fileDateTime.AddSeconds($defaultTimeWindowSeconds).ToString("yyyy-MM-ddTHH:mm:ssZ")
                
                $apiResultRange=Get-DawarichDataFromApi -BaseUrl $dawarichApiUrl -ApiKey $dawarichApiKey -StartAt $startAt -EndAt $endAt
                if($apiResultRange){
                    $resArr=@($apiResultRange)
                    if($resArr.Count -gt 0){
                        $validRes = $resArr | Where-Object { Test-DawarichResultIsValid -Result $_ }
                        if($validRes.Count -gt 0){
                            Show-ConsoleProgress -StatusMessage "     -> $($validRes.Count) valid Dawarich results. Finding closest..." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress
                            $closestDiff=[double]::MaxValue
                            foreach($res in $validRes){
                                try {
                                    $resTs = Parse-DawarichTimestamp -TimestampInput $res.timestamp 
                                    if($resTs){
                                        $tDiff = New-TimeSpan -Start $fileDateTime -End $resTs
                                        $absDiff = [Math]::Abs($tDiff.TotalSeconds)
                                        if($absDiff -lt $closestDiff){
                                            $closestDiff = $absDiff
                                            $bestMatchApiResult = $res
                                        }
                                    }
                                } catch {
                                    $errMsgInnerLoop = "Error processing Dawarich result for timestamp comparison: '$($res.timestamp)' - $($_.Exception.Message)"
                                    Show-ConsoleProgress -StatusMessage "[WARNING] $errMsgInnerLoop" -CurrentFileIndex $script:currentFileIndexForProgress -TotalFiles $script:totalFilesForProgress -MessageColor Yellow
                                    Write-Warning $errMsgInnerLoop
                                }
                            }
                            if($bestMatchApiResult){ Show-ConsoleProgress -StatusMessage "     -> Closest Dawarich match (Diff: $($closestDiff.ToString('F2'))s)." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress }
                            else{ Show-ConsoleProgress -StatusMessage "     -> No time-comparable Dawarich result." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress }
                        } else { Show-ConsoleProgress -StatusMessage "     -> Dawarich results, but no valid non-zero coords." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress }
                    } else { Show-ConsoleProgress -StatusMessage "     -> No results from Dawarich." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress }
                } else { Show-ConsoleProgress -StatusMessage "     -> Dawarich API query failed." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress }

                if($bestMatchApiResult){
                    [double]::TryParse($bestMatchApiResult.latitude.ToString(),[System.Globalization.NumberStyles]::Any,[System.Globalization.CultureInfo]::InvariantCulture,[ref]$latitudeToUse) | Out-Null
                    [double]::TryParse($bestMatchApiResult.longitude.ToString(),[System.Globalization.NumberStyles]::Any,[System.Globalization.CultureInfo]::InvariantCulture,[ref]$longitudeToUse) | Out-Null
                    if($latitudeToUse -eq $null -or $longitudeToUse -eq $null -or ($latitudeToUse -eq 0 -and $longitudeToUse -eq 0)){ 
                        Show-ConsoleProgress -StatusMessage "[WARNING] Invalid/zero lat/lon from Dawarich. Skipping write." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress -MessageColor Yellow
                        Write-Warning "     -> Invalid/zero lat/lon from Dawarich for '$($file.Name)'."
                        $noApiDataFiles.Add($file.FullName);$fileHadError=$true;$errorCount++; continue
                    }
                    $countryToWrite=$bestMatchApiResult.country
                    $cityToWrite=$bestMatchApiResult.city
                    $countryCodeToWrite=$bestMatchApiResult.country_code
                    # $stateToWrite = $bestMatchApiResult.state # Assuming Dawarich might provide state, adjust if property name is different
                    
                    if(-not $isMp4File){
                        $needsPhoton=$false
                        if($alwaysQueryPhoton){
                            $needsPhoton=$true
                            Show-ConsoleProgress -StatusMessage "     -> Always Query Photon ON." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress
                        }elseif([string]::IsNullOrWhiteSpace($countryToWrite)-or[string]::IsNullOrWhiteSpace($cityToWrite)-or[string]::IsNullOrWhiteSpace($countryCodeToWrite) -or [string]::IsNullOrWhiteSpace($stateToWrite) ){
                            $needsPhoton=$true
                            Show-ConsoleProgress -StatusMessage "     -> Dawarich/Existing location incomplete. Querying Photon." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress
                        }
                        if($needsPhoton){
                            $photonData=Get-LocationFromPhoton -BaseUrl $photonApiUrl -Latitude $latitudeToUse -Longitude $longitudeToUse 
                            if($photonData){ 
                                Show-ConsoleProgress -StatusMessage "         -> Photon found: C='$($photonData.Country)',Ci='$($photonData.City)',Co='$($photonData.CountryCode)',S='$($photonData.State)'" -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress
                                # If alwaysQueryPhoton is true, Photon values take precedence if they are not empty. Otherwise, existing values (from Dawarich) are kept.
                                if ($alwaysQueryPhoton) {
                                    if (-not ([string]::IsNullOrWhiteSpace($photonData.Country))) { $countryToWrite = $photonData.Country }
                                    if (-not ([string]::IsNullOrWhiteSpace($photonData.City)))    { $cityToWrite = $photonData.City }
                                    if (-not ([string]::IsNullOrWhiteSpace($photonData.State)))   { $stateToWrite = $photonData.State }
                                    if (-not ([string]::IsNullOrWhiteSpace($photonData.CountryCode))) { $countryCodeToWrite = $photonData.CountryCode }
                                } else { # Fill only if Dawarich data was missing
                                    if([string]::IsNullOrWhiteSpace($countryToWrite) -and -not([string]::IsNullOrWhiteSpace($photonData.Country))){$countryToWrite=$photonData.Country}
                                    if([string]::IsNullOrWhiteSpace($cityToWrite) -and -not([string]::IsNullOrWhiteSpace($photonData.City))){$cityToWrite=$photonData.City}
                                    if([string]::IsNullOrWhiteSpace($stateToWrite) -and -not([string]::IsNullOrWhiteSpace($photonData.State))){$stateToWrite=$photonData.State}
                                    if([string]::IsNullOrWhiteSpace($countryCodeToWrite) -and -not([string]::IsNullOrWhiteSpace($photonData.CountryCode))){$countryCodeToWrite=$photonData.CountryCode}
                                }
                            } else { 
                                Show-ConsoleProgress -StatusMessage "[WARNING] Photon query failed. Existing/Dawarich location data will be used if available." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress -MessageColor Yellow
                                Write-Warning "     -> Photon query failed."
                            }
                        }
                    }
                } else { 
                    Show-ConsoleProgress -StatusMessage "     -> No suitable GPS from Dawarich API. Skipping write." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress
                    Write-Host "     -> No suitable GPS from Dawarich API for '$($file.Name)'."
                    $noApiDataFiles.Add($file.FullName)
                    continue
                }
            } 

            if ($latitudeToUse -ne $null -and $longitudeToUse -ne $null -and ($latitudeToUse -ne 0 -or $longitudeToUse -ne 0)) {
                $writeSuccess=Set-ExifData -ExiftoolExePath $exiftoolPath -FilePath $file.FullName `
                                            -Latitude $latitudeToUse -Longitude $longitudeToUse `
                                            -Country $countryToWrite -City $cityToWrite -CountryCode $countryCodeToWrite `
                                            -State $stateToWrite 
                if(-not $writeSuccess){$fileHadError=$true;$errorCount++}else{$updatedCount++}
            } elseif ($shouldProcessFile) { 
                Show-ConsoleProgress -StatusMessage "[WARNING] No usable GPS determined after all checks. File not updated." -CurrentFileIndex $processedCount -TotalFiles $script:totalFilesForProgress -MessageColor Yellow
                Write-Warning "     -> No usable GPS determined for '$($file.Name)' after all checks. File not updated."
                $noApiDataFiles.Add($file.FullName)
            }
             
            Start-Sleep -Milliseconds 10
             
        } # end foreach file
    } finally {
        Write-Progress -Activity "Verarbeitung" -Completed -Id 1 
    }

    # --- Final Summary (to Console) ---
    Write-Host "`n--- FINAL SUMMARY ---" -ForegroundColor Green
    Write-Host " * Files scanned: $processedCount"
    Write-Host " * Files updated successfully: $updatedCount"
    if($errorCount -gt 0){Write-Host " * Files with errors during processing: $errorCount" -Fg Yellow}
    if($skippedFiles.Count -gt 0){Write-Host "`n--- Files Skipped (Data OK, Overwrite OFF) ---" -Fg Cyan;$skippedFiles|% {Write-Host " - $_"}}
    if($noApiDataFiles.Count -gt 0){Write-Host "`n--- Files Skipped (No API Data/Invalid Coords/Processing Error) ---" -Fg Cyan;$noApiDataFiles|% {Write-Host " - $_"}}
    Write-Host "`nScript ended."
}
#endregion

# --- Script Entry Point ---
# Load initial configuration
$script:currentConfig = Load-Configuration -FilePath $configFilePath -Defaults $defaultConfig

# Show the main application window
Show-MainGui

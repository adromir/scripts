<#
.SYNOPSIS
    Updates or removes preview/thumbnail tags from RAW files using appropriate tools based on file type,
    with configurable tool paths and validation. Adds basic enhancement to generated previews.
    Allows processing a folder or specific files.

.DESCRIPTION
    This script presents a WPF GUI to select either a target folder or specific files, plus options
    (subfolders for folder mode, backups for both modes).
    It loads/saves external tool paths (ExifTool, ImageMagick, dcraw, DNG Converter) from/to a
    'tool_paths.json' file in the script directory.
    It presents a validation dialog to check/confirm tool paths, allowing manual browsing
    (filtered for specific executables), saving the configuration, and attempting winget
    installation for missing tools. Both GUI windows are set to be Topmost.
    It filters for common RAW file extensions.
    Based on the selection mode:
    - Folder Mode: Processes all matching RAW files in the selected folder (and optionally subfolders).
    - Files Mode: Processes only the specifically selected RAW files.
    Processing Logic per file:
    - If the file is a .DNG: Uses Adobe DNG Converter (from configured path) to re-save the file.
    - If the file is another supported RAW type: Uses ImageMagick (resize 50%, normalize, gaussian-blur)
      and ExifTool (from configured paths) to generate and embed an enhanced preview.
    Handles backups/overwrites based on user selection.

.NOTES
    Author: Adromir
    Date:   2025-05-02
    Requires:
        - PowerShell v3.0 or higher
        - Winget (for installing dependencies if needed).
        - External Tools (will prompt for install/location):
            - ExifTool (exiftool.exe)
            - ImageMagick (magick.exe)
            - dcraw (dcraw.exe)
            - Adobe DNG Converter
    Configuration:
        - Saves/Loads tool paths from tool_paths.json in the script's directory.
    Fixes:
        - Added explicit quotes around DNG Converter executable path for Start-Process.
        - Used format operator (-f) for Write-Progress status string.
        - Used format operator (-f) for Write-Error string in Install-DependencyViaWinget.
        - Used call operator (&) for invoking script blocks in validation dialog.
        - Added specific file filters to browse dialogs in validation window.
        - Improved error handling and logging for DNG file replacement logic.
        - DNG Converter success check now based on output file existence, not exit code/stderr.
        - Revised Get-ChildItem result handling to avoid AddRange type issue.
    Changes:
        - Updated ImageMagick command syntax for v7+ (removed explicit 'convert').
        - ImageMagick enhancement now uses -resize 50%, -normalize, -gaussian-blur 0.05.
        - DNG Converter now uses uncompressed (-u), medium preview (-p2), and embeds original raw (-e).
        - Added Topmost=$true to WPF windows.
        - Added option to select specific files instead of a folder in the main GUI.

.EXAMPLE
    .\update-previews-configurable.ps1
    (Launches the GUI, validates paths, processes files)

.EXAMPLE
    .\update-previews-configurable.ps1 -Verbose
    (Runs the script and also shows the verbose output, including DNG Converter stderr)
#>

# --- Configuration ---
# Tag to write the generated preview to using ExifTool (for non-DNG files)
$generatedPreviewTag = "PreviewImage"

# Common RAW file extensions (add or remove as needed)
$rawFileExtensions = @(
    ".CR2", ".CR3", ".NEF", ".ARW", ".DNG", ".ORF", ".RAF", ".RW2", ".PEF"
)

# Default paths (used if config file is missing or entry is blank)
$defaultPaths = @{
    ExifTool = "exiftool.exe" # Assume in PATH
    ImageMagick = "magick.exe"   # Assume in PATH
    Dcraw = "dcraw.exe"    # Assume in PATH
    DngConverter = "C:\Program Files\Adobe\Adobe DNG Converter\Adobe DNG Converter.exe"
}

# Configuration file path
$configFilePath = Join-Path -Path $PSScriptRoot -ChildPath "tool_paths.json"

# --- Global Variables for Tool Paths (Loaded from Config/Defaults) ---
$script:toolPaths = @{} # Initialize as empty hashtable

# --- Helper Function to Prompt for Winget Installation ---
function Install-DependencyViaWinget {
    param(
        [Parameter(Mandatory=$true)] [string]$ToolName,
        [Parameter(Mandatory=$true)] [string]$WingetId,
        [string]$ExpectedCommand # Optional: Command name to check in PATH after install
    )
    Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue
    $choice = [System.Windows.MessageBox]::Show(
        "$ToolName is required but was not found or its path is invalid. Do you want to attempt installation using winget?",
        "Install $ToolName?",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )
    if ($choice -ne [System.Windows.MessageBoxResult]::Yes) {
        Write-Host "User declined installation of $ToolName."
        return $false # Indicate failure/decline
    }

    Write-Host "Attempting to install $ToolName via winget..."
    try {
        if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
             Write-Error "winget.exe not found in PATH. Cannot install $ToolName automatically."
             return $false
        }
        $wingetArgs = "install --id=$WingetId -e --accept-package-agreements --accept-source-agreements --source winget"
        Write-Verbose "Executing: winget.exe $wingetArgs"
        Start-Process -FilePath "winget.exe" -ArgumentList $wingetArgs -Wait -WindowStyle Normal -ErrorAction Stop
        if ($LASTEXITCODE -ne 0) {
            Write-Error "Winget installation of $ToolName failed (Exit Code: $LASTEXITCODE)."
            return $false
        }
        Start-Sleep -Seconds 3
        Write-Host "$ToolName installed successfully via winget (hopefully)."
        # Re-checking the path needs to happen *after* returning to the validation dialog
        return $true # Indicate install attempt was made
    } catch {
         # Use format operator -f for Write-Error
         Write-Error ("Error running winget for {0}: {1}" -f $ToolName, $_.Exception.Message)
         return $false
    }
}

# --- Function to Validate a Tool Path ---
function Validate-ToolPath {
    param([string]$ToolPath)
    if ([string]::IsNullOrWhiteSpace($ToolPath)) { return $false }
    # Check if it's just a command name (assume in PATH) or a full path
    if ($ToolPath -match '[\\/]') { # Contains path separators
        return Test-Path $ToolPath -PathType Leaf
    } else { # Assume command name in PATH
        return (Get-Command $ToolPath -ErrorAction SilentlyContinue) -ne $null
    }
}

# --- Function to Load Tool Paths from Config ---
function Load-ToolPaths {
    param(
        [string]$ConfigPath,
        [hashtable]$Defaults
    )
    $loadedPaths = $Defaults.Clone() # Start with defaults
    if (Test-Path $ConfigPath -PathType Leaf) {
        Write-Verbose "Loading configuration from $ConfigPath"
        try {
            $jsonContent = Get-Content $ConfigPath -Raw -ErrorAction Stop
            $configFromFile = $jsonContent | ConvertFrom-Json -ErrorAction Stop
            if ($configFromFile -is [hashtable]) {
                # Merge loaded paths over defaults, only if value is not empty
                foreach ($key in $configFromFile.Keys) {
                    if ($loadedPaths.ContainsKey($key) -and -not [string]::IsNullOrWhiteSpace($configFromFile[$key])) {
                        $loadedPaths[$key] = $configFromFile[$key]
                        Write-Verbose "Loaded '$key' path: $($loadedPaths[$key])"
                    }
                }
            } else {
                 Write-Warning "Configuration file '$ConfigPath' does not contain a valid JSON object. Using defaults."
            }
        } catch {
            Write-Warning "Error reading or parsing configuration file '$ConfigPath'. Using defaults. Error: $($_.Exception.Message)"
        }
    } else {
        Write-Verbose "Configuration file not found. Using default paths."
    }
    return $loadedPaths
}

# --- Function to Save Tool Paths to Config ---
function Save-ToolPaths {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ConfigPath,
        [Parameter(Mandatory=$true)]
        [hashtable]$PathsToSave
    )
    Write-Host "Saving tool paths to $ConfigPath ..."
    try {
        $jsonOutput = $PathsToSave | ConvertTo-Json -Depth 3
        $jsonOutput | Out-File -FilePath $ConfigPath -Encoding UTF8 -Force -ErrorAction Stop
        Write-Host "Configuration saved successfully."
    } catch {
        Write-Error "Error saving configuration file '$ConfigPath': $($_.Exception.Message)"
    }
}


# --- Function to Show Path Validation Dialog ---
function Show-PathValidationDialog {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$CurrentPaths # Pass current paths in
    )
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName System.Windows.Forms # For OpenFileDialog

    # Define XAML for the validation window
    [xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Validate Tool Paths" SizeToContent="WidthAndHeight" WindowStartupLocation="CenterScreen" ResizeMode="NoResize" Topmost="True"> <StackPanel Margin="15">
        <TextBlock Text="Verify or locate the required external tools:" FontWeight="Bold" Margin="0,0,0,10"/>
        <Grid>
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="Auto"/> <ColumnDefinition Width="*"/>    <ColumnDefinition Width="Auto"/> <ColumnDefinition Width="Auto"/> </Grid.ColumnDefinitions>
            <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>

            <Label Content="ExifTool:" Grid.Row="0" Grid.Column="0" VerticalAlignment="Center"/>
            <TextBox x:Name="ExifToolPathTextBox" Grid.Row="0" Grid.Column="1" Margin="5,2" VerticalContentAlignment="Center" MinWidth="250"/>
            <Button x:Name="BrowseExifToolButton" Content="..." Grid.Row="0" Grid.Column="2" Margin="5,2" Padding="5,0" ToolTip="Browse for exiftool.exe"/>
            <Label x:Name="StatusExifToolLabel" Content="?" Grid.Row="0" Grid.Column="3" Margin="5,2" FontWeight="Bold" VerticalAlignment="Center"/>

            <Label Content="ImageMagick:" Grid.Row="1" Grid.Column="0" VerticalAlignment="Center"/>
            <TextBox x:Name="ImageMagickPathTextBox" Grid.Row="1" Grid.Column="1" Margin="5,2" VerticalContentAlignment="Center"/>
            <Button x:Name="BrowseImageMagickButton" Content="..." Grid.Row="1" Grid.Column="2" Margin="5,2" Padding="5,0" ToolTip="Browse for magick.exe"/>
            <Label x:Name="StatusImageMagickLabel" Content="?" Grid.Row="1" Grid.Column="3" Margin="5,2" FontWeight="Bold" VerticalAlignment="Center"/>

            <Label Content="dcraw:" Grid.Row="2" Grid.Column="0" VerticalAlignment="Center"/>
            <TextBox x:Name="DcrawPathTextBox" Grid.Row="2" Grid.Column="1" Margin="5,2" VerticalContentAlignment="Center"/>
            <Button x:Name="BrowseDcrawButton" Content="..." Grid.Row="2" Grid.Column="2" Margin="5,2" Padding="5,0" ToolTip="Browse for dcraw.exe"/>
            <Label x:Name="StatusDcrawLabel" Content="?" Grid.Row="2" Grid.Column="3" Margin="5,2" FontWeight="Bold" VerticalAlignment="Center"/>

            <Label Content="DNG Converter:" Grid.Row="3" Grid.Column="0" VerticalAlignment="Center"/>
            <TextBox x:Name="DngConverterPathTextBox" Grid.Row="3" Grid.Column="1" Margin="5,2" VerticalContentAlignment="Center"/>
            <Button x:Name="BrowseDngConverterButton" Content="..." Grid.Row="3" Grid.Column="2" Margin="5,2" Padding="5,0" ToolTip="Browse for Adobe DNG Converter.exe"/>
            <Label x:Name="StatusDngConverterLabel" Content="?" Grid.Row="3" Grid.Column="3" Margin="5,2" FontWeight="Bold" VerticalAlignment="Center"/>

        </Grid>

        <Separator Margin="0,15"/>

        <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,0,0,10">
             <Button x:Name="CheckPathsButton" Content="Check All Paths" Width="120" Margin="5" ToolTip="Verify if the tools can be found at the specified paths."/>
             <Button x:Name="InstallButton" Content="Install Missing (Winget)" Width="150" Margin="5" ToolTip="Attempt to install tools marked as 'Not Found' using winget."/>
        </StackPanel>
         <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
            <Button x:Name="SaveButton" Content="Save Configuration" Width="140" Margin="0,0,20,0" ToolTip="Save the current paths to tool_paths.json"/>
            <Button x:Name="ContinueButton" Content="Continue" Width="75" Margin="0,0,10,0" IsDefault="True" IsEnabled="False" ToolTip="Continue only when all required tools are found."/>
            <Button x:Name="CancelButton" Content="Cancel" Width="75" IsCancel="True"/>
        </StackPanel>
    </StackPanel>
</Window>
"@
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    try {
        $window = [System.Windows.Markup.XamlReader]::Load($reader)
        # Set Topmost property after loading
        $window.Topmost = $true
     }
    catch { Write-Error "Error loading Path Validation window: $($_.Exception.Message)"; return $null }

    # Get control references
    $controls = @{}
    $controls.ExifToolPath = $window.FindName("ExifToolPathTextBox")
    $controls.BrowseExifTool = $window.FindName("BrowseExifToolButton")
    $controls.StatusExifTool = $window.FindName("StatusExifToolLabel")
    $controls.ImageMagickPath = $window.FindName("ImageMagickPathTextBox")
    $controls.BrowseImageMagick = $window.FindName("BrowseImageMagickButton")
    $controls.StatusImageMagick = $window.FindName("StatusImageMagickLabel")
    $controls.DcrawPath = $window.FindName("DcrawPathTextBox")
    $controls.BrowseDcraw = $window.FindName("BrowseDcrawButton")
    $controls.StatusDcraw = $window.FindName("StatusDcrawLabel")
    $controls.DngConverterPath = $window.FindName("DngConverterPathTextBox")
    $controls.BrowseDngConverter = $window.FindName("BrowseDngConverterButton")
    $controls.StatusDngConverter = $window.FindName("StatusDngConverterLabel")
    $controls.CheckPaths = $window.FindName("CheckPathsButton")
    $controls.Install = $window.FindName("InstallButton")
    $controls.Save = $window.FindName("SaveButton")
    $controls.Continue = $window.FindName("ContinueButton")
    $controls.Cancel = $window.FindName("CancelButton")

    # Populate TextBoxes with current paths
    $controls.ExifToolPath.Text = $CurrentPaths.ExifTool
    $controls.ImageMagickPath.Text = $CurrentPaths.ImageMagick
    $controls.DcrawPath.Text = $CurrentPaths.Dcraw
    $controls.DngConverterPath.Text = $CurrentPaths.DngConverter

    # --- Helper function to update status labels ---
    $UpdateStatusLabel = {
        param($Label, $IsValid)
        if ($IsValid) {
            $Label.Content = "Found"
            $Label.Foreground = [System.Windows.Media.Brushes]::Green
        } else {
            $Label.Content = "Not Found"
            $Label.Foreground = [System.Windows.Media.Brushes]::Red
        }
    }

    # --- Helper function to check all paths and update UI ---
    $CheckAllAndUpdateUI = {
        $allValid = $true
        # Use call operator '&' when invoking the script block
        $isValid = Validate-ToolPath $controls.ExifToolPath.Text
        & $UpdateStatusLabel $controls.StatusExifTool $isValid
        if (-not $isValid) { $allValid = $false }

        $isValid = Validate-ToolPath $controls.ImageMagickPath.Text
        & $UpdateStatusLabel $controls.StatusImageMagick $isValid
        if (-not $isValid) { $allValid = $false }

        $isValid = Validate-ToolPath $controls.DcrawPath.Text
        & $UpdateStatusLabel $controls.StatusDcraw $isValid
        if (-not $isValid) { $allValid = $false }

        $isValid = Validate-ToolPath $controls.DngConverterPath.Text
        & $UpdateStatusLabel $controls.StatusDngConverter $isValid
        # DNG Converter path status doesn't block 'Continue'

        # Enable Continue only if ExifTool, ImageMagick, and dcraw are found
        $controls.Continue.IsEnabled = $allValid
        return $allValid # Return if core tools are valid
    }

    # --- Event Handlers ---
    $controls.BrowseExifTool.Add_Click({
        $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $openFileDialog.Filter = "ExifTool (exiftool.exe)|exiftool.exe|All files (*.*)|*.*" # Filter added
        $openFileDialog.Title = "Select ExifTool Executable"
        $openFileDialog.FileName = "exiftool.exe" # Default filename
        if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $controls.ExifToolPath.Text = $openFileDialog.FileName
            $CheckAllAndUpdateUI.Invoke() # Revalidate after browsing
        }
    })
    $controls.BrowseImageMagick.Add_Click({
        $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $openFileDialog.Filter = "ImageMagick (magick.exe)|magick.exe|All files (*.*)|*.*" # Filter added
        $openFileDialog.Title = "Select ImageMagick (magick.exe) Executable"
        $openFileDialog.FileName = "magick.exe" # Default filename
        if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $controls.ImageMagickPath.Text = $openFileDialog.FileName
            $CheckAllAndUpdateUI.Invoke()
        }
    })
     $controls.BrowseDcraw.Add_Click({
        $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $openFileDialog.Filter = "dcraw (dcraw.exe)|dcraw.exe|All files (*.*)|*.*" # Filter added
        $openFileDialog.Title = "Select dcraw Executable"
        $openFileDialog.FileName = "dcraw.exe" # Default filename
        if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $controls.DcrawPath.Text = $openFileDialog.FileName
            $CheckAllAndUpdateUI.Invoke()
        }
    })
    $controls.BrowseDngConverter.Add_Click({
        $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $openFileDialog.Filter = "DNG Converter (Adobe DNG Converter.exe)|Adobe DNG Converter.exe|All files (*.*)|*.*" # Filter added
        $openFileDialog.Title = "Select Adobe DNG Converter Executable"
        $openFileDialog.FileName = "Adobe DNG Converter.exe" # Default filename
        if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $controls.DngConverterPath.Text = $openFileDialog.FileName
            $CheckAllAndUpdateUI.Invoke()
        }
    })

    $controls.CheckPaths.Add_Click({ $CheckAllAndUpdateUI.Invoke() })

    $controls.Install.Add_Click({
        Write-Host "`nAttempting Winget installations..."
        $needsCheck = $false
        if ($controls.StatusExifTool.Content -eq "Not Found") {
            Install-DependencyViaWinget -ToolName "ExifTool" -WingetId "OliverBetz.ExifTool" -ExpectedCommand "exiftool.exe"
            $needsCheck = $true
        }
        if ($controls.StatusImageMagick.Content -eq "Not Found") {
            Install-DependencyViaWinget -ToolName "ImageMagick" -WingetId "ImageMagick.ImageMagick" -ExpectedCommand "magick.exe"
             $needsCheck = $true
        }
         if ($controls.StatusDcraw.Content -eq "Not Found") {
            Install-DependencyViaWinget -ToolName "dcraw" -WingetId "Dcraw.Dcraw" -ExpectedCommand "dcraw.exe"
             $needsCheck = $true
        }
         if ($controls.StatusDngConverter.Content -eq "Not Found") {
            Install-DependencyViaWinget -ToolName "Adobe DNG Converter" -WingetId "Adobe.DNGConverter"
             $needsCheck = $true
        }
        if ($needsCheck) {
            Write-Host "Install attempts finished. Please click 'Check All Paths' again."
        } else {
             Write-Host "No tools marked as 'Not Found'."
        }
    })

    $controls.Save.Add_Click({
        $pathsToSave = @{
            ExifTool = $controls.ExifToolPath.Text
            ImageMagick = $controls.ImageMagickPath.Text
            Dcraw = $controls.DcrawPath.Text
            DngConverter = $controls.DngConverterPath.Text
        }
        Save-ToolPaths -ConfigPath $script:configFilePath -PathsToSave $pathsToSave # Use global config path
    })

    $controls.Continue.Add_Click({
        # Return the validated paths
        $window.DialogResult = $true
        $window.Close()
    })

    # Initial check when dialog loads
    $CheckAllAndUpdateUI.Invoke()

    # Show the window modally
    $result = $window.ShowDialog()

    if ($result -eq $true) {
        # Return the paths from the text boxes
        return @{
            Result = $true
            ExifTool = $controls.ExifToolPath.Text
            ImageMagick = $controls.ImageMagickPath.Text
            Dcraw = $controls.DcrawPath.Text
            DngConverter = $controls.DngConverterPath.Text
        }
    } else {
        return @{ Result = $false } # Cancelled
    }
}


# --- Function to Show Folder/File Selection GUI (Main GUI) ---
function Show-FolderSelectionDialog {
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName System.Windows.Forms
    [xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Select Source and Options" SizeToContent="WidthAndHeight" WindowStartupLocation="CenterScreen" ResizeMode="NoResize" ShowInTaskbar="True" Topmost="True">
    <StackPanel Margin="15">
        <TextBlock Text="Select Processing Mode:" FontWeight="Bold" Margin="0,0,0,5"/>
        <StackPanel Orientation="Horizontal" Margin="0,0,0,10">
            <RadioButton x:Name="FolderModeRadio" Content="Process Folder" GroupName="Mode" IsChecked="True"/>
            <RadioButton x:Name="FileModeRadio" Content="Process Specific Files" GroupName="Mode" Margin="20,0,0,0"/>
        </StackPanel>

        <GroupBox x:Name="FolderGroupBox" Header="Folder Options" Padding="10">
            <StackPanel>
                <TextBlock Text="Select Target Folder:" FontWeight="Bold" Margin="0,0,0,5"/>
                <Grid>
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="*"/>
                        <ColumnDefinition Width="Auto"/>
                    </Grid.ColumnDefinitions>
                    <TextBox x:Name="FolderPathTextBox" Grid.Column="0" Margin="0,0,5,0" MinWidth="250" IsReadOnly="True" VerticalContentAlignment="Center"/>
                    <Button x:Name="BrowseFolderButton" Grid.Column="1" Content="Browse..." Padding="5,2"/>
                </Grid>
                 <CheckBox x:Name="IncludeSubfoldersCheckBox" Content="Include Subfolders" Margin="0,10,0,0"/>
           </StackPanel>
        </GroupBox>

        <GroupBox x:Name="FileGroupBox" Header="File Options" Padding="10" Margin="0,10,0,0" IsEnabled="False">
             <StackPanel>
                 <TextBlock Text="Select Target File(s):" FontWeight="Bold" Margin="0,0,0,5"/>
                 <Grid>
                     <Grid.ColumnDefinitions>
                         <ColumnDefinition Width="*"/>
                         <ColumnDefinition Width="Auto"/>
                     </Grid.ColumnDefinitions>
                     <TextBox x:Name="SelectedFilesTextBox" Grid.Column="0" Margin="0,0,5,0" MinWidth="250" IsReadOnly="True" VerticalContentAlignment="Center" Text="(No files selected)"/>
                     <Button x:Name="BrowseFilesButton" Grid.Column="1" Content="Select Files..." Padding="5,2"/>
                 </Grid>
             </StackPanel>
         </GroupBox>

        <CheckBox x:Name="CreateBackupsCheckBox" Content="Create Backups (.original files / _1.dng)" Margin="0,15,0,15"/>
        <TextBlock Text="Note: Only files with RAW extensions ($($rawFileExtensions -join ', ')) will be processed." FontSize="10" FontStyle="Italic" TextWrapping="Wrap" Margin="0,0,0,10"/>

        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
            <Button x:Name="OkButton" Content="OK" Width="75" Margin="0,0,10,0" IsDefault="True"/>
            <Button x:Name="CancelButton" Content="Cancel" Width="75" IsCancel="True"/>
        </StackPanel>
    </StackPanel>
</Window>
"@
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    try {
        $window = [System.Windows.Markup.XamlReader]::Load($reader)
        $window.Topmost = $true
    }
    catch { Write-Error "Error loading WPF window: $($_.Exception.Message)"; if ($_.Exception.InnerException) { Write-Error "Inner Exception: $($_.Exception.InnerException.Message)" }; return $null }

    # Get control references
    $folderModeRadio = $window.FindName("FolderModeRadio")
    $fileModeRadio = $window.FindName("FileModeRadio")
    $folderGroupBox = $window.FindName("FolderGroupBox")
    $fileGroupBox = $window.FindName("FileGroupBox")
    $folderPathTextBox = $window.FindName("FolderPathTextBox")
    $browseFolderButton = $window.FindName("BrowseFolderButton")
    $includeSubfoldersCheckBox = $window.FindName("IncludeSubfoldersCheckBox")
    $selectedFilesTextBox = $window.FindName("SelectedFilesTextBox")
    $browseFilesButton = $window.FindName("BrowseFilesButton")
    $createBackupsCheckBox = $window.FindName("CreateBackupsCheckBox")
    $okButton = $window.FindName("OkButton")
    $cancelButton = $window.FindName("CancelButton")

    # Store selected file paths
    $selectedFilePaths = [System.Collections.Generic.List[string]]::new()

    # --- Event Handlers ---
    $folderModeRadio.add_Checked({
        $folderGroupBox.IsEnabled = $true
        $fileGroupBox.IsEnabled = $false
        $includeSubfoldersCheckBox.IsEnabled = $true
    })
    $fileModeRadio.add_Checked({
        $folderGroupBox.IsEnabled = $false
        $fileGroupBox.IsEnabled = $true
        $includeSubfoldersCheckBox.IsEnabled = $false # Subfolders irrelevant for specific files
    })

    $browseFolderButton.Add_Click({
        $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
        $folderBrowser.Description = "Select the folder containing RAW files"
        $folderBrowser.ShowNewFolderButton = $false
        if(-not [string]::IsNullOrWhiteSpace($folderPathTextBox.Text) -and (Test-Path $folderPathTextBox.Text -PathType Container)) { $folderBrowser.SelectedPath = $folderPathTextBox.Text }
        if ($folderBrowser.ShowDialog([System.Windows.Forms.NativeWindow]::new()) -eq [System.Windows.Forms.DialogResult]::OK) { $folderPathTextBox.Text = $folderBrowser.SelectedPath }
        $folderBrowser.Dispose()
    })

    $browseFilesButton.Add_Click({
        $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
        $openFileDialog.Multiselect = $true
        $openFileDialog.Filter = "RAW Files ($($rawFileExtensions -join ', '))|$(($rawFileExtensions | ForEach-Object { "*$_" }) -join ';')|All files (*.*)|*.*"
        $openFileDialog.Title = "Select RAW File(s)"
        if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $selectedFilePaths.Clear()
            $selectedFilePaths.AddRange($openFileDialog.FileNames)
            if ($selectedFilePaths.Count -gt 0) {
                # Display filenames, comma-separated, truncate if too long
                $displayNames = ($selectedFilePaths | ForEach-Object { [System.IO.Path]::GetFileName($_) }) -join ', '
                if ($displayNames.Length -gt 100) { $displayNames = $displayNames.Substring(0, 97) + "..." }
                 $selectedFilesTextBox.Text = $displayNames
            } else {
                 $selectedFilesTextBox.Text = "(No files selected)"
            }
        }
    })

    $okButton.Add_Click({
        $selectionData = @{ CreateBackups = $createBackupsCheckBox.IsChecked; Result = $true }

        if ($folderModeRadio.IsChecked) {
            if ([string]::IsNullOrWhiteSpace($folderPathTextBox.Text) -or (-not(Test-Path $folderPathTextBox.Text -PathType Container))) {
                [System.Windows.MessageBox]::Show("Please select a valid folder first.", "Folder Required", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
                return # Stay in dialog
            }
            $selectionData.SelectionMode = 'Folder'
            $selectionData.FolderPath = $folderPathTextBox.Text
            $selectionData.IncludeSubfolders = $includeSubfoldersCheckBox.IsChecked
        } else { # File Mode
            if ($selectedFilePaths.Count -eq 0) {
                [System.Windows.MessageBox]::Show("Please select at least one file.", "Files Required", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning) | Out-Null
                return # Stay in dialog
            }
            $selectionData.SelectionMode = 'Files'
            $selectionData.SelectedFiles = $selectedFilePaths.ToArray() # Convert List to Array
            $selectionData.IncludeSubfolders = $false # Not applicable
        }

        # Store result and close
        $script:DialogResultData = $selectionData
        $window.DialogResult = $true
        $window.Close()
    })

    $cancelButton.Add_Click({
        $script:DialogResultData = @{ Result = $false }
        $window.DialogResult = $false
        $window.Close()
    })

    $window.ShowDialog() | Out-Null
    return $script:DialogResultData
}


# --- Main Script Logic ---

# 1. Load Tool Paths from Config or Defaults
$script:toolPaths = Load-ToolPaths -ConfigPath $configFilePath -Defaults $defaultPaths
# Assign specific variables for easier access
$script:exifToolPath = $script:toolPaths.ExifTool
$script:imageMagickPath = $script:toolPaths.ImageMagick
$script:dcrawPath = $script:toolPaths.Dcraw
$script:dngConverterPath = $script:toolPaths.DngConverter


# 2. Show Path Validation Dialog
Write-Host "Validating tool paths..."
$validationResult = Show-PathValidationDialog -CurrentPaths $script:toolPaths
if ($null -eq $validationResult -or $validationResult.Result -eq $false) { Write-Host "Path validation cancelled."; exit 0 }
# Update script variables with potentially modified paths
$script:exifToolPath = $validationResult.ExifTool
$script:imageMagickPath = $validationResult.ImageMagick
$script:dcrawPath = $validationResult.Dcraw
$script:dngConverterPath = $validationResult.DngConverter
Write-Host "Tool paths validated."


# 3. Show Main Folder/File Selection GUI
Write-Host "Launching source selection dialog..."
$script:DialogResultData = $null
$selection = Show-FolderSelectionDialog
if ($null -eq $selection -or $selection.Result -eq $false) { Write-Host "Operation cancelled."; exit 0 }

# Extract selections
$createBackups = $selection.CreateBackups
$selectionMode = $selection.SelectionMode

# 4. Display Final Settings & Prepare File List
$filesToProcessList = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
Write-Host "----------------------------------------"
if ($selectionMode -eq 'Folder') {
    $targetFolder = $selection.FolderPath
    $includeSubfolders = $selection.IncludeSubfolders
    Write-Host "Mode: Folder"
    Write-Host "Selected Folder: $($targetFolder)"
    Write-Host "Include Subfolders: $($includeSubfolders)"
    $gciParameters = @{ Path = $targetFolder; File = $true }
    if ($includeSubfolders) { $gciParameters.Recurse = $true }
    try {
        # Get files first
        $allItems = Get-ChildItem @gciParameters -ErrorAction Stop
        if ($allItems -ne $null) {
            # Filter and add to list
            foreach ($item in $allItems) {
                if ($rawFileExtensions -contains $item.Extension) {
                    $filesToProcessList.Add($item)
                }
            }
        }
    } catch {
         Write-Error "Failed to retrieve files from '$($targetFolder)'. Error: $($_.Exception.Message)"; exit 1
    }
} else { # Files Mode
    $selectedFilePaths = $selection.SelectedFiles
    Write-Host "Mode: Files"
    Write-Host "Selected Files Count: $($selectedFilePaths.Count)"
    # Convert paths to FileInfo objects and filter by extension
    foreach ($fPath in $selectedFilePaths) {
        $fileInfo = Get-Item -Path $fPath -ErrorAction SilentlyContinue
        if ($fileInfo -ne $null -and $rawFileExtensions -contains $fileInfo.Extension) {
            $filesToProcessList.Add($fileInfo)
        } else {
            Write-Warning "Skipping selected file as it's not found or not a target RAW type: $fPath"
        }
    }
}

Write-Host "Create Backups: $($createBackups)"
Write-Host "Using ExifTool: $($script:exifToolPath)"
Write-Host "Using ImageMagick: $($script:imageMagickPath)"
Write-Host "Using dcraw: $($script:dcrawPath)"
Write-Host "Using DNG Converter: $($script:dngConverterPath)"
Write-Host "----------------------------------------"

# 5. Process Files
$totalFiles = $filesToProcessList.Count
$processedCount = 0

if ($totalFiles -eq 0) { Write-Warning "No valid RAW files found to process."; exit 0 }
Write-Host "Found $totalFiles valid RAW files to process."
Write-Host "Starting file processing..."

try {
    foreach ($file in $filesToProcessList) {
        $processedCount++
        $filePath = $file.FullName
        $fileDir = $file.DirectoryName
        $fileNameOnly = $file.Name
        $fileNameWithoutExt = $file.BaseName
        $fileExtension = $file.Extension.ToLowerInvariant() # Use lower case for comparison

        $statusString = "Processing file {0} of {1}: {2}" -f $processedCount, $totalFiles, $fileNameOnly
        Write-Progress -Activity "Processing RAW Files" -Status $statusString -PercentComplete (($processedCount / $totalFiles) * 100) -CurrentOperation $filePath
        Write-Host "`n--- Processing: $($filePath) ---"

        $stdOutLog = Join-Path -Path $env:TEMP -ChildPath "proc_stdout_$($PID)_$($processedCount).log"
        $stdErrLog = Join-Path -Path $env:TEMP -ChildPath "proc_stderr_$($PID)_$($processedCount).log"
        $tempJpegPath = Join-Path -Path $env:TEMP -ChildPath "preview_$($PID)_$($processedCount).jpg"

        # --- Branch: Process .DNG files ---
        if ($fileExtension -eq ".dng") {
            # DNG Converter path should be valid from validation dialog, but double check
            if (-not (Validate-ToolPath $script:dngConverterPath)) {
                 Write-Warning "Skipping DNG conversion for '$fileNameOnly' as Adobe DNG Converter path '$($script:dngConverterPath)' is invalid."
                 continue
            }

            Write-Host "Using Adobe DNG Converter for '$fileNameOnly'..."
            $expectedOutputName = $fileNameWithoutExt + "_1.dng"
            $expectedOutputPath = Join-Path $fileDir $expectedOutputName
            # Updated DNG Args: Removed -c, use -u, use -p2, add -e
            $dngArgs = @("-cr16.0", "-u", "-e", "-p2", "`"$filePath`"")

            try {
                $quotedExePath = if ($script:dngConverterPath -match ' ') { "`"$($script:dngConverterPath)`"" } else { $script:dngConverterPath }
                Write-Verbose "Executing: $quotedExePath $($dngArgs -join ' ')"
                if (Test-Path $expectedOutputPath) { Remove-Item $expectedOutputPath -Force -ErrorAction SilentlyContinue }

                Start-Process -FilePath $quotedExePath -ArgumentList $dngArgs -Wait -NoNewWindow -RedirectStandardOutput $stdOutLog -RedirectStandardError $stdErrLog -ErrorAction Stop
                $exitCode = $LASTEXITCODE

                # --- DNG Converter Output Handling (Revised) ---
                $dngStdOut = if (Test-Path $stdOutLog) { Get-Content $stdOutLog -Raw } else { $null }
                $dngStdErr = if (Test-Path $stdErrLog) { Get-Content $stdErrLog -Raw } else { $null }
                if ($dngStdOut) { Write-Host $dngStdOut }
                if ($dngStdErr) { Write-Verbose "DNG Converter stderr (Exit Code $exitCode):`n$dngStdErr" }
                if (Test-Path $stdOutLog) { Remove-Item $stdOutLog -ErrorAction SilentlyContinue }
                if (Test-Path $stdErrLog) { Remove-Item $stdErrLog -ErrorAction SilentlyContinue }
                # --- End Output Handling ---

                # Check for success based on output file existence
                if (-not (Test-Path $expectedOutputPath)) {
                     $failMsg = "Adobe DNG Converter failed for '$fileNameOnly' - output file '$expectedOutputPath' not found."
                     if ($exitCode -ne 0) { $failMsg += " (Exit Code: $exitCode)" }
                     Write-Warning $failMsg
                     continue
                }

                Write-Host "Successfully converted '$fileNameOnly' to '$expectedOutputName'."
                if ($exitCode -ne 0) { Write-Warning "Adobe DNG Converter finished with Exit Code $exitCode for '$fileNameOnly', but output file was created." }

                # --- DNG Overwrite/Backup Logic ---
                if (-not $createBackups) {
                    Write-Host "Overwrite enabled: Replacing original DNG..."
                    $originalDeleted = $false
                    try {
                        Write-Verbose "Attempting to remove original: $filePath"
                        Remove-Item -Path $filePath -Force -ErrorAction Stop
                        $originalDeleted = $true
                        Write-Verbose "Original DNG removed."
                    } catch { Write-Error "FAILED to remove original file '$filePath': $($_.Exception.Message)"; Write-Warning "Keeping new file '$expectedOutputName' alongside original due to deletion error." }

                    if ($originalDeleted) {
                        try {
                            Write-Verbose "Attempting to rename '$expectedOutputName' to '$fileNameOnly'"
                            Rename-Item -Path $expectedOutputPath -NewName $fileNameOnly -ErrorAction Stop
                            Write-Verbose "Successfully renamed new DNG to replace original."
                        } catch { Write-Error "FAILED to rename '$expectedOutputName' to '$fileNameOnly': $($_.Exception.Message)"; Write-Warning "Original was deleted, but rename failed. New file remains as '$expectedOutputName'." }
                    }
                } else { Write-Host "Backups enabled: Keeping original '$fileNameOnly' and new '$expectedOutputName'." }
                # --- End DNG Overwrite/Backup Logic ---

            } catch { Write-Error "Error running Start-Process for DNG Converter on '$fileNameOnly': $($_.Exception.Message)" }

        # --- Branch: Use ImageMagick + ExifTool for other RAW files ---
        } else {
             # Paths for ImageMagick and ExifTool should be valid from validation dialog
            Write-Host "Attempting to generate and embed '$($generatedPreviewTag)' using ImageMagick+ExifTool for '$fileNameOnly'..."
            $previewGenerated = $false

            # Step 1: Generate preview with ImageMagick
            try {
                $magickArgs = @( "`"$filePath`[0]""", "-resize", "50%", "-normalize", "-gaussian-blur", "0.05", "`"$tempJpegPath`"" )
                $quotedMagickPath = if ($script:imageMagickPath -match ' ') { "`"$($script:imageMagickPath)`"" } else { $script:imageMagickPath }
                Write-Verbose "Executing: $quotedMagickPath $($magickArgs -join ' ')"
                Start-Process -FilePath $quotedMagickPath -ArgumentList $magickArgs -Wait -NoNewWindow -RedirectStandardOutput $stdOutLog -RedirectStandardError $stdErrLog -ErrorAction Stop
                $exitCode = $LASTEXITCODE

                $magickStdOut = if (Test-Path $stdOutLog) { Get-Content $stdOutLog -Raw } else { $null }
                $magickStdErr = if (Test-Path $stdErrLog) { Get-Content $stdErrLog -Raw } else { $null }
                if ($magickStdOut) { Write-Verbose "ImageMagick stdout:`n$magickStdOut" }
                if ($magickStdErr) { Write-Warning "ImageMagick stderr:`n$magickStdErr" }
                if (Test-Path $stdOutLog) { Remove-Item $stdOutLog -ErrorAction SilentlyContinue }
                if (Test-Path $stdErrLog) { Remove-Item $stdErrLog -ErrorAction SilentlyContinue }

                if ($exitCode -ne 0) { Write-Warning "ImageMagick failed to generate preview for '$fileNameOnly' (Exit Code: $exitCode)." }
                elseif (-not (Test-Path $tempJpegPath)) { Write-Warning "ImageMagick ran (Exit Code 0) but temp preview '$tempJpegPath' was not created." }
                else { Write-Verbose "Successfully generated temporary preview: $tempJpegPath"; $previewGenerated = $true }
            } catch { Write-Error "Error running Start-Process for ImageMagick on '$fileNameOnly': $($_.Exception.Message)" }

            # Step 2: Embed preview with ExifTool (only if preview was generated)
            if ($previewGenerated) {
                $exifToolArgs = @()
                $exifToolArgs += "-${generatedPreviewTag}<=`"$tempJpegPath`""
                if (-not $createBackups) { $exifToolArgs += "-overwrite_original" }
                $exifToolArgs += "-ignoreMinorErrors"
                $exifToolArgs += "`"$filePath`""

                try {
                     $quotedExifToolPath = if ($script:exifToolPath -match ' ') { "`"$($script:exifToolPath)`"" } else { $script:exifToolPath }
                     Write-Verbose "Executing: $quotedExifToolPath $($exifToolArgs -join ' ')"
                     Start-Process -FilePath $quotedExifToolPath -ArgumentList $exifToolArgs -Wait -NoNewWindow -RedirectStandardOutput $stdOutLog -RedirectStandardError $stdErrLog -ErrorAction Stop
                     $exitCode = $LASTEXITCODE

                     $errorContent = $null
                     if (Test-Path $stdOutLog) { Get-Content $stdOutLog -Raw | Write-Host; Remove-Item $stdOutLog -ErrorAction SilentlyContinue }
                     if (Test-Path $stdErrLog) {
                         $errorContent = Get-Content $stdErrLog -Raw -ErrorAction SilentlyContinue
                         if ($errorContent) {
                             if ($errorContent -notmatch '^\s*\d+ image files (updated|unchanged)\s*$') { Write-Error $errorContent }
                             else { Write-Host $errorContent.Trim(); $errorContent = $null }
                         }
                         Remove-Item $stdErrLog -ErrorAction SilentlyContinue
                     }

                     if ($exitCode -ne 0) {
                         if ($errorContent) { Write-Warning "ExifTool failed to embed preview for '$fileNameOnly' (Exit Code: $($exitCode))" }
                         else { Write-Verbose "ExifTool finished embedding preview for '$fileNameOnly' with Exit Code: $($exitCode) (Minor issue?)" }
                     } else {
                         if (-not $errorContent) { Write-Host "Successfully embedded preview into '$fileNameOnly'." }
                     }
                } catch { Write-Error "Error executing Start-Process for ExifTool embed on '$fileNameOnly': $($_.Exception.Message)" }
            } # End if ($previewGenerated)

            # Step 3: Clean up temp preview file (always attempt)
            if (Test-Path $tempJpegPath) {
                Write-Verbose "Cleaning up temporary file: $tempJpegPath"
                Remove-Item $tempJpegPath -Force -ErrorAction SilentlyContinue
            }

        } # End ImageMagick+ExifTool Branch

        Write-Host "--- Finished: $($filePath) ---"
    } # End foreach file

    Write-Progress -Activity "Processing RAW Files" -Completed
    Write-Host "`nProcessing complete."

}
catch [System.Management.Automation.ItemNotFoundException] {
     Write-Error "Failed to find the specified path '$($targetFolder)'. Please ensure the path is correct. Error: $($_.Exception.Message)"
     exit 1
}
catch {
    Write-Error "An error occurred while retrieving or processing files: $($_.Exception.Message)"
    exit 1
}

Write-Host "Script finished."

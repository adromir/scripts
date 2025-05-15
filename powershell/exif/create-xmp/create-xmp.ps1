<#
.SYNOPSIS
    Creates XMP sidecar files for media files in a selected folder using ExifTool.
.DESCRIPTION
    This script presents a WPF GUI to select a folder containing media files (images, RAW, videos).
    It checks if ExifTool is installed and offers to install it via winget if not found.
    For each media file found (optionally including subfolders), it deletes any existing corresponding
    .xmp file and then uses ExifTool to generate a new .xmp sidecar file from the media file's metadata.
.NOTES
    Author: Adromir
    Date:   2025-05-01
    Requires: PowerShell 5.1 or later, .NET Framework 4.5 or later for WPF.
              ExifTool (will offer to install via winget if not found).
#>

#region WPF GUI Definition
Add-Type -AssemblyName PresentationFramework, System.Windows.Forms, WindowsBase, PresentationCore

[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="XMP Sidecar Creator" Height="350" Width="500" ResizeMode="NoResize" WindowStartupLocation="CenterScreen">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="*"/>
            <ColumnDefinition Width="Auto"/>
        </Grid.ColumnDefinitions>

        <Label Grid.Row="0" Grid.Column="0" Grid.ColumnSpan="2" Content="Select Folder Containing Media Files:" FontWeight="Bold"/>

        <TextBox x:Name="FolderTextBox" Grid.Row="1" Grid.Column="0" Margin="0,0,5,0" IsReadOnly="True" VerticalContentAlignment="Center"/>
        <Button x:Name="BrowseButton" Grid.Row="1" Grid.Column="1" Content="Browse..." Padding="10,5"/>

        <CheckBox x:Name="SubfoldersCheckBox" Grid.Row="2" Grid.Column="0" Grid.ColumnSpan="2" Content="Include Subfolders" Margin="0,10,0,10"/>

        <TextBox x:Name="StatusTextBox" Grid.Row="3" Grid.Column="0" Grid.ColumnSpan="2" Margin="0,5,0,10" TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" IsReadOnly="True" FontFamily="Consolas"/>

        <Button x:Name="StartButton" Grid.Row="4" Grid.Column="0" Grid.ColumnSpan="2" Content="Create XMP Files" Padding="10,5" FontWeight="Bold" IsEnabled="False"/>
    </Grid>
</Window>
"@

# Create WPF objects from XAML
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
try {
    $window = [Windows.Markup.XamlReader]::Load($reader)
} catch {
    Write-Error "Error loading WPF window: $($_.Exception.Message)"
    exit 1
}

# Get references to GUI elements
$folderTextBox = $window.FindName("FolderTextBox")
$browseButton = $window.FindName("BrowseButton")
$subfoldersCheckBox = $window.FindName("SubfoldersCheckBox")
$startButton = $window.FindName("StartButton")
$statusTextBox = $window.FindName("StatusTextBox")

#endregion

#region Global Variables and Configuration

# Define the extensions of media files to process
$mediaExtensions = @(
    '.jpg', '.jpeg', '.png', '.gif', '.tiff', '.tif', # Common Images
    '.cr2', '.cr3', '.nef', '.arw', '.orf', '.rw2', '.raf', '.dng', # RAW Images
    '.mov', '.mp4', '.avi', '.mkv', '.mts', '.m2ts' # Common Videos
)

# Function to add status messages to the text box
function Add-Status ($message) {
    $statusTextBox.Dispatcher.Invoke([Action]{
        $statusTextBox.AppendText("$(Get-Date -Format 'HH:mm:ss') - $message`r`n")
        $statusTextBox.ScrollToEnd()
    }, "Normal")
}

#endregion

#region ExifTool Check and Installation

function Check-And-Install-ExifTool {
    Add-Status "Checking for ExifTool..."
    $exiftoolPath = Get-Command -Name exiftool -ErrorAction SilentlyContinue
    if ($exiftoolPath) {
        Add-Status "ExifTool found at: $($exiftoolPath.Source)"
        return $true
    } else {
        Add-Status "ExifTool not found in PATH."
        $msgTitle = "ExifTool Not Found"
        $msgBody = "ExifTool is required but was not found in your system's PATH.`n`nDo you want to attempt to install it using winget?"
        $msgButton = [System.Windows.Forms.MessageBoxButtons]::YesNo
        $msgIcon = [System.Windows.Forms.MessageBoxIcon]::Question

        $result = [System.Windows.Forms.MessageBox]::Show($msgBody, $msgTitle, $msgButton, $msgIcon)

        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
            Add-Status "Attempting to install ExifTool via winget..."
            try {
                # Check if winget exists
                $wingetPath = Get-Command -Name winget -ErrorAction SilentlyContinue
                if (-not $wingetPath) {
                     Add-Status "Error: winget command not found. Cannot install ExifTool automatically."
                     [System.Windows.Forms.MessageBox]::Show("winget was not found on your system. Please install ExifTool manually and ensure it's in your PATH.", "Winget Not Found", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                     return $false
                }

                # Run winget install
                Write-Host "Running: winget install ExifTool" # Also show in console
                $process = Start-Process winget -ArgumentList "install ExifTool" -Wait -PassThru -WindowStyle Minimized

                if ($process.ExitCode -eq 0) {
                    Add-Status "ExifTool installation successful (Exit Code: $($process.ExitCode)). Please restart the script."
                     [System.Windows.Forms.MessageBox]::Show("ExifTool installed successfully. Please restart this script for the changes to take effect.", "Installation Successful", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                    # Exit after successful install as PATH might need refresh
                    $window.Close()
                    exit 0 # Exit script cleanly
                } else {
                    Add-Status "ExifTool installation failed (Exit Code: $($process.ExitCode)). Please install it manually."
                    [System.Windows.Forms.MessageBox]::Show("ExifTool installation failed (Exit Code: $($process.ExitCode)). Please install ExifTool manually and ensure it's in your PATH.", "Installation Failed", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                    return $false
                }
            } catch {
                Add-Status "An error occurred during winget installation: $($_.Exception.Message)"
                [System.Windows.Forms.MessageBox]::Show("An error occurred during installation: $($_.Exception.Message). Please install ExifTool manually.", "Installation Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                return $false
            }
        } else {
            Add-Status "User chose not to install ExifTool. Script cannot continue."
            [System.Windows.Forms.MessageBox]::Show("ExifTool is required to proceed. Please install it manually and ensure it's in your PATH.", "ExifTool Required", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            return $false
        }
    }
}

#endregion

#region Event Handlers

# Browse Button Click Event
$browseButton.Add_Click({
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Select the folder containing media files"
    $folderBrowser.ShowNewFolderButton = $false

    # Set initial directory if a folder is already selected
    if ([System.IO.Directory]::Exists($folderTextBox.Text)) {
        $folderBrowser.SelectedPath = $folderTextBox.Text
    }

    # Show the dialog and process the result
    if ($folderBrowser.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $folderTextBox.Text = $folderBrowser.SelectedPath
        $startButton.IsEnabled = $true # Enable start button only when a folder is selected
        Add-Status "Selected folder: $($folderTextBox.Text)"
    }
})

# Start Button Click Event
$startButton.Add_Click({
    # Disable buttons during processing
    $startButton.IsEnabled = $false
    $browseButton.IsEnabled = $false
    $subfoldersCheckBox.IsEnabled = $false
    $statusTextBox.Clear() # Clear previous status

    # Check for ExifTool first
    if (-not (Check-And-Install-ExifTool)) {
        Add-Status "ExifTool check failed or installation declined. Aborting."
        # Re-enable buttons if ExifTool check fails
        $startButton.IsEnabled = ([System.IO.Directory]::Exists($folderTextBox.Text))
        $browseButton.IsEnabled = $true
        $subfoldersCheckBox.IsEnabled = $true
        return
    }

    $targetFolder = $folderTextBox.Text
    $includeSubfolders = $subfoldersCheckBox.IsChecked

    if (-not ([System.IO.Directory]::Exists($targetFolder))) {
        Add-Status "Error: Selected folder '$targetFolder' does not exist."
        [System.Windows.Forms.MessageBox]::Show("The selected folder does not exist. Please select a valid folder.", "Folder Not Found", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
         # Re-enable buttons
        $startButton.IsEnabled = $true # Keep it enabled as path was technically selected before
        $browseButton.IsEnabled = $true
        $subfoldersCheckBox.IsEnabled = $true
        return
    }

    Add-Status "Starting XMP creation process..."
    Add-Status "Target Folder: $targetFolder"
    Add-Status "Include Subfolders: $includeSubfolders"
    Add-Status "Processing extensions: $($mediaExtensions -join ', ')"

    # Get files
    $getFilesParams = @{
        Path = $targetFolder
        Include = $mediaExtensions | ForEach-Object { "*$_" } # Format for -Include
        File = $true
        ErrorAction = 'SilentlyContinue'
    }
    if ($includeSubfolders) {
        $getFilesParams.Recurse = $true
    }

    $mediaFiles = Get-ChildItem @getFilesParams

    if (-not $mediaFiles) {
        Add-Status "No media files found matching the specified extensions in the selected location."
    } else {
        Add-Status "Found $($mediaFiles.Count) media files to process."
        $processedCount = 0
        $errorCount = 0

        foreach ($file in $mediaFiles) {
            $processedCount++
            $mediaFilePath = $file.FullName
            # Construct the expected XMP file path by replacing the extension
            $xmpFilePath = [System.IO.Path]::ChangeExtension($mediaFilePath, '.xmp')

            Add-Status "($processedCount/$($mediaFiles.Count)) Processing: `"$($file.Name)`""

            # Check if an XMP file already exists
            if (Test-Path -Path $xmpFilePath -PathType Leaf) {
                Add-Status "  Deleting existing XMP: `"$($xmpFilePath)`""
                try {
                    Remove-Item -Path $xmpFilePath -Force -ErrorAction Stop
                } catch {
                    Add-Status "  Error deleting existing XMP: $($_.Exception.Message)"
                    $errorCount++
                    continue # Skip to next file if deletion fails
                }
            }

            # Create the new XMP file using ExifTool
            # Use Start-Process for better control and quoting
            $arguments = @(
                '-o' # Output file argument
                "`"$xmpFilePath`"" # The output XMP file path (quoted)
                "`"$mediaFilePath`"" # The input media file path (quoted)
            )

            Add-Status "  Running ExifTool: exiftool -o `"{0}`" `"{1}`"" -f $xmpFilePath.Replace("$","`$"), $mediaFilePath.Replace("$","`$") # Escape $ for format string

            try {
                 # Ensure directory exists for XMP file (should usually be the same as media file)
                $xmpDirectory = [System.IO.Path]::GetDirectoryName($xmpFilePath)
                if (-not (Test-Path -Path $xmpDirectory -PathType Container)) {
                    New-Item -Path $xmpDirectory -ItemType Directory -Force | Out-Null
                }

                $process = Start-Process -FilePath "exiftool" -ArgumentList $arguments -Wait -NoNewWindow -PassThru -ErrorAction Stop

                if ($process.ExitCode -eq 0) {
                    Add-Status "  Successfully created XMP: `"$($xmpFilePath)`""
                } else {
                    Add-Status "  Error: ExifTool failed for `"$($file.Name)`" (Exit Code: $($process.ExitCode)). Check ExifTool output if available."
                    $errorCount++
                    # Attempt to clean up potentially empty/corrupt XMP file if ExifTool failed
                    if (Test-Path -Path $xmpFilePath -PathType Leaf) {
                       Remove-Item -Path $xmpFilePath -Force -ErrorAction SilentlyContinue
                    }
                }
            } catch {
                Add-Status "  Error executing ExifTool for `"$($file.Name)`": $($_.Exception.Message)"
                $errorCount++
            }
             # Force UI update
             $window.Dispatcher.Invoke([Action]{}, "Background")
        } # End foreach file

        Add-Status "-----------------------------------------------------"
        Add-Status "Processing complete."
        Add-Status "Total files processed: $processedCount"
        Add-Status "XMP files successfully created/updated: $($processedCount - $errorCount)"
        Add-Status "Errors encountered: $errorCount"
        Add-Status "-----------------------------------------------------"

    } # End if mediaFiles found

    # Re-enable buttons
    $startButton.IsEnabled = $true
    $browseButton.IsEnabled = $true
    $subfoldersCheckBox.IsEnabled = $true
})

#endregion

#region Show Window
Add-Status "Script loaded. Please select a folder and click 'Create XMP Files'."
Add-Status "Supported extensions: $($mediaExtensions -join ', ')"
$window.ShowDialog() | Out-Null # Show the window modally
#endregion

<#
.SYNOPSIS
Scans a selected folder (optionally including subfolders) for image files,
uses ExifTool to check for metadata errors/warnings (using -validate -warning -a),
displays progress in the console, reports file-specific issues (excluding a specific
'large array' warning) in a WPF GUI window, and provides an option in the GUI to save
the report to a user-selected folder.

.DESCRIPTION
This script uses a standard FolderBrowserDialog for initial folder selection, but utilizes
Windows Presentation Foundation (WPF) for subsequent confirmation dialogs and the final
results window. It displays progress in the PowerShell console using Write-Progress while
it searches for image files and checks them using ExifTool (-validate -warning -a -charset utf8).
Get-ChildItem logic is adjusted to correctly filter files based on extensions whether or not
recursion is enabled. When relevant errors/warnings are found for a file, a message is
immediately printed to the console. After completion, a list of files with their relevant
errors/warnings is displayed in a new WPF GUI window with a scrollable text box. The specific
warning containing 'Not decoding some large array(s). Ignore minor errors to decode' is
filtered out from the reported issues for each file. Files that *only* have this specific
warning are excluded entirely. A "Save Log..." button in this window allows saving the report
named 'exif_errors.log' to a folder chosen by the user via a folder browser dialog. The console
output indicates the number of files with relevant issues found.

.NOTES
Author: Adromir
Date:   2025-05-01
Requires:
    - PowerShell 5.1 or later.
    - .NET Framework 3.0 or later (for WPF).
    - ExifTool by Phil Harvey (exiftool.exe) must be installed and either:
        a) In the system's PATH environment variable.
        b) Its full path specified in the $exiftoolPath variable below.

.LINK
ExifTool Website: https://exiftool.org/

.EXAMPLE
.\Check-Metadata.ps1
# This will open the folder browser dialog, prompt for subdirectory inclusion (WPF),
# show progress in the console during scanning of image files, print warnings immediately,
# correctly find files, display a list of files/errors (filtering out the specific 'large array' warning)
# in a WPF GUI window, and provide a button within that window to save 'exif_errors.log' to a
# user-selected folder.
#>

#region Configuration
# --- Specify the path to exiftool.exe ---
$exiftoolPath = 'exiftool.exe' # Or 'C:\path\to\exiftool\exiftool.exe'

# --- Define IMAGE file extensions to check ---
$imageExtensions = @('.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff', '.tif', '.heic', '.heif', '.webp', '.raw', '.cr2', '.nef', '.arw', '.dng')
# $videoExtensions = @('.mp4', '.mov', '.avi', '.wmv', '.mkv', '.mts', '.m2ts', '.mpg', '.mpeg', '.3gp', '.flv') # Removed video checking
$validExtensions = $imageExtensions # Only check image extensions
#endregion Configuration

#region Required Assemblies
# Load Forms assembly for FolderBrowserDialog
Add-Type -AssemblyName System.Windows.Forms
# Load WPF assemblies
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
#endregion Required Assemblies

#region Functions
# Function to display the standard Windows Forms folder browser dialog
function Select-FolderDialog {
    param(
        [string]$Description = "Select a folder",
        [string]$RootFolder = "MyComputer"
    )
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = $Description
    $folderBrowser.RootFolder = $RootFolder
    $folderBrowser.ShowNewFolderButton = $true # Allow creating new folders for saving
    # Use a dummy form to ensure the dialog is topmost (WinForms specific)
    $dummyForm = New-Object System.Windows.Forms.Form -Property @{TopMost = $true }
    $result = $folderBrowser.ShowDialog($dummyForm)
    $dummyForm.Dispose() # Clean up the dummy form
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return $folderBrowser.SelectedPath
    } else {
        Write-Warning "Folder selection cancelled by user."
        return $null
    }
}

# Function to ask Yes/No using a WPF MessageBox
function Confirm-WPFPrompt {
    param(
        [string]$Title = "Confirmation",
        [string]$Message = "Proceed?"
    )
    # Define WPF MessageBox parameters
    $messageBoxButtons = [System.Windows.MessageBoxButton]::YesNo
    $messageBoxImage = [System.Windows.MessageBoxImage]::Question
    $messageBoxResult = [System.Windows.MessageBoxResult]::No # Default result if closed

    # Show the WPF MessageBox
    $result = [System.Windows.MessageBox]::Show($Message, $Title, $messageBoxButtons, $messageBoxImage, $messageBoxResult)

    # Return $true if Yes was clicked, $false otherwise
    return ($result -eq [System.Windows.MessageBoxResult]::Yes)
}


# Function to display results in a WPF GUI window with Save option
function Show-FileErrorsWPF {
    param(
        # Expects the pre-formatted text string to display
        [string]$FormattedText,
        # Expects the raw list of lines for saving
        [System.Collections.Generic.List[string]]$ReportLines,
        [string]$WindowTitle = "ExifTool Validation Results"
    )

    # Define the WPF Window using XAML
    [xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="$WindowTitle" Height="500" Width="700" MinHeight="300" MinWidth="400"
        WindowStartupLocation="CenterScreen">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>  <RowDefinition Height="*"/>     <RowDefinition Height="Auto"/>  </Grid.RowDefinitions>

        <Label Grid.Row="0" Content="Image files with relevant errors/warnings found:" FontWeight="Bold" Margin="0,0,0,5"/>

        <ScrollViewer Grid.Row="1" VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto">
            <TextBox Name="ResultsTextBox" IsReadOnly="True" FontFamily="Consolas" FontSize="12" TextWrapping="NoWrap" VerticalAlignment="Stretch" HorizontalAlignment="Stretch"/>
        </ScrollViewer>

        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,10,0,0">
            <Button Name="SaveButton" Content="Save Log..." Width="120" Height="25" Margin="5"/>
            <Button Name="CloseButton" Content="Close" Width="100" Height="25" Margin="5" IsDefault="True" IsCancel="True"/>
        </StackPanel>
    </Grid>
</Window>
"@

    # Create the WPF objects from XAML
    $reader = New-Object System.Xml.XmlNodeReader $xaml
    try {
        $window = [System.Windows.Markup.XamlReader]::Load($reader)
    } catch {
        Write-Error "Error loading WPF window XAML: $($_.Exception.Message)"
        return
    }

    # Get references to the controls
    $resultsTextBox = $window.FindName("ResultsTextBox")
    $saveButton = $window.FindName("SaveButton")
    $closeButton = $window.FindName("CloseButton")

    # Populate the TextBox
    $resultsTextBox.Text = $FormattedText

    # --- Button Event Handlers ---
    $saveButton.add_Click({
        # Use the standard WinForms FolderBrowserDialog for selecting save location
        $saveFolder = Select-FolderDialog -Description "Select folder to save exif_errors.log"
        if ($saveFolder) {
            $savePath = Join-Path -Path $saveFolder -ChildPath "exif_errors.log"
            try {
                # Use .NET method for potentially better performance with large lists
                [System.IO.File]::WriteAllLines($savePath, $ReportLines)
                [System.Windows.MessageBox]::Show("Report saved successfully to:`n$savePath", "Save Successful", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)
            } catch {
                Write-Error "Failed to save report to '$savePath': $($_.Exception.Message)"
                [System.Windows.MessageBox]::Show("Failed to save report:`n$($_.Exception.Message)", "Save Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
            }
        } else {
            # User cancelled folder selection
            [System.Windows.MessageBox]::Show("Save cancelled.", "Cancelled", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Warning)
        }
    })

    $closeButton.add_Click({
        $window.Close()
    })

    # Show the window modally
    $window.ShowDialog() | Out-Null
}

#endregion Functions

# --- Main Script ---

# 1. Check if ExifTool exists
try {
    Get-Command $exiftoolPath -ErrorAction Stop | Out-Null
    Write-Host "Using ExifTool found at: $($exiftoolPath)" -ForegroundColor Green
} catch {
    Write-Error "ExifTool ('$($exiftoolPath)') not found or not executable."
    # Use WPF MessageBox for consistency in GUI prompts
    [System.Windows.MessageBox]::Show("ExifTool ('$($exiftoolPath)') not found or not executable. Please check the path in the script or ensure it's in your system PATH.", "ExifTool Not Found", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    Read-Host "Press Enter to exit..."
    Exit 1
}

# 2. Select the folder using GUI (Still using WinForms dialog)
$selectedFolder = Select-FolderDialog -Description "Select the folder containing image files" # Updated description
if (-not $selectedFolder) {
    Write-Host "No folder selected. Exiting script."
    Read-Host "Press Enter to exit..."
    Exit 1
}
Write-Host "Selected folder: $($selectedFolder)"

# 3. Ask about subdirectories using WPF GUI
$includeSubdirectories = Confirm-WPFPrompt -Title "Scan Subdirectories?" -Message "Do you want to include subdirectories in the scan?"
if ($includeSubdirectories) {
    Write-Host "Including subdirectories."
} else {
    Write-Host "Scanning top-level folder only."
}

# 4. Get the files
Write-Host "Scanning for image files..." # Updated message
# Corrected Get-ChildItem logic based on recursion
if ($includeSubdirectories) {
    # Use -Include when recursing
    $getFilesParams = @{
        Path = $selectedFolder
        Include = $validExtensions | ForEach-Object { "*$_" } # $validExtensions now only contains image types
        Recurse = $true
        Force = $true
        ErrorAction = 'SilentlyContinue'
    }
    $filesToCheck = Get-ChildItem @getFilesParams | Where-Object { -not $_.PSIsContainer }
} else {
    # Do NOT use -Include when not recursing; filter afterwards
    $getFilesParams = @{
        Path = $selectedFolder
        Force = $true
        ErrorAction = 'SilentlyContinue'
    }
    # Pipe to Where-Object to filter by extension AND check it's not a container
    $filesToCheck = Get-ChildItem @getFilesParams | Where-Object {
        (-not $_.PSIsContainer) -and ($validExtensions -contains $_.Extension) # $validExtensions now only contains image types
    }
}

if ($filesToCheck.Count -eq 0) {
    Write-Warning "No image files found with the specified extensions in the selected location." # Updated message
    Read-Host "Press Enter to exit..."
    Exit 0
}
$totalFiles = $filesToCheck.Count
Write-Host "Found $totalFiles image files to check." # Updated message

# 5. Check files with ExifTool and collect errors (using Console Progress)
$fileErrorsHashTable = [System.Collections.Hashtable]::new()
$checkedFiles = 0
# Define the pattern to ignore using wildcards
$ignoreWarningPattern = "*Not decoding some large array(s). Ignore minor errors to decode*"

Write-Host "Starting ExifTool validation (-validate -warning -a)..." # Indicate options used

foreach ($file in $filesToCheck) {
    $checkedFiles++
    # Update console progress bar
    $percentComplete = if ($totalFiles -gt 0) { [int](($checkedFiles / $totalFiles) * 100) } else { 0 }
    $statusText = 'Processing file {0} of {1}: {2}' -f $checkedFiles, $totalFiles, $file.Name
    Write-Progress -Activity "Checking Image File Metadata" -Status $statusText -PercentComplete $percentComplete # Updated activity

    try {
        # Setup process start info for ExifTool
        $processInfo = New-Object System.Diagnostics.ProcessStartInfo
        $processInfo.FileName = $exiftoolPath
        # Use recommended -validate -warning -a flags
        $processInfo.Arguments = "-validate -warning -a -charset utf8 `"$($file.FullName)`""
        $processInfo.RedirectStandardOutput = $true
        $processInfo.RedirectStandardError = $true # Capture stderr separately
        $processInfo.UseShellExecute = $false
        $processInfo.CreateNoWindow = $true
        $processInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $processInfo.StandardErrorEncoding = [System.Text.Encoding]::UTF8 # Ensure stderr is also UTF8

        # Start the process and capture output/error streams
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $processInfo
        $process.Start() | Out-Null
        # Read both streams
        $output = $process.StandardOutput.ReadToEnd()
        $errors = $process.StandardError.ReadToEnd() # Read stderr
        $process.WaitForExit()

        # Combine streams and filter for error/warning lines
        $combinedOutput = $output + $errors
        $exiftoolOutputLines = $combinedOutput -split [Environment]::NewLine
        $currentFileErrors = [System.Collections.Generic.List[string]]::new() # Temp list for all errors for this file

        foreach ($line in $exiftoolOutputLines) {
            # Use case-insensitive -match and allow ':' or '='
            if ($line -match '^\s*(Error|Warning)\s*[:=]') {
                # Use regex replace that handles ':' or '=' and potential space after it
                $errorMessage = [System.Text.RegularExpressions.Regex]::Replace($line, '^\s*(Error|Warning)\s*[:=]\s*', '').Trim()
                $currentFileErrors.Add($errorMessage)
            }
        }

        # Filter out the specific ignored warning pattern
        if ($currentFileErrors.Count -gt 0) {
            # Use -notlike with the pattern
            # Create a new list containing only the errors *not* matching the ignored warning pattern
            $relevantFileErrors = $currentFileErrors | Where-Object { $_ -notlike $ignoreWarningPattern }

            # Add the file to the main hashtable ONLY if there are relevant errors remaining
            if ($relevantFileErrors.Count -gt 0) {
                 # Store the filtered list of relevant errors
                 $fileErrorsHashTable[$file.FullName] = $relevantFileErrors
                 # Write warning to console when relevant errors are found
                 Write-Warning "Issues found in file: $($file.Name)"
            }
        }

    } catch { # Catch errors from starting the process etc.
        $errMsg = "Failed to process file '$($file.Name)' due to script error: $($_.Exception.Message)"
        Write-Warning $errMsg # Write warning to console immediately
        # Add this process error to the hashtable associated with the file
        if (-not $fileErrorsHashTable.ContainsKey($file.FullName)) {
            $fileErrorsHashTable[$file.FullName] = [System.Collections.Generic.List[string]]::new()
        }
        # SCRIPT_ERROR should always be reported
        $fileErrorsHashTable[$file.FullName].Add("SCRIPT_ERROR: $errMsg")
        # Also write warning for script errors during processing
        Write-Warning "Script error processing file: $($file.Name)"
    }
} # End foreach loop

# Complete the progress bar
Write-Progress -Activity "Checking Image File Metadata" -Completed # Updated activity

# 6. Process and Display Results
Write-Host "`n--- ExifTool Validation Complete ---" -ForegroundColor Cyan

if ($fileErrorsHashTable.Count -gt 0) {

    # --- Prepare the Report Content ---
    $reportOutputLines = [System.Collections.Generic.List[string]]::new()
    $reportOutputLines.Add("ExifTool Validation Report (Images Only)") # Updated title
    $reportOutputLines.Add("=" * 30)
    $reportOutputLines.Add("Scanned Folder: $selectedFolder")
    $reportOutputLines.Add("Included Subdirectories: $includeSubdirectories")
    $reportOutputLines.Add("Timestamp: $(Get-Date)")
    $reportOutputLines.Add("Filtered Out Warning Pattern: '$ignoreWarningPattern'")
    $reportOutputLines.Add("=" * 30)
    $reportOutputLines.Add("")

    $sortedFiles = $fileErrorsHashTable.Keys | Sort-Object
    foreach ($filePath in $sortedFiles) {
        $reportOutputLines.Add("File: $filePath")
        # Note: $errorsForFile now contains only the relevant errors
        $errorsForFile = $fileErrorsHashTable[$filePath]
        foreach ($errorMsg in $errorsForFile) {
            $reportOutputLines.Add("  - $errorMsg")
        }
        $reportOutputLines.Add("") # Add a blank line between files
    }
    $reportFormattedText = $reportOutputLines -join [Environment]::NewLine

    # --- Output to Console (Simplified) ---
    Write-Host "Found relevant issues in $($fileErrorsHashTable.Count) image file(s). See GUI window for details." -ForegroundColor Yellow # Updated message

    # --- Show Results in WPF GUI Window ---
    try {
         # Pass both formatted text and raw lines to GUI function
         Show-FileErrorsWPF -FormattedText $reportFormattedText -ReportLines $reportOutputLines -WindowTitle "ExifTool Validation Results (Images Only)" # Updated title
    } catch {
         # Handle errors creating/showing the results GUI itself
         Write-Error "Failed to display results WPF GUI: $($_.Exception.Message)"
         [System.Windows.MessageBox]::Show("Failed to display results window: $($_.Exception.Message)", "GUI Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    }

} else {
    # Case where no errors were found (or only ignored warnings)
    Write-Host "No relevant errors or warnings reported by ExifTool for the scanned image files." -ForegroundColor Green # Updated message
    # Optionally show a success message box
    [System.Windows.MessageBox]::Show("Scan complete. No relevant errors or warnings found in image files.", "Scan Successful", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information) # Updated message
}

# --- End of Script ---
Write-Host "`nProcessing finished."
Read-Host "Press Enter to exit..."


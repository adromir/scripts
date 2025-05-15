#Requires -Version 5.1
#Requires -Assembly System.Windows.Forms

<#
.SYNOPSIS
    Recursively finds XMP files in a selected folder and removes all occurrences of "st|" from their content, showing progress.
.DESCRIPTION
    This script prompts the user to select a folder using a graphical dialog.
    It then searches for all files with the .xmp extension within that folder and its subfolders.
    For each XMP file found, it displays progress, prints the filename being processed,
    reads the content, removes every instance of the string "st|",
    and overwrites the original file with the modified content using UTF-8 encoding.
.NOTES
    Author: Adromir
    Date:   2025-04-28
    Version: 1.3
    Changes: Used -f format operator for Write-Progress status string to fix ParserError.
    Requires: Windows PowerShell 5.1 or later and .NET Framework (for the folder browser dialog).
    How to Run:
    1. Save this code as a .ps1 file (e.g., CleanXMP.ps1).
    2. Right-click the file and choose "Run with PowerShell".
    3. Or, open PowerShell, navigate to the directory where you saved the file, and run: .\CleanXMP.ps1
    4. You might need to adjust your PowerShell execution policy if you encounter errors running scripts.
       (See `Get-ExecutionPolicy` and `Set-ExecutionPolicy` cmdlets - use with caution).
#>

# --- Configuration ---
$StringToReplace = 'st|'       # The exact string to find and remove
$ReplacementString = ''        # What to replace it with (empty string means removal)
$FileFilter = '*.xmp'          # The file extension to target
$Encoding = [System.Text.Encoding]::UTF8 # Use UTF-8 encoding for reading and writing

# --- Function to Show Folder Browser Dialog ---
function Select-FolderDialog {
    param(
        [string]$Description = "Select the folder containing XMP files",
        [string]$RootFolder = "MyComputer" # You can set a specific starting point if needed
    )

    # Load the assembly required for the dialog if not already loaded
    Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue

    # Create and configure the dialog object
    $FolderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $FolderBrowser.Description = $Description
    # Ensure the RootFolder is valid, otherwise default to MyComputer
    try {
        $FolderBrowser.RootFolder = $RootFolder
    } catch {
        Write-Warning "Invalid RootFolder specified, defaulting to MyComputer."
        $FolderBrowser.RootFolder = [System.Environment+SpecialFolder]::MyComputer
    }
    $FolderBrowser.ShowNewFolderButton = $false # Optional: Prevent creating new folders via the dialog

    # Show the dialog.
    $Result = $FolderBrowser.ShowDialog()

    if ($Result -eq [System.Windows.Forms.DialogResult]::OK) {
        # Return the selected path if OK was clicked
        return $FolderBrowser.SelectedPath
    } else {
        # Return $null if Cancelled or closed
        Write-Warning "Folder selection was cancelled."
        return $null
    }
    # Dispose of the dialog object
    $FolderBrowser.Dispose()
}

# --- Main Script Logic ---

# 1. Show folder selection dialog
Write-Host "Please select the root folder containing your XMP files..."
$SelectedFolderPath = Select-FolderDialog -Description "Select the root folder containing your XMP files"

# Check if a folder was actually selected
if (-not $SelectedFolderPath -or -not (Test-Path -Path $SelectedFolderPath -PathType Container)) {
    Write-Host "No valid folder selected or selection cancelled. Script aborted." -ForegroundColor Yellow
    # Pause if running directly in console to allow user to see the message
    if ($Host.Name -eq "ConsoleHost") { Read-Host -Prompt "Press Enter to exit" }
    exit
}

Write-Host "Selected folder: $SelectedFolderPath" -ForegroundColor Green
Write-Host "Scanning for '$FileFilter' files and processing..."

# 2. Find XMP files recursively
try {
    # Get all files matching the filter, recursively
    $xmpFiles = Get-ChildItem -Path $SelectedFolderPath -Filter $FileFilter -Recurse -File -ErrorAction Stop
    $totalFiles = $xmpFiles.Count

    if ($totalFiles -eq 0) {
        Write-Host "No '$FileFilter' files found in '$SelectedFolderPath' or its subfolders." -ForegroundColor Yellow
    } else {
        Write-Host "Found $totalFiles '$FileFilter' file(s). Processing..." -ForegroundColor Cyan

        # 3. Loop through each file
        $filesProcessed = 0
        $filesModified = 0
        foreach ($file in $xmpFiles) {
            $filesProcessed++

            # --- Progress Bar Update ---
            $percentComplete = ($filesProcessed / $totalFiles) * 100
            $activity = "Processing XMP files in '$SelectedFolderPath'"
            # --- FIX V2: Use -f format operator for clarity and robustness ---
            $status = "Processing file {0} of {1}: {2}" -f $filesProcessed, $totalFiles, $file.Name
            Write-Progress -Activity $activity -Status $status -PercentComplete $percentComplete -Id 1 # Use a consistent ID for the progress bar

            # --- Verbose Output ---
            Write-Host "($($filesProcessed)/$($totalFiles)) Processing: $($file.FullName)" -ForegroundColor Gray

            try {
                # 4. Read file content as a single string, preserving line endings
                $content = Get-Content -Path $file.FullName -Raw -Encoding $Encoding -ErrorAction Stop

                # Check if the string to replace actually exists in the content
                # Use [regex]::Escape to treat the search string literally if it contains regex special characters
                if ($content -match [regex]::Escape($StringToReplace)) {
                    # 5. Perform the replacement
                    $modifiedContent = $content -replace [regex]::Escape($StringToReplace), $ReplacementString

                    # 6. Write the modified content back to the *same* file
                    Set-Content -Path $file.FullName -Value $modifiedContent -Encoding $Encoding -NoNewline -ErrorAction Stop

                    Write-Host " -> Modified: $($file.Name)" -ForegroundColor Green
                    $filesModified++
                } else {
                    # Optional: Uncomment the next line if you want confirmation for files that didn't need changes
                    # Write-Host " -> No changes needed for: $($file.Name)" -ForegroundColor DarkGray
                }

            } catch {
                # Log errors for specific files but continue with the rest
                Write-Error "Error processing file '$($file.FullName)': $($_.Exception.Message)"
                 # Optionally, update progress bar to indicate an error for this file
                 # --- FIX V2: Use -f format operator here as well ---
                $statusOnError = "ERROR processing {0}" -f $file.Name
                Write-Progress -Activity $activity -Status $statusOnError -PercentComplete $percentComplete -Id 1
            }
        }

        # Complete the progress bar when done
        Write-Progress -Activity $activity -Status "Completed processing $totalFiles files." -Completed -Id 1

        # --- Summary Output ---
        Write-Host "--------------------------------------------------" -ForegroundColor Cyan
        Write-Host "Processing complete." -ForegroundColor Cyan
        Write-Host "Total files scanned: $filesProcessed"
        Write-Host "Files modified: $filesModified" -ForegroundColor Green
    }

} catch {
    # Catch errors during the Get-ChildItem phase (e.g., access denied to a folder)
    Write-Error "An error occurred while searching for files in '$SelectedFolderPath': $($_.Exception.Message)"
}

# Pause if running directly in console to allow user to see the final output
if ($Host.Name -eq "ConsoleHost") {
    Read-Host -Prompt "Press Enter to exit"
}

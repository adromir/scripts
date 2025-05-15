<#
.SYNOPSIS
    Updates missing EXIF date information (DateTimeOriginal, CreateDate) in image files (JPG, JPEG, DNG, CR2)
    by parsing date and time from filenames matching user-defined patterns. Also updates file system timestamps.
    If a filename pattern provides only a date, time will be defaulted to 00:00:00.
    Uses WPF for folder selection.

.DESCRIPTION
    This script automates the process of correcting missing date and time metadata in image files.
    It targets JPG, JPEG, DNG, and CR2 files located within a user-specified folder.
    The folder selection is handled using a WPF OpenFileDialog configured for folder picking.

    The script supports multiple filename patterns, which can be configured in the "$fileNamePatterns"
    variable within the script. Each pattern must use regular expressions.
    - Patterns intended to extract both date and time should capture:
        - Date (YYYYMMDD) as the FIRST capture group ($matches[1])
        - Time (HHMMSS) as the SECOND capture group ($matches[2])
    - Patterns intended to extract only the date (e.g., for WhatsApp files) should capture:
        - Date (YYYYMMDD) as the FIRST capture group ($matches[1]).
        In this case, the time will be automatically set to "00:00:00".

    The order of patterns can be important, with more specific patterns generally listed before more general ones.

    The script performs the following actions for each eligible image file:
    1. Checks for an existing EXIF 'DateTimeOriginal' tag using ExifTool.
    2. If 'DateTimeOriginal' is missing, it examines the filename.
    3. It iterates through the list of defined $fileNamePatterns.
    4. If a matching filename is found:
        a. Extracts the year, month, day.
        b. Extracts hour, minute, second if available in the filename, otherwise defaults them to 00, 00, 00.
        c. Using ExifTool, writes this extracted/defaulted date and time to:
            - DateTimeOriginal
            - CreateDate
        d. Attempts to clear the IPTCDigest tag if it exists.
        e. Updates the file's system timestamps ('CreationTime' and 'LastWriteTime').
    5. Provides verbose output to the console, showing progress and actions.

    Prerequisites:
    - ExifTool (exiftool.exe) must be installed and accessible via the system's PATH.
    - Permissions to read/write files and modify metadata in the selected folder.

.NOTES
    Author: Adromir
    Ensure your custom regex patterns in $fileNamePatterns correctly capture groups as described.
    Supports .jpg, .jpeg, .dng, .cr2 files.

.PARAMETER Folder
    (Implicit) The script prompts the user to select the target folder using a WPF dialog.

.EXAMPLE
    .\exif_date_update_wpf.ps1

    Executing the script will open a WPF-based dialog to select a folder. After selecting a folder,
    the script scans for images and updates them based on the configured filename patterns.
#>

#Requires -Version 5.1
#Requires -Modules Microsoft.PowerShell.Utility

# --- Configuration ---

# Define the path to exiftool.exe. Assumes it's in the system PATH.
# If exiftool.exe is elsewhere, provide the full path, e.g., "C:\path\to\exiftool.exe"
$exiftoolPath = "exiftool.exe"

# --- Customizable Filename Patterns ---
# Add or modify regex patterns here.
# IMPORTANT: Each pattern MUST capture:
#   - Date (YYYYMMDD) as the FIRST capture group ($matches[1])
#   - Time (HHMMSS) as the SECOND capture group ($matches[2]) IF time is present in filename.
#   - If a pattern only captures the date (one capture group), time will be defaulted to 000000.
# The file extensions (jpg, jpeg, dng, cr2) are included in the patterns.
# Order can matter: more specific patterns are generally better placed earlier.
$fileNamePatterns = @(
    # Pattern 1: Handles IMG_YYYYMMDD_HHMMSS.ext, IMG_YYYYMMDD_HHMMSS_TAG.ext, and IMG_YYYYMMDD_HHMMSSxxx.NIGHT.ext
    # e.g., IMG_20230115_103000.jpg, IMG_20230115_103000_XYZ.dng, IMG_20241214_191110363.NIGHT.jpg
    "^IMG_(\d{8})_(\d{6})(?:(?:\d{3}\.NIGHT)|(?:_[a-zA-Z]{3})?)\.(jpg|jpeg|dng|cr2)$",

    # Pattern 2: Handles PANO_YYYYMMDD_HHMMSS.ext
    # e.g., PANO_20231105_120000.jpg
    "^PANO_(\d{8})_(\d{6})\.(jpg|jpeg|dng|cr2)$",

    # Pattern 3: Handles nrG_YYYYMMDD_HHMMSSxxx.ext and AGC_YYYYMMDD_HHMMSSxxx.ext
    # e.g., nrG_20240412_063301214.jpg, AGC_20230410_112030839.jpg
    "^(?:nrG|AGC)_(\d{8})_(\d{6})\d{3}\.(jpg|jpeg|dng|cr2)$",

    # Pattern 4: Handles PXL_YYYYMMDD_HHMMSSxxx.SUFFIX.ext (Google Pixel filenames)
    # e.g., PXL_20230411_092655930.PORTRAIT.ORIGINAL-01.jpeg, PXL_20240511_203715372.RAW-01.COVER.jpg
    "^PXL_(\d{8})_(\d{6})\d{3}\..*?\.(jpg|jpeg|dng|cr2)$",

    # Pattern 5: Handles IMG-YYYYMMDD-WAxxxx.jpg (WhatsApp, date only, time will be defaulted to 00:00:00)
    # e.g., IMG-20231002-WA0022.jpg
    "^IMG-(\d{8})-WA\d{4}\.(jpg|jpeg|dng|cr2)$", # Only one capture group for date

    # Pattern 6: Handles<y_bin_46>MMDD_HHMMSS.ext and<y_bin_46>MMDD_HHMMSS_Anything.ext (no specific prefix)
    # e.g., 20240513_083000.jpg, 20240220_154510_MyEvent.cr2
    # This should come after more specific patterns like PXL, IMG, PANO etc.
    "^(\d{8})_(\d{6})(?:_.*?)?\.(jpg|jpeg|dng|cr2)$",

    # Pattern 7: Handles GenericPrefix_YYYYMMDD_HHMMSS_Anything.ext (requires an alphanumeric prefix)
    # e.g., Holiday_20231225_180000_Dinner.jpg
    # This is quite general, so placed later.
    "^[a-zA-Z0-9]+_(\d{8})_(\d{6})_.*?\.(jpg|jpeg|dng|cr2)$",

    # Pattern 8: Handles<y_bin_46>MMDD-HHMMSS.ext (date and time separated by a hyphen)
    # e.g., 20240310-092530.dng
    "^(\d{8})-(\d{6})\.(jpg|jpeg|dng|cr2)$"
)
# --- End Customizable Filename Patterns ---


# --- Script Body ---

# Function to display WPF Folder Browser Dialog
function Get-WPFSelectedFolder {
    param (
        [string]$Title = "Select Folder",
        [string]$InitialDirectory = ([System.Environment+SpecialFolder]::MyComputer)
    )
    try {
        Add-Type -AssemblyName PresentationFramework
    } catch {
        Write-Error "Failed to load PresentationFramework assembly. This script requires WPF for folder selection."
        return $null
    }

    $openFileDialog = New-Object Microsoft.Win32.OpenFileDialog
    $openFileDialog.Title = $Title
    $openFileDialog.InitialDirectory = $InitialDirectory
    $openFileDialog.Filter = "Folders|*.this.does.not.exist" # Hack to make it a folder picker
    $openFileDialog.FileName = "Folder Selection" # Placeholder text in the filename box
    $openFileDialog.ValidateNames = $false
    $openFileDialog.CheckFileExists = $false
    $openFileDialog.CheckPathExists = $true


    if ($openFileDialog.ShowDialog() -eq $true) {
        # Return the directory of the (non-existent) selected file, which is the folder path
        return [System.IO.Path]::GetDirectoryName($openFileDialog.FileName)
    } else {
        return $null
    }
}


# Check if ExifTool exists in PATH or specified location
if (-not (Get-Command $exiftoolPath -ErrorAction SilentlyContinue)) {
    Write-Error "ExifTool ('$exiftoolPath') could not be found. Please ensure it is installed and in your system's PATH or provide the full path in the script."
    exit 1
}

# Get folder using WPF dialog
$selectedFolder = Get-WPFSelectedFolder -Title "Select the folder containing the image files (JPG, JPEG, DNG, CR2) to process."
if ($selectedFolder) {
    $folder = $selectedFolder
    Write-Host "Selected Folder: $folder" -ForegroundColor Green

    # Find image files (JPG, JPEG, DNG, CR2) directly in the selected folder (non-recursive)
    try {
        $imageFiles = Get-ChildItem -LiteralPath $folder -Include "*.jpg", "*.jpeg", "*.dng", "*.cr2" -File -ErrorAction Stop
    } catch {
        Write-Error "Error accessing folder or files in '$folder': $($_.Exception.Message)"
        exit 1
    }

    if (-not $imageFiles) {
        Write-Host "No image files (.jpg, .jpeg, .dng, .cr2) found in the selected folder."
        exit 0
    }

    Write-Host "Found $($imageFiles.Count) image files to check."

    # Initialize progress variables
    $totalFiles = $imageFiles.Count
    $processedFilesCount = 0
    $updatedFilesCount = 0

    # Process each image file
    foreach ($file in $imageFiles) {
        $processedFilesCount++
        $filePath = $file.FullName
        # Corrected line for Write-Progress:
        Write-Progress -Activity "Processing Images" -Status "Checking file $processedFilesCount of ${totalFiles}: ${file.Name}" -PercentComplete (($processedFilesCount / $totalFiles) * 100)

        # Corrected line for Write-Verbose:
        Write-Verbose "Processing file $($processedFilesCount) of $($totalFiles): $($file.Name)"

        # Check existing EXIF DateTimeOriginal using ExifTool
        try {
            $exifDateOutput = & $exiftoolPath -s -s -s -DateTimeOriginal "$filePath" -ErrorAction SilentlyContinue
            $exifDate = $exifDateOutput.Trim()
        } catch {
            Write-Warning "ExifTool error while reading '${file.Name}': $($_.Exception.Message)"
            Continue # Skip to the next file
        }

        Write-Verbose "File: $(${file.Name}), Current EXIF DateTimeOriginal: '$exifDate'" # Also corrected here for consistency

        if (-not $exifDate) {
            Write-Host "File: $(${file.Name}) - No existing DateTimeOriginal found. Checking filename..." -ForegroundColor Yellow # Corrected here

            $filenameMatched = $false
            $datePart = $null
            $timePart = $null
            $timeDefaulted = $false # Flag to indicate if time was defaulted

            # Iterate through defined patterns
            foreach ($patternString in $fileNamePatterns) {
                if ($file.Name -imatch $patternString) {
                    # $matches[0] is the full match
                    # $matches[1] should be<y_bin_46>MMDD
                    # $matches[2] should be HHMMSS (if available)

                    if ($matches.Count -ge 3) { # Standard case: Date and Time captured
                        $datePart = $matches[1]
                        $timePart = $matches[2]
                        $filenameMatched = $true
                        Write-Verbose "File: $(${file.Name}) - Matched pattern: `"$patternString`". Date part: '$datePart', Time part: '$timePart'." # Corrected here
                    } elseif ($matches.Count -eq 2) { # Case: Only Date captured (pattern has one capture group)
                        $datePart = $matches[1]
                        $timePart = "000000" # Default time
                        $timeDefaulted = $true # Flag that time was defaulted
                        $filenameMatched = $true
                        Write-Verbose "File: $(${file.Name}) - Matched pattern: `"$patternString`". Date part: '$datePart'. Time part defaulted to '$timePart'." # Corrected here
                    } else { # Should ideally not happen if regex patterns are well-formed
                        Write-Warning "File: $(${file.Name}) - Pattern `"$patternString`" matched, but did not yield expected capture groups. Check pattern definition." # Corrected here
                    }
                    
                    if ($filenameMatched) {
                        break # Pattern matched and parts assigned, exit this inner loop
                    }
                }
            }

            if ($filenameMatched) {
                Write-Verbose "File: $(${file.Name}) - Filename pattern recognized. Date: $datePart, Time: $timePart" # Corrected here

                # Basic validation for captured parts length
                if ($datePart.Length -ne 8 -or $timePart.Length -ne 6 -or -not ($datePart -match "^\d+$") -or -not ($timePart -match "^\d+$")) {
                    Write-Warning "File: $(${file.Name}) - Extracted date '$datePart' or time '$timePart' is not in<y_bin_46>MMDD or HHMMSS format. Skipping update for this file." # Corrected here
                    Continue # Skip to the next file
                }

                $year = $datePart.Substring(0, 4)
                $month = $datePart.Substring(4, 2)
                $day = $datePart.Substring(6, 2)
                $hour = $timePart.Substring(0, 2)
                $minute = $timePart.Substring(2, 2)
                $second = $timePart.Substring(4, 2)

                $exifDateTimeString = "${year}:${month}:${day} ${hour}:${minute}:${second}"
                $dotnetDateTimeString = "${year}-${month}-${day} ${hour}:${minute}:${second}"

                try {
                    $parsedDateTime = [datetime]::ParseExact($dotnetDateTimeString, "yyyy-MM-dd HH:mm:ss", $null)
                    Write-Verbose "File: $(${file.Name}) - Parsed DateTime object: $parsedDateTime" # Corrected here
                } catch {
                    Write-Warning "File: $(${file.Name}) - Could not parse '$dotnetDateTimeString' into a valid DateTime object. Extracted from '$datePart' and '$timePart'. Skipping update for this file. Error: $($_.Exception.Message)" # Corrected here
                    Continue # Skip to the next file
                }

                if ($timeDefaulted) {
                    Write-Host "File: $(${file.Name}) - Attempting to set EXIF date to: $exifDateTimeString (time defaulted to 00:00:00)" -ForegroundColor Cyan # Corrected here
                } else {
                    Write-Host "File: $(${file.Name}) - Attempting to set EXIF date to: $exifDateTimeString" -ForegroundColor Cyan # Corrected here
                }

                $exiftoolArgs = @(
                    "-DateTimeOriginal=$exifDateTimeString",
                    "-CreateDate=$exifDateTimeString",
                    "-overwrite_original",
                    "-if",
                    '$IPTCDigest',
                    "-IPTCDigest=",
                    "$filePath"
                )

                try {
                    & $exiftoolPath @exiftoolArgs -ErrorAction Stop
                    Write-Verbose "File: $(${file.Name}) - ExifTool command executed successfully." # Corrected here

                    $file.CreationTime = $parsedDateTime
                    $file.LastWriteTime = $parsedDateTime

                    Write-Host "File: $(${file.Name}) - Successfully updated EXIF and file timestamps to: $exifDateTimeString" -ForegroundColor Green # Corrected here
                    $updatedFilesCount++
                } catch {
                    Write-Warning "File: $(${file.Name}) - ExifTool failed to update metadata. Error: $($_.Exception.Message)" # Corrected here
                    if ($_.Exception.InnerException) {
                        Write-Warning "ExifTool Inner Exception: $($_.Exception.InnerException.Message)"
                    }
                }
            } else {
                Write-Host "File: $(${file.Name}) - Filename does not match any of the defined patterns." # Corrected here
            }
        } else {
            Write-Verbose "File: $(${file.Name}) - Already has an EXIF DateTimeOriginal value ('$exifDate'). No action needed." # Corrected here
        }
        Write-Verbose ("-" * 50)
    }

    Write-Progress -Activity "Processing Images" -Completed
    Write-Host "----------------------------------------"
    Write-Host "Processing Complete." -ForegroundColor Green
    Write-Host "Total files checked: $totalFiles"
    Write-Host "Files updated: $updatedFilesCount"
    Write-Host "----------------------------------------"

} else {
    Write-Host "Folder selection cancelled by user."
}

# Clean up variables if running interactively
if ($Host.Name -eq 'ConsoleHost') {
    Remove-Variable selectedFolder, folder, imageFiles, file, exifDate, datePart, timePart, year, month, day, hour, minute, second, exifDateTimeString, dotnetDateTimeString, parsedDateTime, exiftoolArgs, fileNamePatterns, patternString, timeDefaulted, openFileDialog -ErrorAction SilentlyContinue
}
